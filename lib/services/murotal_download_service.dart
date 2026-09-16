import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import '../models/surah.dart';
import 'api_service.dart';
import 'equran_service.dart';
import 'settings_service.dart';

enum MurotalDownloadStatus { idle, downloading, paused }

class MurotalDownloadService extends ChangeNotifier {
  static final MurotalDownloadService _instance =
      MurotalDownloadService._internal();
  factory MurotalDownloadService() => _instance;
  MurotalDownloadService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  final ApiService _api = ApiService();
  final Dio _dio = Dio();
  String? _localPath;

  // State
  List<int> queue = [];
  List<int> downloadedSurahs = [];
  MurotalDownloadStatus status = MurotalDownloadStatus.idle;
  double progress = 0.0;
  int currentSurah = 0;
  int currentAyah = 0;
  int totalAyahs = 0;

  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;

    // Initialize local path
    final dir = await getApplicationDocumentsDirectory();
    _localPath = '${dir.path}/audio';
    await Directory(_localPath!).create(recursive: true);

    final prefs = await SharedPreferences.getInstance();

    // Load persisted data
    final downloadedList =
        prefs.getStringList('murotal_downloaded_surahs') ?? [];
    downloadedSurahs = downloadedList.map((e) => int.parse(e)).toList();

    final queueList = prefs.getStringList('murotal_download_queue') ?? [];
    queue = queueList.map((e) => int.parse(e)).toList();

    currentSurah = prefs.getInt('murotal_current_download_surah') ?? 0;
    currentAyah = prefs.getInt('murotal_last_downloaded_ayah') ?? 0;

    debugPrint(
      'MurotalDownloadService Init: Queue=${queue.length}, Downloaded=${downloadedSurahs.length}',
    );
    debugPrint('Resume State: Surah=$currentSurah, LastAyah=$currentAyah');

    // Init Notifications — must set Linux settings when targeting Linux (R-35)
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/launcher_icon');
    const LinuxInitializationSettings initializationSettingsLinux =
        LinuxInitializationSettings(defaultActionName: 'Open notification');
    const InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          linux: initializationSettingsLinux,
        );

    try {
      await flutterLocalNotificationsPlugin.initialize(
        settings: initializationSettings,
      );
    } catch (e) {
      debugPrint('Notifications init failed: $e');
    }

    _isInitialized = true;
    notifyListeners();
    // Scan for existing files in background to update status
    scanDownloadedFiles();
    // Rescan when qari changes so offline badges switch correctly
    String lastQari = SettingsService().qariId;
    SettingsService().addListener(() {
      final currentQari = SettingsService().qariId;
      if (currentQari != lastQari) {
        lastQari = currentQari;
        scanDownloadedFiles();
      }
    });
  }

  String _qariDir() {
    // Per-qari folder; downloads and offline checks are scoped to selected qari
    // so that switching qari correctly reflects offline availability and
    // playback no longer sticks to Misyari.
    return '$_localPath/${SettingsService().qariId}';
  }

  /// Scans the local directory for compiled surahs
  Future<void> scanDownloadedFiles() async {
    if (_localPath == null) {
      final dir = await getApplicationDocumentsDirectory();
      _localPath = '${dir.path}/audio';
    }

    final Map<int, int> surahAyahCounts = {};
    final qariDirFile = Directory(_qariDir());
    final legacyDir = Directory(_localPath!);
    final dirsToScan = <Directory>[];
    if (await qariDirFile.exists()) dirsToScan.add(qariDirFile);
    // For default qari, also include legacy root files for backward compat
    if (SettingsService().qariId == EquranService.defaultQariId &&
        await legacyDir.exists()) {
      dirsToScan.add(legacyDir);
    }
    if (dirsToScan.isEmpty) return;

    try {
      for (final dir in dirsToScan) {
        final List<FileSystemEntity> files = dir.listSync();

      for (final file in files) {
        if (file is File) {
          final filename = file.uri.pathSegments.last;
          if (filename.endsWith('.mp3') && filename.contains('-')) {
            try {
              final parts = filename.replaceAll('.mp3', '').split('-');
              if (parts.length == 2) {
                final surahNum = int.parse(parts[0]);
                surahAyahCounts[surahNum] =
                    (surahAyahCounts[surahNum] ?? 0) + 1;
              }
            } catch (e) {
              // Ignore malformed filenames
            }
          }
        }
      }
      }

      // We need total ayahs for each surah to confirm completeness
      // If we don't have them cached in memory elsewhere, we might need to fetch or hardcode.
      // However, ApiService().fetchSurahs() caches in memory usually.
      List<Surah> surahs = [];
      try {
        surahs = await _api.fetchSurahs();
      } catch (e) {
        debugPrint('Error fetching surahs for scan: $e');
        return;
      }

      // Rebuild downloaded list for current qari (offline state is per-qari)
      final newDownloaded = <int>[];
      for (final surah in surahs) {
        final localCount = surahAyahCounts[surah.number] ?? 0;
        if (localCount >= surah.totalAyahs) {
          newDownloaded.add(surah.number);
        }
      }
      newDownloaded.sort();
      downloadedSurahs.sort();
      final changed =
          newDownloaded.length != downloadedSurahs.length ||
          !newDownloaded.every((e) => downloadedSurahs.contains(e));
      if (changed) {
        downloadedSurahs = newDownloaded;
        await _saveDownloadedList();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error scanning downloaded files: $e');
    }
  }

  /// Checks if a specific Surah is fully downloaded (e.g. after streaming)
  Future<void> checkSurahCompleteness(int surahNumber) async {
    // If already marked, skip
    if (downloadedSurahs.contains(surahNumber)) return;

    if (_localPath == null) {
      final dir = await getApplicationDocumentsDirectory();
      _localPath = '${dir.path}/audio';
    }

    final qariDir = Directory(_qariDir());
    final legacyDir = Directory(_localPath!);
    final hasQariDir = await qariDir.exists();
    final hasLegacyDir = await legacyDir.exists();
    if (!hasQariDir &&
        !(SettingsService().qariId == EquranService.defaultQariId &&
            hasLegacyDir)) {
      return;
    }

    try {
      // Get total ayahs for this Surah
      // We try to fetch from API cache first
      int totalAyahs = 0;
      try {
        final surahs = await _api.fetchSurahs();
        final surah = surahs.firstWhere(
          (s) => s.number == surahNumber,
          orElse: () => Surah(
            number: surahNumber,
            name: '',
            nameAr: '',
            type: '',
            totalAyahs: 0,
          ),
        );
        totalAyahs = surah.totalAyahs;
      } catch (e) {
        debugPrint('Error fetching surah info for check: $e');
        return;
      }

      if (totalAyahs == 0) return;

      // Optimize: Check specific files instead of listing all
      // We assume standard naming: SSS-AAA.mp3. For default qari, legacy root
      // files count as valid offline cache as well.
      bool allAyahsExist = true;
      for (int i = 1; i <= totalAyahs; i++) {
        final filename =
            '${surahNumber.toString().padLeft(3, '0')}-${i.toString().padLeft(3, '0')}.mp3';
        final qariFile = File('${qariDir.path}/$filename');
        if (await qariFile.exists()) continue;
        if (SettingsService().qariId == EquranService.defaultQariId) {
          final legacyFile = File('${legacyDir.path}/$filename');
          if (await legacyFile.exists()) continue;
        }
        allAyahsExist = false;
        break;
      }

      if (allAyahsExist) {
        debugPrint(
          'Surah $surahNumber detected as fully downloaded via stream.',
        );
        downloadedSurahs.add(surahNumber);
        await _saveDownloadedList();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error checking completeness for Surah $surahNumber: $e');
    }
  }

  Future<void> _saveDownloadedList() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'murotal_downloaded_surahs',
      downloadedSurahs.map((e) => e.toString()).toList(),
    );
    debugPrint('Saved Downloaded Surahs: ${downloadedSurahs.length} items');
  }

  Future<void> _saveQueue() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'murotal_download_queue',
      queue.map((e) => e.toString()).toList(),
    );
    debugPrint('Saved Queue: ${queue.length} items');
  }

  void addToQueue(int surahNumber) {
    if (!queue.contains(surahNumber) &&
        !downloadedSurahs.contains(surahNumber)) {
      queue.add(surahNumber);
      _saveQueue();
      notifyListeners();
    }
  }

  void removeFromQueue(int surahNumber) {
    queue.remove(surahNumber);
    _saveQueue();
    notifyListeners();
  }

  Future<void> startDownload() async {
    if (queue.isEmpty) return;
    if (status == MurotalDownloadStatus.downloading) return;

    status = MurotalDownloadStatus.downloading;
    notifyListeners();

    // Get surah list for total ayahs info
    final surahs = await _api.fetchSurahs();

    // Process queue
    while (queue.isNotEmpty && status == MurotalDownloadStatus.downloading) {
      currentSurah = queue.first;

      // Find surah info
      final surahInfo = surahs.firstWhere(
        (s) => s.number == currentSurah,
        orElse: () => Surah(
          number: currentSurah,
          name: 'Surah $currentSurah',
          nameAr: '',
          type: '',
          totalAyahs: 7,
        ),
      );
      totalAyahs = surahInfo.totalAyahs;

      // Resume Logic
      int startFrom = 1;
      final prefs = await SharedPreferences.getInstance();
      int? savedSurah = prefs.getInt('murotal_current_download_surah');
      int? savedAyah = prefs.getInt('murotal_last_downloaded_ayah');

      if (savedSurah == currentSurah &&
          savedAyah != null &&
          savedAyah < totalAyahs) {
        startFrom = savedAyah + 1;
      } else {
        // New surah starting
        await prefs.setInt('murotal_current_download_surah', currentSurah);
        await prefs.setInt('murotal_last_downloaded_ayah', 0);
      }

      for (int i = startFrom; i <= totalAyahs; i++) {
        if (status != MurotalDownloadStatus.downloading)
          break; // Check for pause/stop

        currentAyah = i;
        progress = (i / totalAyahs);
        notifyListeners();
        _showProgressNotification(currentSurah, i, totalAyahs);

        try {
          await _downloadAyahAudio(currentSurah, i);
          // Persist progress
          await prefs.setInt('murotal_last_downloaded_ayah', i);
        } catch (e) {
          debugPrint('Error downloading audio Surah $currentSurah Ayah $i: $e');
        }
      }

      if (status == MurotalDownloadStatus.downloading) {
        // Surah completed
        queue.removeAt(0);
        _saveQueue();

        // Reset progress trackers
        await prefs.remove('murotal_current_download_surah');
        await prefs.remove('murotal_last_downloaded_ayah');

        downloadedSurahs.add(currentSurah);
        await _saveDownloadedList();
        notifyListeners();
      }
    }

    if (queue.isEmpty) {
      status = MurotalDownloadStatus.idle;
      progress = 0.0;
      currentSurah = 0;
      currentAyah = 0;
      totalAyahs = 0;
      await flutterLocalNotificationsPlugin.cancel(id: 1);
      notifyListeners();
    }
  }

  Future<void> _downloadAyahAudio(int surahNum, int ayahNum) async {
    if (_localPath == null) await init();

    final String fileName =
        '${surahNum.toString().padLeft(3, '0')}-${ayahNum.toString().padLeft(3, '0')}.mp3';
    final qari = SettingsService().qariId;
    final dirPath = _qariDir();
    await Directory(dirPath).create(recursive: true);
    final String localFilePath = '$dirPath/$fileName';
    final File file = File(localFilePath);

    // Skip if already exists and valid
    if (await file.exists()) {
      final length = await file.length();
      if (length > 1024) {
        debugPrint('Audio already exists: $fileName (qari $qari)');
        return;
      } else {
        await file.delete();
      }
    }

    final String url = EquranService.audioAyahUrl(qari, surahNum, ayahNum);
    try {
      await _dio.download(url, localFilePath);
      debugPrint('Downloaded: $fileName');
    } catch (e) {
      debugPrint('Download failed for $url: $e');
      rethrow;
    }
  }

  void pauseDownload() {
    status = MurotalDownloadStatus.paused;
    notifyListeners();
  }

  void stopDownload() async {
    status = MurotalDownloadStatus.idle;
    progress = 0.0;
    currentSurah = 0;
    currentAyah = 0;
    totalAyahs = 0;
    queue.clear();

    // Clear persistence
    _saveQueue();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('murotal_current_download_surah');
    await prefs.remove('murotal_last_downloaded_ayah');

    await flutterLocalNotificationsPlugin.cancel(id: 1);
    notifyListeners();
  }

  /// Check if a surah is fully downloaded
  bool isSurahDownloaded(int surahNumber) {
    return downloadedSurahs.contains(surahNumber);
  }

  /// Get download status text
  String getStatusText() {
    switch (status) {
      case MurotalDownloadStatus.idle:
        return 'Idle';
      case MurotalDownloadStatus.downloading:
        return 'Downloading';
      case MurotalDownloadStatus.paused:
        return 'Paused';
    }
  }

  Future<void> _showProgressNotification(
    int surah,
    int current,
    int total,
  ) async {
    final AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          'murotal_download_channel',
          'Murotal Downloads',
          channelDescription: 'Show murotal download progress',
          importance: Importance.low,
          priority: Priority.low,
          showProgress: true,
          maxProgress: total,
          progress: current,
          onlyAlertOnce: true,
        );
    final NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );
    await flutterLocalNotificationsPlugin.show(
      id: 1,
      title: 'Downloading Surah $surah',
      body: 'Ayah $current of $total',
      notificationDetails: platformChannelSpecifics,
    );
  }
}
