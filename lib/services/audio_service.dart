import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:synchronized/synchronized.dart';
import '../models/surah.dart';
import '../services/api_service.dart';
import '../services/murotal_download_service.dart';
import '../services/widget_service.dart';

enum RepeatMode { none, autoNext, repeatOne }

enum SurahOrder { ascending, descending }

class AudioService extends ChangeNotifier {
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;
  AudioService._internal();

  final AudioPlayer _player = AudioPlayer();
  final Dio _dio = Dio();
  String? _localPath;

  final Map<String, Lock> _downloadLocks = {};
  final Lock _playlistLock = Lock();

  Surah? _currentSurah;
  int _currentAyah = 1;
  int _lastAddedAyah = 0;
  bool _isPlaying = false;
  bool _isBuffering = false;

  RepeatMode _repeatMode = RepeatMode.autoNext;
  SurahOrder _surahOrder = SurahOrder.ascending;

  final bool _isPlayingBismillah = false;
  bool _isCompletionHandled = false;
  bool _isChangingTrack = false;
  int _loadingOperationId = 0;
  Timer? _debounceTimer;
  int? _pendingSurahTarget;

  List<int> _customSurahSequence = [];

  ConcatenatingAudioSource? _playlist;

  Surah? get currentSurah => _currentSurah;
  int get currentAyah => _currentAyah;
  bool get isPlaying => _isPlaying;
  bool get isBuffering => _isBuffering;

  RepeatMode get repeatMode => _repeatMode;
  SurahOrder get surahOrder => _surahOrder;

  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;

  Future<void> seek(Duration position) async {
    final duration = _player.duration;
    if (duration == null) return;
    final clamped = position < Duration.zero
        ? Duration.zero
        : (position > duration ? duration : position);
    await _player.seek(clamped);
  }

  void toggleRepeatMode() {
    if (_repeatMode == RepeatMode.autoNext) {
      _repeatMode = RepeatMode.repeatOne;
    } else if (_repeatMode == RepeatMode.repeatOne) {
      _repeatMode = RepeatMode.none;
    } else {
      _repeatMode = RepeatMode.autoNext;
    }
    notifyListeners();
  }

  void toggleSurahOrder() {
    _surahOrder = _surahOrder == SurahOrder.ascending
        ? SurahOrder.descending
        : SurahOrder.ascending;
    notifyListeners();
  }

  void setCustomSurahSequence(List<int> sequence) {
    _customSurahSequence = sequence;
    notifyListeners();
  }

  void clearCustomSurahSequence() {
    _customSurahSequence = [];
    notifyListeners();
  }

  bool hasNextSurah() {
    if (_currentSurah == null) return false;

    if (_customSurahSequence.isNotEmpty) {
      final currentIndex = _customSurahSequence.indexOf(_currentSurah!.number);
      if (currentIndex == -1) return false;

      if (_surahOrder == SurahOrder.descending) {
        return currentIndex > 0;
      } else {
        return currentIndex < _customSurahSequence.length - 1;
      }
    }

    if (_surahOrder == SurahOrder.descending) {
      return _currentSurah!.number > 1;
    } else {
      return _currentSurah!.number < 114;
    }
  }

  bool hasPrevSurah() {
    if (_currentSurah == null) return false;

    if (_customSurahSequence.isNotEmpty) {
      final currentIndex = _customSurahSequence.indexOf(_currentSurah!.number);
      if (currentIndex == -1) return false;

      if (_surahOrder == SurahOrder.descending) {
        return currentIndex < _customSurahSequence.length - 1;
      } else {
        return currentIndex > 0;
      }
    }

    if (_surahOrder == SurahOrder.descending) {
      return _currentSurah!.number < 114;
    } else {
      return _currentSurah!.number > 1;
    }
  }

  void playNextSurah() {
    if (_currentSurah == null) return;

    final direction = _surahOrder == SurahOrder.ascending ? 1 : -1;
    int baseSurah = _pendingSurahTarget ?? _currentSurah!.number;
    int nextNum = -1;

    if (_customSurahSequence.isNotEmpty) {
      final currentIndex = _customSurahSequence.indexOf(baseSurah);
      if (currentIndex != -1) {
        final nextIndex = currentIndex + direction;
        if (nextIndex >= 0 && nextIndex < _customSurahSequence.length) {
          nextNum = _customSurahSequence[nextIndex];
        }
      }
    } else {
      nextNum = baseSurah + direction;
    }

    if (nextNum != -1 && nextNum >= 1 && nextNum <= 114) {
      _pendingSurahTarget = nextNum;
      _debounceTimer?.cancel();
      _debounceTimer = Timer(const Duration(milliseconds: 500), () {
        final target = _pendingSurahTarget;
        _pendingSurahTarget = null;
        if (target != null) {
          _loadAndPlaySurah(target);
        }
      });
    }
  }

  void playPrevSurah() {
    if (_currentSurah == null) return;

    final direction = _surahOrder == SurahOrder.ascending ? -1 : 1;
    int baseSurah = _pendingSurahTarget ?? _currentSurah!.number;
    int prevNum = -1;

    if (_customSurahSequence.isNotEmpty) {
      final currentIndex = _customSurahSequence.indexOf(baseSurah);
      if (currentIndex != -1) {
        final prevIndex = currentIndex + direction;
        if (prevIndex >= 0 && prevIndex < _customSurahSequence.length) {
          prevNum = _customSurahSequence[prevIndex];
        }
      }
    } else {
      prevNum = baseSurah + direction;
    }

    if (prevNum != -1 && prevNum >= 1 && prevNum <= 114) {
      _pendingSurahTarget = prevNum;
      _debounceTimer?.cancel();
      _debounceTimer = Timer(const Duration(milliseconds: 500), () {
        final target = _pendingSurahTarget;
        _pendingSurahTarget = null;
        if (target != null) {
          _loadAndPlaySurah(target);
        }
      });
    }
  }

  Future<void> init() async {
    if (_localPath != null) return;
    final dir = await getApplicationDocumentsDirectory();
    _localPath = '${dir.path}/audio';
    await Directory(_localPath!).create(recursive: true);

    _player.playerStateStream.listen((state) {
      _isPlaying = state.playing;
      _isBuffering = state.processingState == ProcessingState.buffering ||
          state.processingState == ProcessingState.loading;
      notifyListeners();
    });

    _player.currentIndexStream.listen((index) {
      if (index != null && _playlist != null && index < _playlist!.length) {
        final source = _playlist!.children[index] as UriAudioSource;
        if (source.tag != null && source.tag is int) {
          final newAyah = source.tag as int;
          if (newAyah >= 0 && _currentAyah != newAyah) {
            _currentAyah = newAyah;
            notifyListeners();
            _maintainPlaylistQueue();
          }
        }
      }
    });

    _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        if (!_isChangingTrack && !_isCompletionHandled) {
          _isCompletionHandled = true;
          _handleSurahCompletion();
        }
      } else if (state.processingState != ProcessingState.completed) {
        _isCompletionHandled = false;
      }
    });
  }

  Future<void> playAyah(Surah surah, int ayahNumber) async {
    final int opId = ++_loadingOperationId;
    _currentSurah = surah;
    _currentAyah = ayahNumber;
    _isChangingTrack = true;
    notifyListeners();

    try {
      await _player.stop();
    } catch (_) {}
    if (opId != _loadingOperationId) return;

    try {
      final List<AudioSource> initialSources = [];
      if (ayahNumber == 1 && surah.number != 1 && surah.number != 9) {
        final bismillahPath = await _getFileWithLock(1, 1, onlyCheck: true);
        if (opId != _loadingOperationId) return;
        final uri = bismillahPath != null
            ? Uri.parse(bismillahPath)
            : Uri.parse('https://damarjati1323.github.io/audio/001-001.mp3');
        initialSources.add(AudioSource.uri(uri, tag: 0));
      }

      final targetPath = await _getFileWithLock(surah.number, ayahNumber, onlyCheck: true);
      if (opId != _loadingOperationId) return;
      final targetUri = targetPath != null
          ? Uri.parse(targetPath)
          : Uri.parse('https://damarjati1323.github.io/audio/${surah.number.toString().padLeft(3, '0')}-${ayahNumber.toString().padLeft(3, '0')}.mp3');
      initialSources.add(AudioSource.uri(targetUri, tag: ayahNumber));

      _playlist = ConcatenatingAudioSource(children: initialSources);
      try {
        await _player.setAudioSource(_playlist!);
        _lastAddedAyah = ayahNumber;
      } catch (e) {
        if (e.toString().contains('Platform player') && e.toString().contains('already exists')) {
          await Future.delayed(const Duration(milliseconds: 100));
          if (opId != _loadingOperationId) return;
          await _player.setAudioSource(_playlist!);
          _lastAddedAyah = ayahNumber;
        } else {
          rethrow;
        }
      }

      if (opId != _loadingOperationId) return;
      _isChangingTrack = false;
      _player.play();
      notifyListeners();
      _bufferNextAyahsInBackground(surah, ayahNumber, opId);
    } catch (e) {
      if (opId == _loadingOperationId) {
        debugPrint('Error initializing playlist: $e');
        _isChangingTrack = false;
        notifyListeners();
      }
    }
  }

  Future<void> _bufferNextAyahsInBackground(Surah surah, int startAyah, int opId) async {
    await Future.delayed(const Duration(milliseconds: 100));
    if (opId != _loadingOperationId) return;

    await _playlistLock.synchronized(() async {
      if (opId != _loadingOperationId) return;
      for (int i = 1; i <= 3; i++) {
        final target = startAyah + i;
        if (target <= _lastAddedAyah) continue;
        if (target <= surah.totalAyahs && _playlist != null) {
          try {
            final source = await _resolveAudioSource(surah, target);
            if (_playlist != null && opId == _loadingOperationId) {
              await _playlist!.add(source);
              _lastAddedAyah = target;
            }
          } catch (e) {
            debugPrint('Buffer error for ayah $target: $e');
          }
        }
      }
    });

    if (opId == _loadingOperationId) _prefetch(surah, startAyah);
  }

  bool _isAddingToPlaylist = false;

  void _maintainPlaylistQueue() async {
    if (_playlist == null || _currentSurah == null || _isAddingToPlaylist) return;
    _isAddingToPlaylist = true;
    try {
      await _playlistLock.synchronized(() async {
        await _sanitizePlaylist();
        final index = _player.currentIndex ?? 0;
        final length = _playlist!.length;
        if (length - index <= 2) {
          final lastSource = _playlist!.children.last as UriAudioSource;
          final lastAyahNum = lastSource.tag as int;
          int nextAyahNum = (lastAyahNum == 0) ? 1 : lastAyahNum + 1;
          if (nextAyahNum <= _currentSurah!.totalAyahs) {
            if (nextAyahNum > _lastAddedAyah) {
              final source = await _resolveAudioSource(_currentSurah!, nextAyahNum);
              if (_playlist != null) {
                await _playlist!.add(source);
                _lastAddedAyah = nextAyahNum;
              }
            }
          } else if (!_isPrefetchingNext) {
            _prefetchNextSurahInfo();
          }
        }
        _prefetch(_currentSurah!, _currentAyah);
      });
    } finally {
      _isAddingToPlaylist = false;
    }
  }

  Future<void> _sanitizePlaylist() async {
    if (_playlist == null || _playlist!.length < 2) return;
    try {
      for (int i = _playlist!.length - 1; i > 0; i--) {
        final current = _playlist!.children[i] as UriAudioSource;
        final prev = _playlist!.children[i - 1] as UriAudioSource;
        if (current.tag == prev.tag) {
          await _playlist!.removeAt(i);
        }
      }
    } catch (e) {
      debugPrint('Sanitizer warning: $e');
    }
  }

  bool _isPrefetchingNext = false;

  Future<void> _prefetchNextSurahInfo() async {
    if (_currentSurah == null) return;
    _isPrefetchingNext = true;
    try {
      final nextSurahNum = _currentSurah!.number + 1;
      if (nextSurahNum <= 114) {
        final api = ApiService();
        await api.fetchSurahDetails(nextSurahNum);
        await _getFileWithLock(1, 1);
        await _getFileWithLock(nextSurahNum, 1);
      }
    } catch (e) {
      debugPrint('Prefetch Warning: $e');
    } finally {
      _isPrefetchingNext = false;
    }
  }

  void _handleSurahCompletion() async {
    if (_currentSurah == null) return;
    if (_repeatMode == RepeatMode.repeatOne) {
      playAyah(_currentSurah!, 1);
    } else if (_repeatMode == RepeatMode.autoNext) {
      playNextSurah();
    } else {
      _player.stop();
    }
  }

  Future<void> _loadAndPlaySurah(int number) async {
    final int opId = ++_loadingOperationId;
    try {
      final surahs = await ApiService().fetchSurahs();
      if (opId != _loadingOperationId) return;
      final nextSurah = surahs.firstWhere(
        (s) => s.number == number,
        orElse: () => Surah(number: number, name: 'Surah $number', nameAr: '', type: '', totalAyahs: 7),
      );
      _currentSurah = nextSurah;
      _currentAyah = 1;
      _lastAddedAyah = 0;
      notifyListeners();
      await _playWithBismillahFirst(nextSurah, opId);
    } catch (e) {
      if (opId == _loadingOperationId) {
        debugPrint('Cannot load surah $number: $e');
        _player.stop();
        _isChangingTrack = false;
        notifyListeners();
      }
    }
  }

  Future<void> _playWithBismillahFirst(Surah surah, int opId) async {
    _isChangingTrack = true;
    notifyListeners();
    try {
      await _player.stop();
    } catch (_) {}
    if (opId != _loadingOperationId) return;

    try {
      final List<AudioSource> initialSources = [];
      if (surah.number != 1 && surah.number != 9) {
        final bismillahPath = await _getFileWithLock(1, 1, onlyCheck: true);
        if (opId != _loadingOperationId) return;
        final uri = bismillahPath != null
            ? Uri.parse(bismillahPath)
            : Uri.parse('https://damarjati1323.github.io/audio/001-001.mp3');
        initialSources.add(AudioSource.uri(uri, tag: 0));
      }
      final ayah1Path = await _getFileWithLock(surah.number, 1, onlyCheck: true);
      if (opId != _loadingOperationId) return;
      final ayah1Uri = ayah1Path != null
          ? Uri.parse(ayah1Path)
          : Uri.parse('https://damarjati1323.github.io/audio/${surah.number.toString().padLeft(3, '0')}-001.mp3');
      initialSources.add(AudioSource.uri(ayah1Uri, tag: 1));

      _playlist = ConcatenatingAudioSource(children: initialSources);
      await _player.setAudioSource(_playlist!);
      _lastAddedAyah = 1;
      if (opId != _loadingOperationId) return;
      _isChangingTrack = false;
      _player.play();
      notifyListeners();
      _bufferNextAyahsInBackground(surah, 1, opId);
    } catch (e) {
      if (opId == _loadingOperationId) {
        debugPrint('Error playing surah: $e');
        _isChangingTrack = false;
        notifyListeners();
      }
    }
  }

  Future<AudioSource> _resolveAudioSource(Surah surah, int ayahNum) async {
    final path = await _getFileWithLock(surah.number, ayahNum, onlyCheck: true);
    if (path != null) return AudioSource.uri(Uri.parse(path), tag: ayahNum);
    final fileName = '${surah.number.toString().padLeft(3, '0')}-${ayahNum.toString().padLeft(3, '0')}.mp3';
    return AudioSource.uri(Uri.parse('https://damarjati1323.github.io/audio/$fileName'), tag: ayahNum);
  }

  Future<void> pause() async => _player.pause();
  Future<void> resume() async => _player.play();
  Future<void> stop() async => _player.stop();

  Future<void> next() async {
    if (_player.hasNext) {
      await _player.seekToNext();
    } else {
      _handleSurahCompletion();
    }
  }

  Future<void> skipToNextSurah() async {
    if (_currentSurah != null) {
      await _player.stop();
      playNextSurah();
    }
  }

  Future<void> previous() async {
    if (_player.hasPrevious) {
      await _player.seekToPrevious();
    } else if (_currentSurah != null && _currentAyah > 1) {
      playAyah(_currentSurah!, _currentAyah - 1);
    }
  }

  Future<void> _prefetch(Surah surah, int startAyah) async {
    for (int i = 1; i <= 5; i++) {
      final targetAyah = startAyah + i;
      if (targetAyah > surah.totalAyahs) break;
      _getFileWithLock(surah.number, targetAyah).then((_) {});
    }
  }

  Future<String?> _getFileWithLock(int surahNum, int ayahNum, {bool onlyCheck = false}) async {
    if (_localPath == null) await init();
    final fileName = '${surahNum.toString().padLeft(3, '0')}-${ayahNum.toString().padLeft(3, '0')}.mp3';
    final lock = _downloadLocks.putIfAbsent(fileName, () => Lock());
    return lock.synchronized(() async {
      final localFilePath = '$_localPath/$fileName';
      final file = File(localFilePath);
      if (await file.exists()) {
        final length = await file.length();
        if (length > 1024) return file.uri.toString();
        await file.delete();
      }
      if (onlyCheck) return null;
      final url = 'https://damarjati1323.github.io/audio/$fileName';
      final tempFile = '$localFilePath.tmp';
      try {
        await _dio.download(url, tempFile, options: Options(responseType: ResponseType.bytes));
        final downloaded = File(tempFile);
        if (await downloaded.exists() && await downloaded.length() > 1024) {
          await downloaded.rename(localFilePath);
          return File(localFilePath).uri.toString();
        }
      } catch (e) {
        debugPrint('Download error $fileName: $e');
      }
      try {
        final temp = File(tempFile);
        if (await temp.exists()) await temp.delete();
      } catch (_) {}
      return null;
    });
  }
}