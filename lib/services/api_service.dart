import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/ayah.dart';
import '../models/surah.dart';
import 'quran_external_service.dart';

class ApiService {
  static const String baseUrl = 'https://quran-api.damarcreative.my.id/api';
  static const String _detailCacheVersion = 'v5';

  // Keeps recently opened Surahs instantly available while the app is running.
  static final Map<String, List<Ayah>> _memorySurahCache = {};

  static String _detailsKey(int surahNumber, String edition) =>
      '$surahNumber::$edition';

  /// Synchronous lookup used by the reader screen so an already-opened Surah
  /// can render immediately without another loading state.
  static List<Ayah>? getCachedSurahDetails(
    int surahNumber, {
    String edition = 'id-indonesian',
  }) {
    return _memorySurahCache[_detailsKey(surahNumber, edition)];
  }

  List<Ayah> _decodeAyahs(dynamic raw) {
    if (raw is! List) return <Ayah>[];
    return raw.map<Ayah>((item) {
      final map = item as Map<String, dynamic>;
      final wordsRaw = map['words'];
      final words = <QuranWord>[];
      if (wordsRaw is List) {
        for (final rawWord in wordsRaw) {
          if (rawWord is Map<String, dynamic>) {
            words.add(
              QuranWord(
                arabic: rawWord['arabic']?.toString() ?? '',
                translation: rawWord['translation']?.toString() ?? '',
              ),
            );
          }
        }
      }
      return Ayah(
        number: (map['number'] as num?)?.toInt() ?? 0,
        arabic: map['arabic']?.toString() ?? '',
        translation: map['translation']?.toString() ?? '',
        indopak: map['indopak']?.toString(),
        transliteration: map['transliteration']?.toString(),
        tajwidText: map['tajwidText']?.toString(),
        words: words,
        tajwidSource: map['tajwidSource']?.toString(),
        wordTranslationSource: map['wordTranslationSource']?.toString(),
      );
    }).where((ayah) => ayah.number > 0).toList(growable: false);
  }

  List<Map<String, dynamic>> _encodeAyahs(List<Ayah> ayahs) {
    return ayahs
        .map(
          (e) => {
            'number': e.number,
            'arabic': e.arabic,
            'translation': e.translation,
            'indopak': e.indopak,
            'transliteration': e.transliteration,
            'tajwidText': e.tajwidText,
            'words': e.words
                .map((word) => {
                      'arabic': word.arabic,
                      'translation': word.translation,
                    })
                .toList(growable: false),
            'tajwidSource': e.tajwidSource,
            'wordTranslationSource': e.wordTranslationSource,
          },
        )
        .toList(growable: false);
  }

  Future<List<Surah>> fetchSurahs({bool forceRefresh = false}) async {
    const String cacheKey = 'cache_surah_list';
    final prefs = await SharedPreferences.getInstance();

    if (!forceRefresh && prefs.containsKey(cacheKey)) {
      final String? cachedData = prefs.getString(cacheKey);
      if (cachedData != null) {
        try {
          final List<dynamic> data = json.decode(cachedData);
          if (data.isNotEmpty) {
            return data.map((json) => Surah.fromJson(json)).toList();
          }
        } catch (e) {
          debugPrint('Cache error: $e');
        }
      }
    }

    try {
      final response = await http.get(Uri.parse('$baseUrl/surah'));

      if (response.statusCode == 200) {
        final Map<String, dynamic> body = json.decode(response.body);
        final List<dynamic> data = body['data'];
        await prefs.setString(cacheKey, json.encode(data));
        return data.map((json) => Surah.fromJson(json)).toList();
      }
      throw Exception('Failed to load surahs');
    } catch (e) {
      try {
        final String jsonString =
            await rootBundle.loadString('assets/surah_list.json');
        final Map<String, dynamic> body = json.decode(jsonString);
        final List<dynamic> data = body['data'];
        return data.map((json) => Surah.fromJson(json)).toList();
      } catch (_) {
        throw Exception(
          'Failed to connect to API and load offline data: $e',
        );
      }
    }
  }

  Future<List<Ayah>> fetchArabicOnly(int surahNumber) async {
    final String arabicCacheKey = 'cache_surah_${surahNumber}_arabic_v4';
    final prefs = await SharedPreferences.getInstance();

    if (prefs.containsKey(arabicCacheKey)) {
      final String? cachedData = prefs.getString(arabicCacheKey);
      if (cachedData != null) {
        try {
          final List<dynamic> data = json.decode(cachedData);
          return data
              .map(
                (item) => Ayah(
                  number: item['number'],
                  arabic: item['arabic'],
                  translation: '',
                ),
              )
              .toList(growable: false);
        } catch (e) {
          debugPrint('Error parsing Arabic cache: $e');
        }
      }
    }

    try {
      final keys = prefs.getKeys();
      final String prefix = 'cache_surah_${surahNumber}_';

      for (final key in keys) {
        if (!key.startsWith(prefix) || !key.endsWith('_v4')) continue;

        final String? cachedData = prefs.getString(key);
        if (cachedData == null) continue;
        final List<dynamic> data = json.decode(cachedData);
        if (data.isEmpty) continue;

        final ayahs = data
            .map(
              (item) => Ayah(
                number: item['number'],
                arabic: item['arabic'],
                translation: '',
              ),
            )
            .toList(growable: false);

        await prefs.setString(
          arabicCacheKey,
          json.encode(
            ayahs
                .map((e) => {'number': e.number, 'arabic': e.arabic})
                .toList(growable: false),
          ),
        );
        return ayahs;
      }
    } catch (e) {
      debugPrint('Error checking fallback cache: $e');
    }

    try {
      final arabicResponse = await http.get(
        Uri.parse('$baseUrl/surah/$surahNumber/arabic'),
      );
      if (arabicResponse.statusCode != 200) {
        throw Exception('Failed to load Arabic');
      }

      final Map<String, dynamic> arabicBody =
          json.decode(arabicResponse.body);
      final List<dynamic> arabicList = arabicBody['data']['ayahs'];
      final List<Ayah> ayahs = [];
      int currentNumber = 1;

      for (final arabicItem in arabicList) {
        final arabicText = arabicItem['uthmani']?.toString() ?? '';
        if (arabicItem['number'] == 0 || arabicText.trim().isEmpty) continue;

        ayahs.add(
          Ayah(
            number: currentNumber++,
            arabic: arabicText,
            translation: '',
          ),
        );
      }

      await prefs.setString(
        arabicCacheKey,
        json.encode(
          ayahs
              .map((e) => {'number': e.number, 'arabic': e.arabic})
              .toList(growable: false),
        ),
      );
      return ayahs;
    } catch (e) {
      throw Exception('Failed to connect to API: $e');
    }
  }

  Future<List<Ayah>> fetchTranslation(
    int surahNumber,
    List<Ayah> arabicAyahs, {
    String edition = 'id-indonesian',
  }) async {
    final String cacheKey = 'cache_surah_${surahNumber}_${edition}_v4';
    final prefs = await SharedPreferences.getInstance();

    if (prefs.containsKey(cacheKey)) {
      final String? cachedData = prefs.getString(cacheKey);
      if (cachedData != null) {
        try {
          final List<dynamic> data = json.decode(cachedData);
          return data
              .map(
                (item) => Ayah(
                  number: item['number'],
                  arabic: item['arabic'],
                  translation: item['translation'] ?? '',
                ),
              )
              .toList(growable: false);
        } catch (e) {
          debugPrint('Translation cache error: $e');
        }
      }
    }

    try {
      final translationResponse = await http.get(
        Uri.parse('$baseUrl/surah/$surahNumber/$edition'),
      );

      if (translationResponse.statusCode != 200) return arabicAyahs;

      final Map<String, dynamic> transBody =
          json.decode(translationResponse.body);
      final List<dynamic> transList = transBody['data']['ayahs'];

      final List<Ayah> mergedAyahs = [];
      for (int i = 0; i < arabicAyahs.length; i++) {
        final trans = i < transList.length
            ? transList[i]['text']?.toString() ?? ''
            : '';
        mergedAyahs.add(
          Ayah(
            number: arabicAyahs[i].number,
            arabic: arabicAyahs[i].arabic,
            translation: trans,
          ),
        );
      }

      await prefs.setString(cacheKey, json.encode(_encodeAyahs(mergedAyahs)));
      return mergedAyahs;
    } catch (e) {
      debugPrint('Translation request failed: $e');
      return arabicAyahs;
    }
  }

  Future<List<Ayah>> fetchSurahDetails(
    int surahNumber, {
    String edition = 'id-indonesian',
  }) async {
    final memoryKey = _detailsKey(surahNumber, edition);
    final memory = _memorySurahCache[memoryKey];
    if (memory != null && memory.isNotEmpty) return memory;

    final prefs = await SharedPreferences.getInstance();
    final detailsCacheKey =
        'cache_surah_details_${surahNumber}_${edition}_$_detailCacheVersion';

    final diskCache = prefs.getString(detailsCacheKey);
    if (diskCache != null) {
      try {
        final cached = _decodeAyahs(json.decode(diskCache));
        if (cached.isNotEmpty) {
          _memorySurahCache[memoryKey] = cached;
          return cached;
        }
      } catch (e) {
        debugPrint('Detailed Surah cache error: $e');
      }
    }

    try {
      final arabicAyahs = await fetchArabicOnly(surahNumber);
      final base = await fetchTranslation(
        surahNumber,
        arabicAyahs,
        edition: edition,
      );

      final enhanced = await QuranExternalService().fetchSurah(
        surahNumber,
        edition: edition,
      );

      final merged = enhanced.isEmpty
          ? base
          : base.map((ayah) {
              final extra = enhanced[ayah.number];
              if (extra == null) return ayah;
              return ayah.copyWith(
                indopak: extra.indopak,
                transliteration: extra.transliteration,
                tajwidText: extra.tajwidText,
                words: extra.words,
                tajwidSource:
                    extra.tajwidText == null ? null : 'Quran.com API',
                wordTranslationSource:
                    extra.words.isEmpty ? null : 'Quran.com API',
              );
            }).toList(growable: false);

      _memorySurahCache[memoryKey] = merged;
      await prefs.setString(
        detailsCacheKey,
        json.encode(_encodeAyahs(merged)),
      );
      return merged;
    } catch (e) {
      debugPrint('fetchSurahDetails Error: $e');
      throw Exception('Failed to load data: $e');
    }
  }

  Future<List<Map<String, dynamic>>> fetchPrayerSchedule(
    String province,
    String city, {
    DateTime? date,
  }) async {
    const String url = 'https://equran.id/api/v2/shalat';
    final DateTime targetDate = date ?? DateTime.now();
    final int month = targetDate.month;
    final int year = targetDate.year;

    final String cacheKey =
        'prayer_times_${province}_${city}_${year}_$month';
    final prefs = await SharedPreferences.getInstance();

    if (prefs.containsKey(cacheKey)) {
      final String? cachedData = prefs.getString(cacheKey);
      if (cachedData != null) {
        final List<dynamic> data = json.decode(cachedData);
        return data.cast<Map<String, dynamic>>();
      }
    }

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'provinsi': province,
          'kabkota': city,
          'bulan': month,
          'tahun': year,
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to load prayer times');
      }

      final Map<String, dynamic> body = json.decode(response.body);
      final List<dynamic> jadwal = body['data']['jadwal'];
      await prefs.setString(cacheKey, json.encode(jadwal));
      return jadwal.cast<Map<String, dynamic>>();
    } catch (e) {
      throw Exception('Failed to connect to API: $e');
    }
  }
}
