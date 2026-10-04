import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';

/// Service singleton untuk mengelola semua preferensi aplikasi
class SettingsService extends ChangeNotifier {
  static final SettingsService _instance = SettingsService._internal();
  factory SettingsService() => _instance;
  SettingsService._internal();

  bool _isInitialized = false;

  // Settings values
  List<Map<String, String>> _availableTranslations = [
    {'code': 'id-indonesian', 'name': 'Indonesia'},
    {'code': 'en-sahih', 'name': 'English'},
  ];
  String _defaultTranslation = 'id-indonesian';
  ThemeMode _themeMode = ThemeMode.dark;
  bool _useArabicNumerals = false;
  String _scriptStyle = 'uthmani';
  bool _showTransliteration = false;
  String _reciterId = 'alafasy';

  // Getters
  String get defaultTranslation => _defaultTranslation;
  ThemeMode get themeMode => _themeMode;
  bool get useArabicNumerals => _useArabicNumerals;
  String get scriptStyle => _scriptStyle;
  bool get showTransliteration => _showTransliteration;
  String get reciterId => _reciterId;

  static const List<Map<String, String>> reciters = [
    {'id': 'alafasy', 'name': 'Mishary Rashid Alafasy'},
    {'id': 'abdulbaset', 'name': 'Abdul Basit Abdul Samad'},
    {'id': 'ghamdi', 'name': 'Saad Al-Ghamdi'},
    {'id': 'husary', 'name': 'Mahmoud Khalil Al-Husary'},
    {'id': 'sudais', 'name': 'Abdul Rahman Al-Sudais'},
    {'id': 'maher', 'name': 'Maher Al-Muaiqly'},
    {'id': 'minshawi', 'name': 'Mohamed Siddiq Al-Minshawi'},
    {'id': 'shuraim', 'name': 'Saud Al-Shuraim'},
  ];
  bool get isInitialized => _isInitialized;

  // SharedPreferences keys
  static const String _keyDefaultTranslation = 'settings_default_translation';
  static const String _keyThemeMode = 'settings_theme_mode';
  static const String _keyUseArabicNumerals = 'settings_use_arabic_numerals';
  static const String _keyScriptStyle = 'settings_script_style';
  static const String _keyShowTransliteration = 'settings_show_transliteration';
  static const String _keyReciterId = 'settings_reciter_id';

  /// Initialize and load saved settings
  Future<void> init() async {
    if (_availableTranslations.length <= 2) {
      await _loadEditions();
    }

    if (_isInitialized) return;

    final prefs = await SharedPreferences.getInstance();

    _defaultTranslation =
        prefs.getString(_keyDefaultTranslation) ?? 'id-indonesian';

    final themeModeString = prefs.getString(_keyThemeMode) ?? 'dark';
    _themeMode = themeModeString == 'light' ? ThemeMode.light : ThemeMode.dark;

    _useArabicNumerals = prefs.getBool(_keyUseArabicNumerals) ?? false;
    final savedScript = prefs.getString(_keyScriptStyle) ?? 'uthmani';
    _scriptStyle = savedScript == 'indopak' ? 'indopak' : 'uthmani';
    _showTransliteration = prefs.getBool(_keyShowTransliteration) ?? false;
    final savedReciter = prefs.getString(_keyReciterId) ?? 'alafasy';
    _reciterId = reciters.any((e) => e['id'] == savedReciter) ? savedReciter : 'alafasy';

    // Migration fix: English code changed from en-english to en-sahih
    if (_defaultTranslation == 'en-english') {
      _defaultTranslation = 'en-sahih';
      await prefs.setString(_keyDefaultTranslation, 'en-sahih');
    }

    // Migration fix: ar-arabic is invalid, fallback to id-indonesian
    if (_defaultTranslation == 'ar-arabic') {
      _defaultTranslation = 'id-indonesian';
      await prefs.setString(_keyDefaultTranslation, 'id-indonesian');
      await prefs.setString(_keyDefaultTranslation, 'id-indonesian');
    }

    await _loadEditions();

    _isInitialized = true;
    debugPrint(
      'SettingsService initialized: translation=$_defaultTranslation, theme=$_themeMode, arabicNumerals=$_useArabicNumerals',
    );
  }

  Future<void> _loadEditions() async {
    try {
      final jsonString = await rootBundle.loadString('assets/editions.json');
      final Map<String, dynamic> data = json.decode(jsonString);
      final List<dynamic> editionsRaw = data['editions'];

      final Set<String> pinned = {'id-indonesian', 'en-sahih'};
      final List<Map<String, String>> others = [];

      for (final edition in editionsRaw) {
        if (edition is String && !pinned.contains(edition)) {
          // Filter out known tafsirs or non-translations
          if (edition.contains('jalalayn') ||
              edition.contains('muyassar') ||
              edition.contains('muntakhab') ||
              edition == 'arabic') {
            continue;
          }

          others.add({'code': edition, 'name': formatEditionName(edition)});
        }
      }

      // Sort others alphabetically by name
      others.sort((a, b) => a['name']!.compareTo(b['name']!));

      _availableTranslations = [
        {'code': 'id-indonesian', 'name': 'Indonesia'},
        {'code': 'en-sahih', 'name': 'English'},
        ...others,
      ];
    } catch (e) {
      debugPrint('Error loading editions in SettingsService: $e');
    }
  }

  String formatEditionName(String editionId) {
    final parts = editionId.split('-');
    final langCode = parts[0];

    final langMap = {
      'id': 'Indonesia',
      'en': 'English',
      'ar': 'Arabic',
      'az': 'Azerbaijani',
      'bg': 'Bulgarian',
      'bn': 'Bengali',
      'bs': 'Bosnian',
      'cs': 'Czech',
      'de': 'German',
      'dv': 'Divehi',
      'es': 'Spanish',
      'fa': 'Persian',
      'fr': 'French',
      'ha': 'Hausa',
      'hi': 'Hindi',
      'it': 'Italian',
      'ja': 'Japanese',
      'ko': 'Korean',
      'ku': 'Kurdish',
      'ml': 'Malayalam',
      'ms': 'Malay',
      'nl': 'Dutch',
      'no': 'Norwegian',
      'pl': 'Polish',
      'pt': 'Portuguese',
      'ro': 'Romanian',
      'ru': 'Russian',
      'sd': 'Sindhi',
      'so': 'Somali',
      'sq': 'Albanian',
      'sv': 'Swedish',
      'sw': 'Swahili',
      'ta': 'Tamil',
      'tg': 'Tajik',
      'th': 'Thai',
      'tr': 'Turkish',
      'tt': 'Tatar',
      'ug': 'Uyghur',
      'ur': 'Urdu',
      'uz': 'Uzbek',
      'zh': 'Chinese',
    };

    String langName = langMap[langCode] ?? langCode.toUpperCase();

    if (parts.length > 1) {
      String suffix = parts[1];
      if (suffix.toLowerCase() == langName.toLowerCase()) {
        return langName;
      }
      suffix = suffix[0].toUpperCase() + suffix.substring(1);
      return "$langName ($suffix)";
    }
    return langName;
  }

  /// Set default translation language
  Future<void> setDefaultTranslation(String edition) async {
    if (_defaultTranslation == edition) return;

    _defaultTranslation = edition;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyDefaultTranslation, edition);
    notifyListeners();
  }

  /// Set theme mode (dark/light)
  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;

    _themeMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _keyThemeMode,
      mode == ThemeMode.light ? 'light' : 'dark',
    );
    notifyListeners();
  }

  /// Set whether to use Arabic numerals for ayah numbers
  Future<void> setUseArabicNumerals(bool value) async {
    if (_useArabicNumerals == value) return;

    _useArabicNumerals = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyUseArabicNumerals, value);
    notifyListeners();
  }

  Future<void> setScriptStyle(String style) async {
    final value = style == 'indopak' ? 'indopak' : 'uthmani';
    if (_scriptStyle == value) return;
    _scriptStyle = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyScriptStyle, value);
    notifyListeners();
  }

  Future<void> setShowTransliteration(bool value) async {
    if (_showTransliteration == value) return;
    _showTransliteration = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyShowTransliteration, value);
    notifyListeners();
  }

  Future<void> setReciter(String id) async {
    if (!reciters.any((e) => e['id'] == id)) return;
    if (_reciterId == id) return;
    _reciterId = id;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyReciterId, id);
    notifyListeners();
  }

  /// Convert number to Arabic numeral string if enabled
  String formatNumber(int number) {
    if (!useArabicNumerals) return number.toString();
    const arabicDigits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    return number
        .toString()
        .split('')
        .map((digit) {
          return arabicDigits[int.parse(digit)];
        })
        .join('');
  }

  String formatString(String input) {
    if (!useArabicNumerals) return input;
    const arabicDigits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    return input.replaceAllMapped(RegExp(r'[0-9]'), (match) {
      return arabicDigits[int.parse(match.group(0)!)];
    });
  }

  /// Get storage info (cache sizes)
  Future<Map<String, dynamic>> getStorageInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();

    int cacheCount = 0;
    int totalSize = 0;

    // Count cache entries
    for (final key in keys) {
      if (key.startsWith('cache_') || key.startsWith('prayer_times_')) {
        cacheCount++;
        final value = prefs.getString(key);
        if (value != null) {
          totalSize += value.length;
        }
      }
    }

    // Get audio files size
    int audioFilesSize = 0;
    int audioFilesCount = 0;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final audioDir = Directory('${dir.path}/audio');
      if (await audioDir.exists()) {
        await for (final entity in audioDir.list(recursive: true)) {
          if (entity is File) {
            audioFilesCount++;
            audioFilesSize += await entity.length();
          }
        }
      }
    } catch (e) {
      debugPrint('Error getting audio files size: $e');
    }

    return {
      'cacheCount': cacheCount,
      'cacheSize': totalSize,
      'audioFilesCount': audioFilesCount,
      'audioFilesSize': audioFilesSize,
      'totalSize': totalSize + audioFilesSize,
    };
  }

  /// Clear all cached data (but preserve settings)
  Future<void> clearAllCache() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().toList();

    for (final key in keys) {
      if (key.startsWith('cache_') ||
          key.startsWith('prayer_times_') ||
          key.startsWith('downloaded_') ||
          key.startsWith('download_') ||
          key.startsWith('murotal_') ||
          key.startsWith('current_download') ||
          key.startsWith('last_downloaded')) {
        await prefs.remove(key);
      }
    }

    // Clear audio files
    try {
      final dir = await getApplicationDocumentsDirectory();
      final audioDir = Directory('${dir.path}/audio');
      if (await audioDir.exists()) {
        await audioDir.delete(recursive: true);
      }
    } catch (e) {
      debugPrint('Error clearing audio files: $e');
    }

    debugPrint('All cache cleared');
    notifyListeners();
  }

  /// Get list of available translation editions
  List<Map<String, String>> getAvailableTranslations() {
    return _availableTranslations;
  }

  /// Format bytes to human readable string
  String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024)
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  /// Get detailed audio storage info
  Future<List<Map<String, dynamic>>> getAudioStorageDetails() async {
    final List<Map<String, dynamic>> details = [];
    try {
      final dir = await getApplicationDocumentsDirectory();
      final audioDir = Directory('${dir.path}/audio');
      if (await audioDir.exists()) {
        final List<FileSystemEntity> files = await audioDir.list().toList();

        // Group files by Surah
        final Map<int, List<File>> surahFiles = {};

        for (final entity in files) {
          if (entity is File) {
            final filename = entity.uri.pathSegments.last;
            final parts = filename.split('-');
            if (parts.length == 2) {
              final surahNum = int.tryParse(parts[0]);
              if (surahNum != null) {
                surahFiles.putIfAbsent(surahNum, () => []).add(entity);
              }
            }
          }
        }

        // Calculate details for each Surah
        for (final entry in surahFiles.entries) {
          final surahNum = entry.key;
          final files = entry.value;
          int totalSize = 0;
          int maxAyah = 0;

          for (final file in files) {
            totalSize += await file.length();
            final filename = file.uri.pathSegments.last;
            final parts = filename.split('-');
            if (parts.length == 2) {
              final ayahPart = parts[1].split('.')[0];
              final ayahNum = int.tryParse(ayahPart) ?? 0;
              if (ayahNum > maxAyah) maxAyah = ayahNum;
            }
          }

          details.add({
            'surahNumber': surahNum,
            'totalSize': totalSize,
            'fileCount': files.length,
            'maxAyah': maxAyah,
          });
        }
      }
    } catch (e) {
      debugPrint('Error getting audio storage details: $e');
    }

    // Sort by Surah number
    details.sort(
      (a, b) => (a['surahNumber'] as int).compareTo(b['surahNumber'] as int),
    );
    return details;
  }

  /// Get detailed text cache info (Surahs)
  Future<List<Map<String, dynamic>>> getSurahStorageDetails() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    final Map<int, int> surahSizes = {}; // SurahNum -> Size in bytes
    final Map<int, bool> surahHasArabic = {};

    for (final key in keys) {
      if (key.startsWith('cache_surah_')) {
        // Format: cache_surah_{number}_{edition}_v4 or cache_surah_{number}_arabic_v4
        final parts = key.split('_');
        if (parts.length >= 3) {
          final surahNum = int.tryParse(parts[2]);
          if (surahNum != null) {
            final value = prefs.getString(key);
            if (value != null) {
              surahSizes[surahNum] = (surahSizes[surahNum] ?? 0) + value.length;
              // If we have any cache for this surah, we assume it's downloaded
              // but for "Manage Storage" we just need to know if it's there.
              // The UI will look up the totalAyahs from metadata.
            }
          }
        }
      }
    }

    final List<Map<String, dynamic>> details = [];
    surahSizes.forEach((surahNum, size) {
      details.add({
        'surahNumber': surahNum,
        'totalSize': size,
        // We don't parse the JSON here to save performance.
        // The UI will map surahNumber to totalAyahs from surah_list.json
      });
    });

    details.sort(
      (a, b) => (a['surahNumber'] as int).compareTo(b['surahNumber'] as int),
    );
    return details;
  }

  /// Get detailed text cache info (Translations)
  Future<List<Map<String, dynamic>>> getTranslationStorageDetails() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    final Map<String, int> translationSizes = {}; // EditionKey -> Size
    final Map<String, int> translationCounts =
        {}; // EditionKey -> Count of Surahs

    for (final key in keys) {
      if (key.startsWith('cache_surah_') && !key.contains('_arabic_')) {
        // key: cache_surah_1_id-indonesian_v4
        // parts: [cache, surah, 1, id-indonesian, v4]
        final parts = key.split('_');
        if (parts.length >= 5) {
          // Reconstruct edition if it contains underscores
          // But for safety let's stick to index 3 as our editions are simple
          String edition = parts[3];

          final value = prefs.getString(key);
          if (value != null) {
            translationSizes[edition] =
                (translationSizes[edition] ?? 0) + value.length;
            translationCounts[edition] = (translationCounts[edition] ?? 0) + 1;
          }
        }
      }
    }

    final List<Map<String, dynamic>> details = [];
    translationSizes.forEach((edition, size) {
      details.add({
        'edition': edition,
        'name': formatEditionName(edition),
        'totalSize': size,
        'surahCount': translationCounts[edition] ?? 0,
      });
    });

    details.sort(
      (a, b) => (a['name'] as String).compareTo(b['name'] as String),
    );
    return details;
  }

  /// Delete audio for specific Surah
  Future<void> deleteAudioForSurah(int surahNumber) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final audioDir = Directory('${dir.path}/audio');
      if (await audioDir.exists()) {
        final List<FileSystemEntity> files = await audioDir.list().toList();
        for (final entity in files) {
          if (entity is File) {
            final filename = entity.uri.pathSegments.last;
            if (filename.startsWith(
              '${surahNumber.toString().padLeft(3, '0')}-',
            )) {
              await entity.delete();
            }
          }
        }
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error deleting audio for surah $surahNumber: $e');
    }
  }

  /// Delete all cache for a specific Surah
  Future<void> deleteSurahCache(int surahNumber) async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs
        .getKeys()
        .toList(); // Copy list to avoid concurrent modification issues

    for (final key in keys) {
      if (key.startsWith('cache_surah_${surahNumber}_')) {
        await prefs.remove(key);
      }
    }
    notifyListeners();
  }

  /// Delete all cache for a specific Translation Edition
  Future<void> deleteTranslationCache(String edition) async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().toList();

    for (final key in keys) {
      // key format: cache_surah_{num}_{edition}_v4
      if (key.contains('_$edition')) {
        await prefs.remove(key);
      }
    }
    notifyListeners();
  }
}
