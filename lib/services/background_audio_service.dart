import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:synchronized/synchronized.dart';

import 'audio_service.dart';

/// Manages optional rain ambience independently from Quran playback.
class BackgroundAudioService extends ChangeNotifier {
  static final BackgroundAudioService _instance =
      BackgroundAudioService._internal();
  factory BackgroundAudioService() => _instance;
  BackgroundAudioService._internal();

  static const String _rainAsset = 'assets/rain_loop.mp3';
  static const String _enabledKey = 'background_audio_enabled';
  static const String _backgroundVolumeKey = 'background_audio_volume';
  static const String _mainVolumeKey = 'main_audio_volume';

  final AudioPlayer _backgroundPlayer = AudioPlayer(
    handleInterruptions: false,
    handleAudioSessionActivation: false,
    androidApplyAudioAttributes: false,
  );
  final AudioService _quranAudio = AudioService();
  final Lock _transitionLock = Lock();

  Future<void>? _initFuture;
  bool _initialized = false;
  bool _enabled = false;
  double _backgroundVolume = 0.16;
  double _mainVolume = 1.0;
  bool _disposed = false;
  int _intentVersion = 0;
  bool _pendingEnableIntent = false;
  bool? _lastQuranPlaying;

  bool get enabled => _enabled;
  double get backgroundVolume => _backgroundVolume;
  double get mainVolume => _mainVolume;
  bool get isPlaying => _backgroundPlayer.playing;

  Future<void> init() => _initFuture ??= _initialize();

  Future<void> _initialize() async {
    if (_initialized || _disposed) return;

    final prefs = await SharedPreferences.getInstance();
    if (!_pendingEnableIntent) {
      _enabled = prefs.getBool(_enabledKey) ?? false;
    }
    _backgroundVolume =
        (prefs.getDouble(_backgroundVolumeKey) ?? 0.16)
            .clamp(0.0, 1.0)
            .toDouble();
    _mainVolume =
        (prefs.getDouble(_mainVolumeKey) ?? 1.0).clamp(0.0, 1.0).toDouble();

    await _backgroundPlayer.setVolume(_backgroundVolume);
    await _quranAudio.init();
    await _quranAudio.setVolume(_mainVolume);
    _quranAudio.addListener(_syncWithQuranPlayback);
    _lastQuranPlaying = _quranAudio.isPlaying;

    _initialized = true;
    await _reconcileAmbient();
  }

  void _syncWithQuranPlayback() {
    if (!_initialized || _disposed) return;

    final playing = _quranAudio.isPlaying;
    if (_lastQuranPlaying == playing) return;
    _lastQuranPlaying = playing;

    if (!playing) {
      unawaited(_stopAmbientImmediately());
      return;
    }

    unawaited(_reconcileAmbient());
  }

  Future<void> _stopAmbientImmediately() async {
    if (_disposed) return;
    try {
      await _backgroundPlayer.stop();
    } catch (error) {
      debugPrint('Unable to stop rain background: $error');
    }
  }

  Future<void> _reconcileAmbient() async {
    if (_disposed) return;
    if (!_initialized) {
      await init();
      if (_disposed) return;
    }

    final version = _intentVersion;
    await _transitionLock.synchronized(() async {
      await _reconcileAmbientLocked(version);
    });
  }

  Future<void> _reconcileAmbientLocked(int version) async {
    if (_disposed || version != _intentVersion) return;

    final shouldPlay = _enabled && _quranAudio.isPlaying;
    if (!shouldPlay) {
      await _stopAmbientImmediately();
      return;
    }

    try {
      if (_backgroundPlayer.audioSource == null) {
        await _backgroundPlayer.setAudioSource(
          AudioSource.asset(_rainAsset),
          preload: true,
        );
        await _backgroundPlayer.setLoopMode(LoopMode.one);
      }

      await _backgroundPlayer.setVolume(_backgroundVolume);

      if (_disposed ||
          version != _intentVersion ||
          !_enabled ||
          !_quranAudio.isPlaying) {
        await _stopAmbientImmediately();
        return;
      }

      if (!_backgroundPlayer.playing) {
        await _backgroundPlayer.play();
      }
    } catch (error, stackTrace) {
      debugPrint('Unable to start rain background: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> setEnabled(bool value) async {
    if (_disposed) return;

    final version = ++_intentVersion;
    _pendingEnableIntent = true;
    _enabled = value;

    // Publish the user's intent synchronously. It never waits for the
    // player, a lock, initialization, or SharedPreferences.
    notifyListeners();

    if (!value) {
      unawaited(_disableForVersion(version));
      return;
    }

    unawaited(_enableForVersion(version));
  }

  Future<void> _disableForVersion(int version) async {
    try {
      await _backgroundPlayer.stop();

      final prefs = await SharedPreferences.getInstance();
      if (!_disposed && version == _intentVersion) {
        await prefs.setBool(_enabledKey, false);
      }
    } catch (error, stackTrace) {
      debugPrint('Unable to disable rain background: $error');
      debugPrintStack(stackTrace: stackTrace);
    } finally {
      if (version == _intentVersion) {
        _pendingEnableIntent = false;
      }
      if (!_disposed && version == _intentVersion) notifyListeners();
    }
  }

  Future<void> _enableForVersion(int version) async {
    try {
      await init();
      if (_disposed || version != _intentVersion || !_enabled) return;

      await _transitionLock.synchronized(() async {
        if (_disposed || version != _intentVersion || !_enabled) return;
        await _reconcileAmbientLocked(version);
      });

      if (!_disposed && version == _intentVersion) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_enabledKey, true);
      }
    } catch (error, stackTrace) {
      debugPrint('Unable to enable rain background: $error');
      debugPrintStack(stackTrace: stackTrace);
    } finally {
      if (version == _intentVersion) {
        _pendingEnableIntent = false;
      }
      if (!_disposed && version == _intentVersion) notifyListeners();
    }
  }

  Future<void> setBackgroundVolume(double value) async {
    if (_disposed) return;

    final next = value.clamp(0.0, 1.0).toDouble();
    _backgroundVolume = next;
    await _backgroundPlayer.setVolume(next);
    if (!_disposed) notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    if (!_disposed && _backgroundVolume == next) {
      await prefs.setDouble(_backgroundVolumeKey, next);
    }
  }

  Future<void> setMainVolume(double value) async {
    if (_disposed) return;

    final next = value.clamp(0.0, 1.0).toDouble();
    _mainVolume = next;
    await _quranAudio.setVolume(next);
    if (!_disposed) notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    if (!_disposed && _mainVolume == next) {
      await prefs.setDouble(_mainVolumeKey, next);
    }
  }

  Future<void> disposeService() async {
    if (_disposed) return;
    _disposed = true;
    _intentVersion++;
    _quranAudio.removeListener(_syncWithQuranPlayback);
    try {
      await _backgroundPlayer.stop();
    } catch (_) {}
    await _backgroundPlayer.dispose();
  }

  @override
  void dispose() {
    unawaited(disposeService());
    super.dispose();
  }
}