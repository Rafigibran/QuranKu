import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppLanguageService extends ChangeNotifier {
  static final AppLanguageService _instance = AppLanguageService._internal();
  factory AppLanguageService() => _instance;
  AppLanguageService._internal();

  static const _keyLanguage = 'app_language';
  Locale _locale = const Locale('id');

  Locale get locale => _locale;
  bool get isEnglish => _locale.languageCode == 'en';
  String get languageCode => _locale.languageCode;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_keyLanguage) ?? 'id';
    _locale = code == 'en' ? const Locale('en') : const Locale('id');
  }

  Future<void> setLanguage(String code) async {
    final locale = code == 'en' ? const Locale('en') : const Locale('id');
    if (_locale == locale) return;
    _locale = locale;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLanguage, locale.languageCode);
    notifyListeners();
  }

  String get languageName => isEnglish ? 'English' : 'Indonesia';

  String t(String key) {
    final data = isEnglish ? _en : _id;
    return data[key] ?? _id[key] ?? key;
  }

  static const Map<String, String> _id = {
    'quran': 'Al-Quran',
    'times': 'Jadwal',
    'murotal': 'Murotal',
    'playlist': 'Daftar Putar',
    'qibla': 'Kiblat',
    'settings': 'Pengaturan',
    'double_tap_exit': 'Ketuk dua kali untuk keluar',
    'general': 'Umum',
    'theme': 'Tema',
    'light': 'Terang',
    'dark': 'Gelap',
    'default_translation': 'Terjemahan Default',
    'arabic_numerals': 'Angka Arab',
    'arabic_numerals_desc': 'Gunakan ١٢٣ bukan 123',
    'language': 'Bahasa Aplikasi',
    'language_desc': 'Pilih bahasa antarmuka aplikasi',
    'storage': 'Penyimpanan',
    'clear_cache': 'Bersihkan Cache',
    'clear_cache_desc': 'Menghapus file sementara untuk mengosongkan ruang',
    'manage_storage': 'Kelola Penyimpanan',
    'about': 'Tentang',
    'about_developer': 'Tentang Developer',
    'built_for_ummah': 'Dibuat dengan ❤️ untuk Umat',
    'read_reflect_act': 'Baca. Renungkan. Amalkan.',
    'select_language': 'Pilih Bahasa',
    'select_theme': 'Pilih Tema',
    'cancel': 'Batal',
    'clear_all_cache': 'Bersihkan Semua Cache?',
    'clear_all_cache_desc': 'Teks Al-Quran, terjemahan, jadwal salat, dan file audio yang diunduh akan dihapus.',
    'clear_all': 'Bersihkan Semua',
    'english': 'English',
    'indonesian': 'Indonesia',
  };

  static const Map<String, String> _en = {
    'quran': 'Quran',
    'times': 'Prayer Times',
    'murotal': 'Murotal',
    'playlist': 'Playlist',
    'qibla': 'Qibla',
    'settings': 'Settings',
    'double_tap_exit': 'Double-tap to exit',
    'general': 'General',
    'theme': 'Theme',
    'light': 'Light',
    'dark': 'Dark',
    'default_translation': 'Default Translation',
    'arabic_numerals': 'Arabic Numerals',
    'arabic_numerals_desc': 'Use ١٢٣ instead of 123',
    'language': 'App Language',
    'language_desc': 'Choose the application interface language',
    'storage': 'Storage',
    'clear_cache': 'Clear Cache',
    'clear_cache_desc': 'Remove temporary files to free up space',
    'manage_storage': 'Manage Storage',
    'about': 'About',
    'about_developer': 'About Developer',
    'built_for_ummah': 'Built with ❤️ for the Ummah',
    'read_reflect_act': 'Read. Reflect. Act.',
    'select_language': 'Select Language',
    'select_theme': 'Select Theme',
    'cancel': 'Cancel',
    'clear_all_cache': 'Clear All Cache?',
    'clear_all_cache_desc': 'Downloaded Quran text, translations, prayer times and audio files will be removed.',
    'clear_all': 'Clear All',
    'english': 'English',
    'indonesian': 'Indonesian',
  };
}
