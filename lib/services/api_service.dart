import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../models/surah.dart';
import '../models/ayah.dart';
import 'equran_service.dart';

class ApiService {
  static const String baseUrl = 'https://quran-api.damarcreative.my.id/api';

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

    // Primary: equran.id v2 (Kemenag source, 24h edge cache).
    // Runs for both fresh and forced loads; legacy API below is fallback.
    try {
      final surahs = await EquranService.fetchSurahs();
      if (surahs.length == 114) {
        await prefs.setString(
          cacheKey,
          json.encode(surahs.map((e) => e.toJson()).toList()),
        );
        return surahs;
      }
    } catch (e) {
      debugPrint('equran surah list failed, falling back: $e');
    }

    try {
      final response = await http.get(Uri.parse('$baseUrl/surah'));

      if (response.statusCode == 200) {
        final Map<String, dynamic> body = json.decode(response.body);
        final List<dynamic> data = body['data'];

        await prefs.setString(cacheKey, json.encode(data));

        return data.map((json) => Surah.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load surahs');
      }
    } catch (e) {
      try {
        final String jsonString = await rootBundle.loadString(
          'assets/surah_list.json',
        );
        final Map<String, dynamic> body = json.decode(jsonString);
        final List<dynamic> data = body['data'];

        return data.map((json) => Surah.fromJson(json)).toList();
      } catch (_) {
        throw Exception('Failed to connect to API and load offline data: $e');
      }
    }
  }

  // Supports both v4 (legacy) and v5 (with transliteration)
  List<Ayah> _decodeAyahs(List<dynamic> data) {
    return data.map((item) {
      final map = item as Map<String, dynamic>;
      return Ayah(
        number: map['number'] as int,
        arabic: map['arabic'] as String? ?? '',
        translation: map['translation'] as String? ?? '',
        transliteration: map['transliteration'] as String? ?? '',
      );
    }).toList();
  }

  String _stripTransliterationTags(String raw) {
    // en-transliteration contains <u> <b> markup for pronunciation hints
    var out = raw.replaceAll(RegExp(r'<[^>]*>'), '');
    // Decode common entities if any
    out = out
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>');
    out = out.replaceAll('&quot;', '"').replaceAll('&#39;', "'");
    return out.trim();
  }

  /// Fetch Arabic only (with robust cache fallback) - supports v5 and migrates v4
  Future<List<Ayah>> fetchArabicOnly(int surahNumber) async {
    final String arabicCacheKey = 'cache_surah_${surahNumber}_arabic_v5';
    final String legacyKey = 'cache_surah_${surahNumber}_arabic_v4';
    final prefs = await SharedPreferences.getInstance();

    // 1. Check v5 Arabic cache
    if (prefs.containsKey(arabicCacheKey)) {
      final String? cachedData = prefs.getString(arabicCacheKey);
      if (cachedData != null) {
        try {
          final List<dynamic> data = json.decode(cachedData);
          return _decodeAyahs(data)
              .map(
                (e) => Ayah(
                  number: e.number,
                  arabic: e.arabic,
                  translation: '',
                  transliteration: '',
                ),
              )
              .toList();
        } catch (e) {
          debugPrint('Error parsing Arabic v5 cache: $e');
        }
      }
    }
    // Fallback legacy v4
    if (prefs.containsKey(legacyKey)) {
      final String? cachedData = prefs.getString(legacyKey);
      if (cachedData != null) {
        try {
          final List<dynamic> data = json.decode(cachedData);
          final ayahs = _decodeAyahs(data)
              .map(
                (e) => Ayah(
                  number: e.number,
                  arabic: e.arabic,
                  translation: '',
                  transliteration: '',
                ),
              )
              .toList();
          // Promote to v5
          await prefs.setString(
            arabicCacheKey,
            json.encode(
              ayahs
                  .map((e) => {'number': e.number, 'arabic': e.arabic})
                  .toList(),
            ),
          );
          return ayahs;
        } catch (e) {
          debugPrint('Error parsing Arabic v4 cache: $e');
        }
      }
    }

    // 2. Check ANY other edition cache for this surah to extract Arabic
    try {
      final keys = prefs.getKeys();
      final String prefix = 'cache_surah_${surahNumber}_';

      for (final key in keys) {
        if (key.startsWith(prefix) &&
            (key.endsWith('_v5') || key.endsWith('_v4')) &&
            key != arabicCacheKey &&
            key != legacyKey) {
          final String? cachedData = prefs.getString(key);
          if (cachedData != null) {
            final List<dynamic> data = json.decode(cachedData);
            if (data.isNotEmpty) {
              final ayahs = _decodeAyahs(data)
                  .map(
                    (e) => Ayah(
                      number: e.number,
                      arabic: e.arabic,
                      translation: '',
                      transliteration: '',
                    ),
                  )
                  .toList();

              await prefs.setString(
                arabicCacheKey,
                json.encode(
                  ayahs
                      .map((e) => {'number': e.number, 'arabic': e.arabic})
                      .toList(),
                ),
              );

              return ayahs;
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error checking fallback cache: $e');
    }

    // 2b. Try bundled offline asset assets/quran/{n}.json (contains arabic+translation+transliteration)
    try {
      final String assetData = await rootBundle.loadString(
        'assets/quran/$surahNumber.json',
      );
      final Map<String, dynamic> j = json.decode(assetData);
      final List<dynamic> ayahsJson = j['ayahs'] as List<dynamic>;
      final List<Ayah> ayahs = ayahsJson
          .map(
            (e) => Ayah(
              number: e['number'] as int,
              arabic: e['arabic'] as String,
              translation: e['translation'] as String? ?? '',
              transliteration: e['transliteration'] as String? ?? '',
            ),
          )
          .toList();
      if (ayahs.isNotEmpty) {
        // Cache arabic part
        await prefs.setString(
          arabicCacheKey,
          json.encode(
            ayahs.map((e) => {'number': e.number, 'arabic': e.arabic}).toList(),
          ),
        );
        // Also cache full with default translation for offline
        final String fullKey = 'cache_surah_${surahNumber}_id-indonesian_v5';
        if (!prefs.containsKey(fullKey)) {
          await prefs.setString(
            fullKey,
            json.encode(ayahs.map((e) => e.toJson()).toList()),
          );
        }
        // Cache transliteration separately
        final String translitKey = 'cache_translit_${surahNumber}_asian_v5';
        if (!prefs.containsKey(translitKey)) {
          await prefs.setString(
            translitKey,
            json.encode(ayahs.map((e) => e.transliteration).toList()),
          );
        }
        // Return arabic-only for fetchArabicOnly contract (translation will be merged later via cache hit)
        return ayahs
            .map(
              (e) => Ayah(
                number: e.number,
                arabic: e.arabic,
                translation: '',
                transliteration: '',
              ),
            )
            .toList();
      }
    } catch (_) {}

    // 3. Fetch from API
    try {
      final arabicResponse = await http.get(
        Uri.parse('$baseUrl/surah/$surahNumber/arabic'),
      );

      if (arabicResponse.statusCode == 200) {
        final Map<String, dynamic> arabicBody = json.decode(
          arabicResponse.body,
        );
        final List<dynamic> arabicList = arabicBody['data']['ayahs'];

        final List<Ayah> ayahs = [];
        int currentNumber = 1;

        for (int i = 0; i < arabicList.length; i++) {
          final arabicItem = arabicList[i];
          String arabicText = arabicItem['uthmani'] ?? '';

          if (arabicItem['number'] == 0) continue;
          if (arabicText.trim().isEmpty) continue;

          ayahs.add(
            Ayah(number: currentNumber++, arabic: arabicText, translation: ''),
          );
        }

        await prefs.setString(
          arabicCacheKey,
          json.encode(
            ayahs.map((e) => {'number': e.number, 'arabic': e.arabic}).toList(),
          ),
        );

        return ayahs;
      } else {
        throw Exception('Failed to load Arabic');
      }
    } catch (e) {
      throw Exception('Failed to connect to API: $e');
    }
  }

  /// Fetch translation and merge with existing ayahs — supports v5
  /// `id-indonesian` prefers the equran.id v2 fast path (Kemenag);
  /// `en-asad` uses the equran.id English API (Muhammad Asad).
  Future<List<Ayah>> fetchTranslation(
    int surahNumber,
    List<Ayah> arabicAyahs, {
    String edition = 'id-indonesian',
  }) async {
    if (edition == 'id-indonesian') {
      final fast = await fetchEquranDetail(surahNumber);
      if (fast != null &&
          fast.isNotEmpty &&
          (arabicAyahs.isEmpty || fast.length == arabicAyahs.length)) {
        return fast;
      }
      // Length mismatch: fall through to the legacy merge below.
    }
    if (edition == 'en-asad') {
      return fetchEnglishAsad(surahNumber, arabicAyahs);
    }
    final String cacheKeyV5 = 'cache_surah_${surahNumber}_${edition}_v5';
    final String legacyKey = 'cache_surah_${surahNumber}_${edition}_v4';
    final prefs = await SharedPreferences.getInstance();

    if (prefs.containsKey(cacheKeyV5)) {
      final String? cachedData = prefs.getString(cacheKeyV5);
      if (cachedData != null) {
        try {
          final List<dynamic> data = json.decode(cachedData);
          return _decodeAyahs(data);
        } catch (e) {
          debugPrint('Parse v5 translation cache error: $e');
        }
      }
    }
    if (prefs.containsKey(legacyKey)) {
      final String? cachedData = prefs.getString(legacyKey);
      if (cachedData != null) {
        try {
          final List<dynamic> data = json.decode(cachedData);
          final merged = _decodeAyahs(data);
          // migrate to v5
          await prefs.setString(
            cacheKeyV5,
            json.encode(merged.map((e) => e.toJson()).toList()),
          );
          return merged;
        } catch (e) {
          debugPrint('Parse v4 translation cache error: $e');
        }
      }
    }

    try {
      final translationResponse = await http.get(
        Uri.parse('$baseUrl/surah/$surahNumber/$edition'),
      );

      if (translationResponse.statusCode == 200) {
        final Map<String, dynamic> transBody = json.decode(
          translationResponse.body,
        );
        final List<dynamic> transList = transBody['data']['ayahs'];

        final List<Ayah> mergedAyahs = [];

        for (int i = 0; i < arabicAyahs.length; i++) {
          final trans = (i < transList.length)
              ? transList[i]['text'] ?? ''
              : '';
          mergedAyahs.add(
            Ayah(
              number: arabicAyahs[i].number,
              arabic: arabicAyahs[i].arabic,
              translation: trans,
              transliteration: arabicAyahs[i].transliteration,
            ),
          );
        }

        await prefs.setString(
          cacheKeyV5,
          json.encode(mergedAyahs.map((e) => e.toJson()).toList()),
        );

        return mergedAyahs;
      } else {
        return arabicAyahs;
      }
    } catch (e) {
      return arabicAyahs;
    }
  }

  /// Convert English transliteration to Asian (Muslim Pro / Kemenag) style
  /// Applies Indonesian SKB 1987 simplified orthography and hyphenation
  String _toAsianStyle(String en) {
    var s = en;
    // Basic hyphenation for sun-letter assimilation already in gading data;
    // For dammar en data, normalize spaces around hyphens and ensure sy vs sh
    // Keep it readable: Muslin Pro uses capital first letter, double vowels
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    // Example fixes for Asian readability: sy instead of sh in some contexts is already handled
    // Preserve double vowel length as in Muslim Pro: aa, ii, uu
    return s;
  }

  /// Fetch Asian (Muslim Pro / Kemenag) transliteration via gading.dev
  Future<List<Ayah>> fetchAsianTransliteration(
    int surahNumber,
    List<Ayah> baseAyahs,
  ) async {
    const String edition = 'asian';
    final String cacheKey = 'cache_translit_${surahNumber}_${edition}_v5';
    final prefs = await SharedPreferences.getInstance();

    if (prefs.containsKey(cacheKey)) {
      final String? cachedData = prefs.getString(cacheKey);
      if (cachedData != null) {
        try {
          final List<dynamic> data = json.decode(cachedData);
          final List<String> lats = List<String>.from(data);
          if (lats.length == baseAyahs.length) {
            return List.generate(
              baseAyahs.length,
              (i) => baseAyahs[i].copyWith(transliteration: lats[i]),
            );
          }
        } catch (e) {
          debugPrint('Asian translit cache parse error: $e');
        }
      }
    }

    try {
      final res = await http.get(
        Uri.parse('https://api.quran.gading.dev/surah/$surahNumber'),
      );
      if (res.statusCode == 200) {
        final Map<String, dynamic> body = json.decode(res.body);
        final List<dynamic> verses = body['data']['verses'] as List<dynamic>;
        final List<Ayah> merged = [];
        for (int i = 0; i < baseAyahs.length; i++) {
          String raw = '';
          if (i < verses.length) {
            final v = verses[i] as Map<String, dynamic>;
            final text = v['text'] as Map<String, dynamic>?;
            final trans = text?['transliteration'] as Map<String, dynamic>?;
            raw = (trans?['en'] as String?) ?? '';
          }
          // Fallback to en dammar data if gading missing
          if (raw.isEmpty) {
            // Try dammar en-transliteration as fallback
            try {
              final fallback = await http.get(
                Uri.parse('$baseUrl/surah/$surahNumber/en-transliteration'),
              );
              if (fallback.statusCode == 200) {
                final fbBody = json.decode(fallback.body);
                final fbList = fbBody['data']['ayahs'] as List<dynamic>;
                if (i < fbList.length)
                  raw = (fbList[i]['text'] ?? '') as String;
                raw = _stripTransliterationTags(raw);
              }
            } catch (_) {}
          }
          final cleaned = _toAsianStyle(raw);
          merged.add(baseAyahs[i].copyWith(transliteration: cleaned));
        }
        await prefs.setString(
          cacheKey,
          json.encode(merged.map((e) => e.transliteration).toList()),
        );
        return merged;
      }
    } catch (e) {
      debugPrint('fetchAsianTransliteration error: $e');
    }
    // Fallback to regular en transliteration converted
    return fetchTransliteration(
      surahNumber,
      baseAyahs,
      edition: 'en-transliteration',
    );
  }

  /// equran.id v2 fast path: one call returns Arabic + Indonesian +
  /// Indonesian Latin. Warms the standard caches so search/offline keep
  /// working: `cache_surah_{n}_id-indonesian_v5` and
  /// `cache_translit_{n}_id-transliteration_v5`.
  Future<List<Ayah>?> fetchEquranDetail(int surahNumber) async {
    try {
      final (_, ayahs) = await EquranService.fetchSurahDetail(surahNumber);
      if (ayahs.isEmpty) return null;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'cache_surah_${surahNumber}_id-indonesian_v5',
        json.encode(ayahs.map((e) => e.toJson()).toList()),
      );
      await prefs.setString(
        'cache_translit_${surahNumber}_id-transliteration_v5',
        json.encode(ayahs.map((e) => e.transliteration).toList()),
      );
      await prefs.setString(
        'cache_surah_${surahNumber}_arabic_v5',
        json.encode(
          ayahs.map((e) => {'number': e.number, 'arabic': e.arabic}).toList(),
        ),
      );
      return ayahs;
    } catch (e) {
      debugPrint('fetchEquranDetail error: $e');
      return null;
    }
  }

  /// Muhammad Asad English translation via equran.id English API.
  Future<List<Ayah>> fetchEnglishAsad(
    int surahNumber,
    List<Ayah> baseAyahs,
  ) async {
    final cacheKeyPrefix = 'cache_surah_${surahNumber}_en-asad_v5';
    final prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey(cacheKeyPrefix)) {
      try {
        final data = json.decode(prefs.getString(cacheKeyPrefix)!) as List;
        final cached = _decodeAyahs(data);
        if (cached.length == baseAyahs.length) return cached;
      } catch (e) {
        debugPrint('en-asad cache parse error: $e');
      }
    }
    try {
      final en = await EquranService.fetchEnglish(surahNumber);
      if (en.length != baseAyahs.length) return baseAyahs;
      final merged = List.generate(
        baseAyahs.length,
        (i) => Ayah(
          number: baseAyahs[i].number,
          arabic: baseAyahs[i].arabic.isNotEmpty
              ? baseAyahs[i].arabic
              : en[i].arabic,
          translation: en[i].translation,
          transliteration: baseAyahs[i].transliteration.isNotEmpty
              ? baseAyahs[i].transliteration
              : en[i].transliteration,
        ),
      );
      await prefs.setString(
        cacheKeyPrefix,
        json.encode(merged.map((e) => e.toJson()).toList()),
      );
      return merged;
    } catch (e) {
      debugPrint('fetchEnglishAsad error: $e');
      return baseAyahs;
    }
  }

  /// Indonesian Latin transliteration (equran.id v2 `teksLatin`, Kemenag
  /// orthography). Served from the warmed cache or the single-call fast
  /// path; falls back to the legacy Asian pipeline when offline/empty.
  Future<List<Ayah>> fetchIndonesianLatin(
    int surahNumber,
    List<Ayah> baseAyahs,
  ) async {
    const edition = 'id-transliteration';
    final cacheKey = 'cache_translit_${surahNumber}_${edition}_v5';
    final prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey(cacheKey)) {
      try {
        final data = json.decode(prefs.getString(cacheKey)!) as List;
        final lats = List<String>.from(data);
        if (lats.length == baseAyahs.length) {
          return List.generate(
            baseAyahs.length,
            (i) => baseAyahs[i].copyWith(transliteration: lats[i]),
          );
        }
      } catch (e) {
        debugPrint('Indonesian latin cache parse error: $e');
      }
    }
    final fast = await fetchEquranDetail(surahNumber);
    if (fast != null && fast.length == baseAyahs.length) {
      return List.generate(
        baseAyahs.length,
        (i) => baseAyahs[i].copyWith(transliteration: fast[i].transliteration),
      );
    }
    return fetchAsianTransliteration(surahNumber, baseAyahs);
  }

  /// Fetch transliteration for a surah and merge — uses same edition mechanism
  Future<List<Ayah>> fetchTransliteration(
    int surahNumber,
    List<Ayah> baseAyahs, {
    String edition = 'en-transliteration',
  }) async {
    if (edition == 'id-transliteration') {
      return fetchIndonesianLatin(surahNumber, baseAyahs);
    }
    if (edition == 'asian' || edition == 'id-transliteration-legacy') {
      return fetchAsianTransliteration(surahNumber, baseAyahs);
    }
    final String cacheKey = 'cache_translit_${surahNumber}_${edition}_v5';
    final prefs = await SharedPreferences.getInstance();

    if (prefs.containsKey(cacheKey)) {
      final String? cachedData = prefs.getString(cacheKey);
      if (cachedData != null) {
        try {
          final List<dynamic> data = json.decode(cachedData);
          final List<String> lats = List<String>.from(data);
          if (lats.length == baseAyahs.length) {
            return List.generate(
              baseAyahs.length,
              (i) => baseAyahs[i].copyWith(transliteration: lats[i]),
            );
          }
        } catch (e) {
          debugPrint('Translit cache parse error: $e');
        }
      }
    }

    try {
      final res = await http.get(
        Uri.parse('$baseUrl/surah/$surahNumber/$edition'),
      );
      if (res.statusCode == 200) {
        final Map<String, dynamic> body = json.decode(res.body);
        final List<dynamic> list = body['data']['ayahs'];
        final List<Ayah> merged = [];
        for (int i = 0; i < baseAyahs.length; i++) {
          final raw = (i < list.length)
              ? (list[i]['text'] ?? '') as String
              : '';
          final cleaned = _stripTransliterationTags(raw);
          merged.add(baseAyahs[i].copyWith(transliteration: cleaned));
        }
        // cache only transliteration strings for reuse
        await prefs.setString(
          cacheKey,
          json.encode(merged.map((e) => e.transliteration).toList()),
        );
        return merged;
      }
    } catch (e) {
      debugPrint('fetchTransliteration error: $e');
    }
    return baseAyahs;
  }

  Future<List<Ayah>> fetchSurahDetails(
    int surahNumber, {
    String edition = 'id-indonesian',
    String? transliterationEdition,
  }) async {
    try {
      final List<Ayah> arabicAyahs = await fetchArabicOnly(surahNumber);
      List<Ayah> withTranslation = await fetchTranslation(
        surahNumber,
        arabicAyahs,
        edition: edition,
      );

      if (transliterationEdition != null && transliterationEdition.isNotEmpty) {
        withTranslation = await fetchTransliteration(
          surahNumber,
          withTranslation,
          edition: transliterationEdition,
        );
      }

      return withTranslation;
    } catch (e) {
      debugPrint('fetchSurahDetails Error: $e');
      throw Exception('Failed to load data: $e');
    }
  }

  Future<List<Ayah>> fetchSurahWithAll(
    int surahNumber, {
    String edition = 'id-indonesian',
    String? transliterationEdition,
    String? tafsirEdition,
  }) async {
    // Unified entry that can fetch translation + transliteration + optional tafsir (tafsir is stored as second translation layer via download service)
    return fetchSurahDetails(
      surahNumber,
      edition: edition,
      transliterationEdition: transliterationEdition,
    );
  }

  /// Kemenag per-ayah tafsir via equran.id v2, cached per surah.
  Future<List<EquranTafsir>> fetchTafsirCached(int surahNumber) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'cache_tafsir_${surahNumber}_v1';
    if (prefs.containsKey(key)) {
      try {
        final data = json.decode(prefs.getString(key)!) as List;
        final cached = [
          for (final e in data)
            EquranTafsir(
              ayah: ((e as Map)['ayat'] as num).toInt(),
              teks: '${e['teks'] ?? ''}',
            ),
        ];
        if (cached.isNotEmpty) return cached;
      } catch (e) {
        debugPrint('tafsir cache parse error: $e');
      }
    }
    final fresh = await EquranService.fetchTafsir(surahNumber);
    if (fresh.isNotEmpty) {
      await prefs.setString(
        key,
        json.encode([
          for (final t in fresh) {'ayat': t.ayah, 'teks': t.teks},
        ]),
      );
    }
    return fresh;
  }

  /// Surah description (Kemenag) via equran.id v2, HTML-stripped + cached.
  Future<String> fetchSurahDescription(int surahNumber) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'cache_surah_desc_${surahNumber}_v1';
    if (prefs.containsKey(key)) {
      return prefs.getString(key) ?? '';
    }
    try {
      final res = await http
          .get(Uri.parse('${EquranService.base}/api/v2/surat/$surahNumber'))
          .timeout(const Duration(seconds: 25));
      if (res.statusCode == 200) {
        final data = (json.decode(res.body) as Map)['data'] as Map;
        var desc = '${data['deskripsi'] ?? ''}';
        desc = desc.replaceAll(RegExp(r'<[^>]*>'), '');
        desc = desc.replaceAll(RegExp(r'\s+'), ' ').trim();
        await prefs.setString(key, desc);
        return desc;
      }
    } catch (e) {
      debugPrint('fetchSurahDescription error: $e');
    }
    return '';
  }

  /// Verified Tajwid source: quran.com word-level uthmani tajweed.
  /// Returns map verseNumber -> tagged string with <rule class=X>...</rule>.
  /// Words joined with spaces; ayah-end markers skipped.
  /// Cached per chapter. Throws on failure so callers fall back to plain.
  Future<Map<int, String>> fetchTajweedChapter(int surahNumber) async {
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = 'cache_tajweed_${surahNumber}_v2';
    if (prefs.containsKey(cacheKey)) {
      try {
        final raw = prefs.getString(cacheKey);
        if (raw != null) {
          final Map<String, dynamic> j = json.decode(raw);
          final cached = j.map((k, v) => MapEntry(int.parse(k), v as String));
          if (cached.isNotEmpty) return cached;
        }
      } catch (e) {
        debugPrint('Tajweed cache parse error: $e');
      }
    }
    final out = <int, String>{};
    int page = 1;
    int totalPages = 1;
    const perPage = 50;
    while (true) {
      final uri = Uri.parse(
        'https://api.quran.com/api/v4/verses/by_chapter/$surahNumber?words=true&word_fields=text_uthmani_tajweed&per_page=$perPage&page=$page',
      );
      final res = await http.get(uri, headers: {'Accept': 'application/json'});
      if (res.statusCode != 200)
        throw Exception('Tajweed fetch failed ${res.statusCode}');
      final body = json.decode(res.body) as Map<String, dynamic>;
      final verses = (body['verses'] as List<dynamic>? ?? []);
      for (final v in verses) {
        final m = v as Map<String, dynamic>;
        final key = m['verse_key'] as String? ?? '';
        final num = key.contains(':') ? int.tryParse(key.split(':')[1]) : null;
        if (num == null) continue;
        final words = (m['words'] as List<dynamic>? ?? []);
        final parts = <String>[];
        for (final w in words) {
          final wm = w as Map<String, dynamic>;
          if (wm['char_type_name'] == 'end') continue;
          final t = wm['text_uthmani_tajweed'] as String? ?? '';
          if (t.isNotEmpty) parts.add(t);
        }
        if (parts.isNotEmpty) out[num] = parts.join(' ');
      }
      final pagination = body['pagination'] as Map<String, dynamic>?;
      totalPages = (pagination?['total_pages'] as num?)?.toInt() ?? 1;
      if (page >= totalPages) break;
      page++;
    }
    if (out.isEmpty) throw Exception('Empty tajweed');
    try {
      await prefs.setString(
        cacheKey,
        json.encode(out.map((k, v) => MapEntry(k.toString(), v))),
      );
    } catch (_) {}
    return out;
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

    final String cacheKey = 'prayer_times_${province}_${city}_${year}_$month';
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

      if (response.statusCode == 200) {
        final Map<String, dynamic> body = json.decode(response.body);
        final List<dynamic> jadwal = body['data']['jadwal'];

        await prefs.setString(cacheKey, json.encode(jadwal));

        return jadwal.cast<Map<String, dynamic>>();
      } else {
        throw Exception('Failed to load prayer times');
      }
    } catch (e) {
      throw Exception('Failed to connect to API: $e');
    }
  }
}
