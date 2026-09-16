import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'audio_service.dart';

/// Controls an ambient background track that follows Quran playback.
/// The build workflow installs the bundled rain_loop.mp3 asset before compiling.
class BackgroundAudioService extends ChangeNotifier {
  static final BackgroundAudioService _instance =
      BackgroundAudioService._internal();
  factory BackgroundAudioService() => _instance;
  BackgroundAudioService._internal();

  static const String _rainAsset = 'assets/rain_loop.mp3';
  static const String _enabledKey = 'background_audio_enabled';
  static const String _backgroundVolumeKey = 'background_audio_volume';
  static const String _mainVolumeKey = 'main_audio_volume';

  final AudioPlayer _backgroundPlayer = AudioPlayer();
  final AudioService _quranAudio = AudioService();

  bool _initialized = false;
  bool _enabled = false;
  double _backgroundVolume = 0.20;
  double _mainVolume = 1.0;
  String? _rainPath;

  bool get enabled => _enabled;
  double get backgroundVolume => _backgroundVolume;
  double get mainVolume => _mainVolume;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    final prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool(_enabledKey) ?? false;
    _backgroundVolume = prefs.getDouble(_backgroundVolumeKey) ?? 0.20;
    _mainVolume = prefs.getDouble(_mainVolumeKey) ?? 1.0;

    if (Platform.isLinux) {
      debugPrint('BackgroundAudio disabled on Linux');
      try {
        await _quranAudio.init();
      } catch (_) {}
      _quranAudio.addListener(_syncWithQuranPlayback);
      return;
    }

    try {
      await _backgroundPlayer.setVolume(_backgroundVolume);
    } catch (e) {
      debugPrint('Background player init failed: $e');
    }
    try {
      await _quranAudio.init();
      await _quranAudio.setVolume(_mainVolume);
    } catch (e) {
      debugPrint('Quran audio init failed: $e');
    }
    _quranAudio.addListener(_syncWithQuranPlayback);
  }

  void _syncWithQuranPlayback() {
    if (_enabled && _quranAudio.isPlaying) {
      _startAmbient();
    } else {
      _pauseAmbient();
    }
  }

  Future<String?> _ensureRainFile() async {
    if (_rainPath != null && await File(_rainPath!).exists()) return _rainPath;

    try {
      final data = await rootBundle.load(_rainAsset);
      final bytes = data.buffer.asUint8List();
      final directory = await getApplicationSupportDirectory();
      final file = File('${directory.path}/quranku_rain_loop.mp3');
      if (!await file.exists() || await file.length() != bytes.length) {
        await file.writeAsBytes(bytes, flush: true);
      }
      _rainPath = file.path;
      return _rainPath;
    } catch (e) {
      debugPrint('Rain background audio is unavailable: $e');
      return null;
    }
  }

  Future<void> _startAmbient() async {
    if (Platform.isLinux) return;
    if (!_enabled || !_quranAudio.isPlaying) return;

    final path = await _ensureRainFile();
    if (path == null) return;

    try {
      if (_backgroundPlayer.audioSource == null) {
        await _backgroundPlayer.setAudioSource(AudioSource.uri(Uri.file(path)));
        await _backgroundPlayer.setLoopMode(LoopMode.one);
      }
      await _backgroundPlayer.setVolume(_backgroundVolume);
      if (!_backgroundPlayer.playing) {
        await _backgroundPlayer.play();
      }
    } catch (e) {
      debugPrint('Unable to start rain background: $e');
    }
  }

  Future<void> _pauseAmbient() async {
    if (Platform.isLinux) return;
    try {
      if (_backgroundPlayer.playing) {
        await _backgroundPlayer.pause();
      }
    } catch (e) {
      debugPrint('Pause ambient failed: $e');
    }
  }

  Future<void> setEnabled(bool value) async {
    _enabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, value);

    if (value && _quranAudio.isPlaying) {
      await _startAmbient();
    } else if (!value) {
      await _pauseAmbient();
    }
    notifyListeners();
  }

  Future<void> setBackgroundVolume(double value) async {
    _backgroundVolume = value.clamp(0.0, 1.0);
    if (!Platform.isLinux) {
      try {
        await _backgroundPlayer.setVolume(_backgroundVolume);
      } catch (e) {
        debugPrint('setBackgroundVolume failed: $e');
      }
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_backgroundVolumeKey, _backgroundVolume);
    notifyListeners();
  }

  Future<void> setMainVolume(double value) async {
    _mainVolume = value.clamp(0.0, 1.0);
    try {
      await _quranAudio.setVolume(_mainVolume);
    } catch (e) {
      debugPrint('setMainVolume failed: $e');
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_mainVolumeKey, _mainVolume);
    notifyListeners();
  }

  Future<void> disposeService() async {
    _quranAudio.removeListener(_syncWithQuranPlayback);
    if (!Platform.isLinux) {
      try {
        await _backgroundPlayer.dispose();
      } catch (e) {
        debugPrint('dispose background failed: $e');
      }
    }
  }

  @override
  void dispose() {
    disposeService();
    super.dispose();
  }
}
