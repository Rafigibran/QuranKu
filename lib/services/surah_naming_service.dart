import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Controls the Latin display names used for Surah titles.
/// The Indonesian form follows the Arab-Latin transliteration guidance used
/// by the Indonesian Ministry of Religious Affairs / SKB No. 158/1987 and
/// No. 0543b/U/1987. The existing API/edition name remains available as the
/// international form.
class SurahNamingService extends ChangeNotifier {
  static final SurahNamingService _instance = SurahNamingService._internal();
  factory SurahNamingService() => _instance;
  SurahNamingService._internal();

  static const _key = 'settings_indonesian_transliteration';
  bool _useIndonesian = true;
  bool _initialized = false;

  bool get useIndonesianTransliteration => _useIndonesian;

  static const Map<int, String> indonesianNames = {
    1: 'Al-Fatihah', 2: 'Al-Baqarah', 3: 'Ali Imran', 4: 'An-Nisa',
    5: "Al-Ma'idah", 6: "Al-An'am", 7: "Al-A'raf", 8: 'Al-Anfal',
    9: 'At-Taubah', 10: 'Yunus', 11: 'Hud', 12: 'Yusuf', 13: "Ar-Ra'd",
    14: 'Ibrahim', 15: 'Al-Hijr', 16: 'An-Nahl', 17: "Al-Isra'",
    18: 'Al-Kahf', 19: 'Maryam', 20: 'Ta-Ha', 21: 'Al-Anbiya', 22: 'Al-Hajj',
    23: "Al-Mu'minun", 24: 'An-Nur', 25: 'Al-Furqan', 26: "Asy-Syu'ara",
    27: 'An-Naml', 28: 'Al-Qasas', 29: "Al-'Ankabut", 30: 'Ar-Rum',
    31: 'Luqman', 32: 'As-Sajdah', 33: 'Al-Ahzab', 34: "Saba'", 35: 'Fatir',
    36: 'Ya Sin', 37: 'As-Saffat', 38: 'Sad', 39: 'Az-Zumar', 40: 'Ghafir',
    41: 'Fussilat', 42: 'Asy-Syura', 43: 'Az-Zukhruf', 44: 'Ad-Dukhan',
    45: 'Al-Jasiyah', 46: 'Al-Ahqaf', 47: 'Muhammad', 48: 'Al-Fath',
    49: 'Al-Hujurat', 50: 'Qaf', 51: 'Az-Zariyat', 52: 'At-Tur', 53: 'An-Najm',
    54: 'Al-Qamar', 55: 'Ar-Rahman', 56: "Al-Waqi'ah", 57: 'Al-Hadid',
    58: 'Al-Mujadalah', 59: 'Al-Hasyr', 60: 'Al-Mumtahanah', 61: 'As-Saff',
    62: "Al-Jumu'ah", 63: 'Al-Munafiqun', 64: 'At-Tagabun', 65: 'At-Talaq',
    66: 'At-Tahrim', 67: 'Al-Mulk', 68: 'Al-Qalam', 69: 'Al-Haqqah',
    70: "Al-Ma'arij", 71: 'Nuh', 72: 'Al-Jinn', 73: 'Al-Muzzammil',
    74: 'Al-Muddassir', 75: 'Al-Qiyamah', 76: 'Al-Insan', 77: 'Al-Mursalat',
    78: "An-Naba'", 79: "An-Nazi'at", 80: 'Abasa', 81: 'At-Takwir',
    82: 'Al-Infitar', 83: 'Al-Mutaffifin', 84: 'Al-Insyiqaq', 85: 'Al-Buruj',
    86: 'At-Tariq', 87: "Al-A'la", 88: 'Al-Gasyiyah', 89: 'Al-Fajr',
    90: 'Al-Balad', 91: 'Asy-Syams', 92: 'Al-Lail', 93: 'Ad-Duha',
    94: 'Asy-Syarh', 95: 'At-Tin', 96: "Al-'Alaq", 97: 'Al-Qadr',
    98: 'Al-Bayyinah', 99: 'Az-Zalzalah', 100: 'Al-Adiyat', 101: "Al-Qari'ah",
    102: 'At-Takasur', 103: 'Al-Asr', 104: 'Al-Humazah', 105: 'Al-Fil',
    106: 'Quraisy', 107: 'Al-Maun', 108: 'Al-Kausar', 109: 'Al-Kafirun',
    110: 'An-Nasr', 111: 'Al-Lahab', 112: 'Al-Ikhlas', 113: 'Al-Falaq', 114: 'An-Nas',
  };

  Future<void> init() async {
    if (_initialized) return;
    final prefs = await SharedPreferences.getInstance();
    _useIndonesian = prefs.getBool(_key) ?? true;
    _initialized = true;
  }

  Future<void> setUseIndonesianTransliteration(bool value) async {
    if (_useIndonesian == value) return;
    _useIndonesian = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, value);
    notifyListeners();
  }

  String displayName(int number, String internationalName) {
    if (!_useIndonesian) return internationalName;
    return indonesianNames[number] ?? internationalName;
  }
}
