import 'dart:io';
import 'dart:convert';
import 'dart:ui' show PlatformDispatcher;
import 'package:flutter/foundation.dart' show setEquals;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';

import '../data/daily_duas.dart';

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

  // UI language — null = follow system (best practice). Persisted as 'id' / 'en'.
  Locale? _appLocale;
  Locale? get appLocale => _appLocale;
  bool get isFollowingSystem => _appLocale == null;

  /// Device language captured at startup; used while [appLocale] is null.
  String _systemLanguageCode = 'id';

  /// Language the UI is actually rendering in: explicit choice, else device.
  String get effectiveLanguageCode =>
      _appLocale?.languageCode ?? _systemLanguageCode;

  /// Selected tafsir edition. Null = derived from [effectiveLanguageCode].
  String? _tafsirEditionId;

  // Reading display toggles — persisted so user preference survives restart
  bool _showArabic = true;
  bool _showTranslation = true;
  bool _showTransliteration = true;
  // Asian (Muslim Pro style) is the default — Indonesian Kemenag SKB 1987 simplified
  String _transliterationEdition = 'id-transliteration';
  double _arabicFontScale = 1.0;
  double _translationFontScale = 1.0;
  double _transliterationFontScale = 1.0;
  // Tajwid — best practice: off by default, user opts in.
  // Per-kata dihapus total (Akurasi Quran): terjemahan per kata yang ditebak
  // per indeks rawan salah dan tidak tolerabel untuk Holy Quran.
  bool _showTajwid = false;

  // Murotal reciter (equran.id v2, 6 qari). '05' Misyari = suara file offline.
  String _qariId = '05';
  // Lyrics stage in full player: live sync highlight, ON by default
  bool _showLyrics = true;

  // Bookmark & last read & read-ayahs (checkmark per ayat di dalam surah)
  Set<String> _bookmarks = {};
  // Saved collections: Asmaul Husna numbers + Doa titles (stable keys).
  Set<String> _savedAsmaul = {};
  Set<String> _savedDuas = {};
  Set<String> _readAyahs = {};
  int? _lastSurah;
  int? _lastAyah;

  /// Built-in tafsir: Kemenag (equran.id), Indonesian.
  static const String kemenagTafsirId = 'kemenag-id';

  /// Tafsir used by default when the UI language is English.
  static const String defaultEnglishTafsirId = 'en-tafsir-al-mukhtasar';

  // Getters
  String get defaultTranslation => _defaultTranslation;
  ThemeMode get themeMode => _themeMode;
  bool get useArabicNumerals => _useArabicNumerals;
  bool get isInitialized => _isInitialized;
  bool get showArabic => _showArabic;
  bool get showTranslation => _showTranslation;
  bool get showTransliteration => _showTransliteration;
  String get transliterationEdition => _transliterationEdition;
  String get qariId => _qariId;

  /// Tafsir edition shown by the reader. Falls back to the language default
  /// when the user has never picked one explicitly.
  String get tafsirEditionId =>
      _tafsirEditionId ??
      (effectiveLanguageCode == 'en'
          ? defaultEnglishTafsirId
          : kemenagTafsirId);

  bool get showLyrics => _showLyrics;
  double get arabicFontScale => _arabicFontScale;
  double get translationFontScale => _translationFontScale;
  double get transliterationFontScale => _transliterationFontScale;
  bool get showTajwid => _showTajwid;
  Set<String> get bookmarks => Set.unmodifiable(_bookmarks);
  Set<String> get readAyahs => Set.unmodifiable(_readAyahs);
  int? get lastSurah => _lastSurah;
  int? get lastAyah => _lastAyah;

  bool isBookmarked(int surah, int ayah) =>
      _bookmarks.contains('${surah}_$ayah');
  Set<String> get savedAsmaul => Set.unmodifiable(_savedAsmaul);
  Set<String> get savedDuas => Set.unmodifiable(_savedDuas);
  bool isAsmaulSaved(int number) => _savedAsmaul.contains('$number');
  bool isDuaSaved(String duaId) => _savedDuas.contains(duaId.trim());
  bool isRead(int surah, int ayah) => _readAyahs.contains('${surah}_$ayah');

  // SharedPreferences keys
  static const String _keyDefaultTranslation = 'settings_default_translation';
  static const String _keyThemeMode = 'settings_theme_mode';
  static const String _keyUseArabicNumerals = 'settings_use_arabic_numerals';
  static const String _keyShowArabic = 'settings_show_arabic';
  static const String _keyShowTranslation = 'settings_show_translation';
  static const String _keyShowTransliteration = 'settings_show_transliteration';
  static const String _keyTransliterationEdition =
      'settings_transliteration_edition';
  static const String _keyArabicFontScale = 'settings_arabic_font_scale';
  static const String _keyTranslationFontScale =
      'settings_translation_font_scale';
  static const String _keyTransliterationFontScale =
      'settings_transliteration_font_scale';
  static const String _keyShowTajwid = 'settings_show_tajwid';
  static const String _keyQariId = 'settings_qari_id';
  static const String _keyAppLocale = 'app_locale';
  static const String _keyTafsirEdition = 'settings_tafsir_edition';
  static const String _keyShowLyrics = 'settings_show_lyrics';
  static const String _keyBookmarks = 'settings_bookmarks';
  static const String _keySavedAsmaul = 'settings_saved_asmaul';
  static const String _keySavedDuas = 'settings_saved_duas';
  static const String _keyReadAyahs = 'settings_read_ayahs';
  static const String _keyLastSurah = 'settings_last_surah';
  static const String _keyLastAyah = 'settings_last_ayah';

  /// Initialize and load saved settings
  Future<void> init() async {
    _systemLanguageCode =
        PlatformDispatcher.instance.locale.languageCode == 'en' ? 'en' : 'id';

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
    _showArabic = prefs.getBool(_keyShowArabic) ?? true;
    _showTranslation = prefs.getBool(_keyShowTranslation) ?? true;
    _showTransliteration = prefs.getBool(_keyShowTransliteration) ?? true;
    _transliterationEdition =
        prefs.getString(_keyTransliterationEdition) ?? 'id-transliteration';
    // Migrate legacy editions to Indonesian (equran.id v2 Latin, Kemenag).
    if (_transliterationEdition == 'en-transliteration' ||
        _transliterationEdition == 'asian') {
      _transliterationEdition = 'id-transliteration';
      await prefs.setString(
        _keyTransliterationEdition,
        'id-transliteration',
      );
    }
    _arabicFontScale = prefs.getDouble(_keyArabicFontScale) ?? 1.0;
    _translationFontScale = prefs.getDouble(_keyTranslationFontScale) ?? 1.0;
    _transliterationFontScale =
        prefs.getDouble(_keyTransliterationFontScale) ?? 1.0;
    _showTajwid = prefs.getBool(_keyShowTajwid) ?? false;
    _qariId = prefs.getString(_keyQariId) ?? '05';
    _showLyrics = prefs.getBool(_keyShowLyrics) ?? true;
    final localeCode = prefs.getString(_keyAppLocale);
    if (localeCode == 'en') {
      _appLocale = const Locale('en', 'US');
    } else if (localeCode == 'id') {
      _appLocale = const Locale('id', 'ID');
    } else {
      _appLocale = null; // follow system
    }
    _tafsirEditionId = prefs.getString(_keyTafsirEdition);
    await prefs.remove('settings_show_word_by_word');

    final bm = prefs.getStringList(_keyBookmarks);
    if (bm != null) _bookmarks = bm.toSet();
    final sa = prefs.getStringList(_keySavedAsmaul);
    if (sa != null) _savedAsmaul = sa.toSet();
    final sd = prefs.getStringList(_keySavedDuas);
    if (sd != null) _savedDuas = sd.toSet();
    await _migrateLegacyDuaBookmarks(prefs);
    final rd = prefs.getStringList(_keyReadAyahs);
    if (rd != null) _readAyahs = rd.toSet();
    _lastSurah = prefs.getInt(_keyLastSurah);
    _lastAyah = prefs.getInt(_keyLastAyah);

    if (_defaultTranslation == 'en-english') {
      _defaultTranslation = 'en-sahih';
      await prefs.setString(_keyDefaultTranslation, 'en-sahih');
    }

    if (_defaultTranslation == 'ar-arabic') {
      _defaultTranslation = 'id-indonesian';
      await prefs.setString(_keyDefaultTranslation, 'id-indonesian');
    }

    await _loadEditions();

    _isInitialized = true;
    debugPrint(
      'SettingsService initialized: translation=$_defaultTranslation, transliteration=$_transliterationEdition showTranslit=$_showTransliteration',
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
          if (edition == 'arabic') continue;
          // Previously filtered jalalayn/muyassar/muntakhab — now exposed as tafsir options
          others.add({'code': edition, 'name': formatEditionName(edition)});
        }
      }

      others.sort((a, b) => a['name']!.compareTo(b['name']!));

      _availableTranslations = [
        {'code': 'id-indonesian', 'name': 'Indonesia'},
        {'code': 'en-sahih', 'name': 'English'},
        {'code': 'en-asad', 'name': 'English (Asad)'},
        ...others,
      ];
    } catch (e) {
      debugPrint('Error loading editions in SettingsService: $e');
    }
  }

  List<Map<String, String>> getTransliterationEditions() {
    return [
      {
        'code': 'id-transliteration',
        'name': transliterationName('id-transliteration'),
      },
      {
        'code': 'en-transliteration',
        'name': transliterationName('en-transliteration'),
      },
      {
        'code': 'tr-transliteration',
        'name': transliterationName('tr-transliteration'),
      },
    ];
  }

  String transliterationName(String code) {
    if (code == 'id-transliteration') return 'Indonesian';
    if (code == 'asian') return 'Asian (legacy)';
    if (code == 'en-transliteration') return 'International';
    if (code == 'tr-transliteration') return 'Turkish';
    return formatEditionName(code);
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

  Future<void> setDefaultTranslation(String edition) async {
    if (_defaultTranslation == edition) return;
    _defaultTranslation = edition;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyDefaultTranslation, edition);
    notifyListeners();
  }

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

  Future<void> setUseArabicNumerals(bool value) async {
    if (_useArabicNumerals == value) return;
    _useArabicNumerals = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyUseArabicNumerals, value);
    notifyListeners();
  }

  Future<void> setShowArabic(bool v) async {
    if (_showArabic == v) return;
    _showArabic = v;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyShowArabic, v);
    notifyListeners();
  }

  Future<void> setShowTranslation(bool v) async {
    if (_showTranslation == v) return;
    _showTranslation = v;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyShowTranslation, v);
    notifyListeners();
  }

  Future<void> setShowTransliteration(bool v) async {
    if (_showTransliteration == v) return;
    _showTransliteration = v;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyShowTransliteration, v);
    notifyListeners();
  }

  Future<void> setTransliterationEdition(String e) async {
    if (_transliterationEdition == e) return;
    _transliterationEdition = e;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyTransliterationEdition, e);
    notifyListeners();
  }

  Future<void> setQariId(String id) async {
    if (_qariId == id) return;
    _qariId = id;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyQariId, id);
    notifyListeners();
  }

  Future<void> setShowLyrics(bool v) async {
    if (_showLyrics == v) return;
    _showLyrics = v;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyShowLyrics, v);
    notifyListeners();
  }

  Future<void> setAppLocale(Locale? locale) async {
    // Normalize: only id/en persisted; null = follow system
    if (locale != null &&
        locale.languageCode != 'id' &&
        locale.languageCode != 'en') {
      return;
    }
    if (_appLocale == locale) return;
    _appLocale = locale == null
        ? null
        : Locale(locale.languageCode, locale.countryCode);
    final prefs = await SharedPreferences.getInstance();
    if (_appLocale == null) {
      await prefs.remove(_keyAppLocale);
    } else {
      await prefs.setString(_keyAppLocale, _appLocale!.languageCode);
    }
    await _alignTranslationWithLanguage(prefs);
    notifyListeners();
  }

  /// Keeps the Quran translation edition in step with the UI language.
  ///
  /// The user can still override it afterwards via [setDefaultTranslation];
  /// the next language change re-aligns it again.
  Future<void> _alignTranslationWithLanguage(SharedPreferences prefs) async {
    final lang = effectiveLanguageCode;
    final alreadyMatches = lang == 'en'
        ? _defaultTranslation.startsWith('en-')
        : _defaultTranslation.startsWith('id-');
    if (alreadyMatches) return;
    final preferred = lang == 'en' ? 'en-sahih' : 'id-indonesian';
    _defaultTranslation = preferred;
    await prefs.setString(_keyDefaultTranslation, preferred);
  }

  /// Picks the tafsir edition shown by the reader. Clears back to the
  /// language default when [id] is empty.
  Future<void> setTafsirEdition(String id) async {
    final prefs = await SharedPreferences.getInstance();
    if (id.isEmpty) {
      if (_tafsirEditionId == null) return;
      _tafsirEditionId = null;
      await prefs.remove(_keyTafsirEdition);
      notifyListeners();
      return;
    }
    if (_tafsirEditionId == id) return;
    _tafsirEditionId = id;
    await prefs.setString(_keyTafsirEdition, id);
    notifyListeners();
  }

  Future<void> setArabicFontScale(double v) async {
    v = v.clamp(0.85, 1.4);
    if (_arabicFontScale == v) return;
    _arabicFontScale = v;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyArabicFontScale, v);
    notifyListeners();
  }

  Future<void> setTranslationFontScale(double v) async {
    v = v.clamp(0.85, 1.3);
    if (_translationFontScale == v) return;
    _translationFontScale = v;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyTranslationFontScale, v);
    notifyListeners();
  }

  Future<void> setTransliterationFontScale(double v) async {
    v = v.clamp(0.85, 1.3);
    if (_transliterationFontScale == v) return;
    _transliterationFontScale = v;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyTransliterationFontScale, v);
    notifyListeners();
  }

  Future<void> setShowTajwid(bool v) async {
    if (_showTajwid == v) return;
    _showTajwid = v;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyShowTajwid, v);
    notifyListeners();
  }

  Future<void> toggleBookmark(int surah, int ayah) async {
    final key = '${surah}_$ayah';
    if (_bookmarks.contains(key)) {
      _bookmarks.remove(key);
    } else {
      _bookmarks.add(key);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_keyBookmarks, _bookmarks.toList());
    notifyListeners();
  }

  Future<void> toggleAsmaulSaved(int number) async {
    final key = '$number';
    if (_savedAsmaul.contains(key)) {
      _savedAsmaul.remove(key);
    } else {
      _savedAsmaul.add(key);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_keySavedAsmaul, _savedAsmaul.toList());
    notifyListeners();
  }

  /// Rewrites pre-i18n dua bookmarks (Indonesian titles) to the stable ids
  /// introduced with [DailyDua.id].
  ///
  /// Keys that match no bundled dua are left alone: remote equran.id duas were
  /// already keyed by their API name, which is never localized.
  Future<void> _migrateLegacyDuaBookmarks(SharedPreferences prefs) async {
    if (_savedDuas.isEmpty) return;
    final legacyIds = legacyDuaBookmarkIds();
    final migrated = {for (final key in _savedDuas) legacyIds[key] ?? key};
    if (setEquals(migrated, _savedDuas)) return;
    _savedDuas = migrated;
    await prefs.setStringList(_keySavedDuas, _savedDuas.toList());
  }

  /// Toggles a saved dua. [duaId] is the stable [DailyDua.id], not the
  /// displayed title — titles change with the UI language.
  Future<void> toggleDuaSaved(String duaId) async {
    final key = duaId.trim();
    if (key.isEmpty) return;
    if (_savedDuas.contains(key)) {
      _savedDuas.remove(key);
    } else {
      _savedDuas.add(key);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_keySavedDuas, _savedDuas.toList());
    notifyListeners();
  }

  /// Toggle tanda sudah-dibaca per ayat (checkmark di dalam surah).
  Future<void> toggleRead(int surah, int ayah) async {
    final key = '${surah}_$ayah';
    if (_readAyahs.contains(key)) {
      _readAyahs.remove(key);
    } else {
      _readAyahs.add(key);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_keyReadAyahs, _readAyahs.toList());
    notifyListeners();
  }

  Future<void> setLastRead(int surah, int ayah) async {
    _lastSurah = surah;
    _lastAyah = ayah;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyLastSurah, surah);
    await prefs.setInt(_keyLastAyah, ayah);
    notifyListeners();
  }

  Future<void> clearLastRead() async {
    _lastSurah = null;
    _lastAyah = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyLastSurah);
    await prefs.remove(_keyLastAyah);
    notifyListeners();
  }

  String formatNumber(int number) {
    if (!useArabicNumerals) return number.toString();
    const arabicDigits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    return number
        .toString()
        .split('')
        .map((digit) => arabicDigits[int.parse(digit)])
        .join('');
  }

  String formatString(String input) {
    if (!useArabicNumerals) return input;
    const arabicDigits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    return input.replaceAllMapped(
      RegExp(r'[0-9]'),
      (match) => arabicDigits[int.parse(match.group(0)!)],
    );
  }

  Future<Map<String, dynamic>> getStorageInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();

    int cacheCount = 0;
    int totalSize = 0;

    for (final key in keys) {
      if (key.startsWith('cache_') ||
          key.startsWith('prayer_times_') ||
          key.startsWith('cache_translit_')) {
        cacheCount++;
        final value = prefs.getString(key);
        if (value != null) totalSize += value.length;
      }
    }

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

  Future<void> clearAllCache() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().toList();

    for (final key in keys) {
      if (key.startsWith('cache_') ||
          key.startsWith('cache_translit_') ||
          key.startsWith('prayer_times_') ||
          key.startsWith('downloaded_') ||
          key.startsWith('download_') ||
          key.startsWith('murotal_') ||
          key.startsWith('current_download') ||
          key.startsWith('last_downloaded')) {
        await prefs.remove(key);
      }
    }

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

  List<Map<String, String>> getAvailableTranslations() =>
      _availableTranslations;

  String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024)
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  Future<List<Map<String, dynamic>>> getAudioStorageDetails() async {
    final List<Map<String, dynamic>> details = [];
    try {
      final dir = await getApplicationDocumentsDirectory();
      final audioDir = Directory('${dir.path}/audio');
      if (await audioDir.exists()) {
        final List<FileSystemEntity> files = await audioDir.list().toList();
        final Map<int, List<File>> surahFiles = {};
        for (final entity in files) {
          if (entity is File) {
            final filename = entity.uri.pathSegments.last;
            final parts = filename.split('-');
            if (parts.length == 2) {
              final surahNum = int.tryParse(parts[0]);
              if (surahNum != null)
                surahFiles.putIfAbsent(surahNum, () => []).add(entity);
            }
          }
        }
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
    details.sort(
      (a, b) => (a['surahNumber'] as int).compareTo(b['surahNumber'] as int),
    );
    return details;
  }

  Future<List<Map<String, dynamic>>> getSurahStorageDetails() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    final Map<int, int> surahSizes = {};
    for (final key in keys) {
      if (key.startsWith('cache_surah_') || key.startsWith('cache_translit_')) {
        final parts = key.split('_');
        if (parts.length >= 3) {
          final surahNum = int.tryParse(parts[2]);
          if (surahNum != null) {
            final value = prefs.getString(key);
            if (value != null)
              surahSizes[surahNum] = (surahSizes[surahNum] ?? 0) + value.length;
          }
        }
      }
    }
    final List<Map<String, dynamic>> details = [];
    surahSizes.forEach(
      (surahNum, size) =>
          details.add({'surahNumber': surahNum, 'totalSize': size}),
    );
    details.sort(
      (a, b) => (a['surahNumber'] as int).compareTo(b['surahNumber'] as int),
    );
    return details;
  }

  Future<List<Map<String, dynamic>>> getTranslationStorageDetails() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    final Map<String, int> translationSizes = {};
    final Map<String, int> translationCounts = {};
    for (final key in keys) {
      if ((key.startsWith('cache_surah_') ||
              key.startsWith('cache_translit_')) &&
          !key.contains('_arabic_')) {
        final parts = key.split('_');
        if (parts.length >= 5) {
          String edition = parts[3];
          // transliteration keys have extra segment
          if (key.startsWith('cache_translit_'))
            edition = parts[3] + (parts.length > 4 ? '-${parts[4]}' : '');
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
    translationSizes.forEach(
      (edition, size) => details.add({
        'edition': edition,
        'name': formatEditionName(edition),
        'totalSize': size,
        'surahCount': translationCounts[edition] ?? 0,
      }),
    );
    details.sort(
      (a, b) => (a['name'] as String).compareTo(b['name'] as String),
    );
    return details;
  }

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
            ))
              await entity.delete();
          }
        }
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error deleting audio for surah $surahNumber: $e');
    }
  }

  Future<void> deleteSurahCache(int surahNumber) async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().toList();
    for (final key in keys) {
      if (key.startsWith('cache_surah_${surahNumber}_') ||
          key.startsWith('cache_translit_${surahNumber}_'))
        await prefs.remove(key);
    }
    notifyListeners();
  }

  Future<void> deleteTranslationCache(String edition) async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().toList();
    for (final key in keys) {
      if (key.contains('_$edition')) await prefs.remove(key);
    }
    notifyListeners();
  }
}
