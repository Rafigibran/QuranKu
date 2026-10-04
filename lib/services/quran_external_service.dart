import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/ayah.dart';

class QuranExternalService {
  static const String _baseUrl = 'https://api.quran.com/api/v4';

  Future<Map<int, QuranExternalData>> fetchSurah(
    int surahNumber, {
    String edition = 'id-indonesian',
  }) async {
    final translationId = switch (edition) {
      'en-sahih' => 20,
      'id-indonesian' => 33,
      _ => 33,
    };

    // Keep word-by-word translation aligned with the selected language.
    final language = _languageCodeFromEdition(edition);

    try {
      final uri = Uri.parse(
        '$_baseUrl/verses/by_chapter/$surahNumber'
        '?words=true'
        '&language=$language'
        '&word_fields=text_uthmani,text_indopak,translation'
        '&translations=$translationId,57'
        '&fields=text_uthmani,text_indopak,text_uthmani_tajweed'
        '&per_page=300',
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 7));
      if (response.statusCode != 200) return <int, QuranExternalData>{};

      final body = json.decode(response.body) as Map<String, dynamic>;
      final verses = (body['verses'] as List<dynamic>? ?? const <dynamic>[]);
      final result = <int, QuranExternalData>{};

      for (final raw in verses) {
        if (raw is! Map<String, dynamic>) continue;
        final verseNumber = raw['verse_number'] is num
            ? (raw['verse_number'] as num).toInt()
            : int.tryParse(raw['verse_number']?.toString() ?? '');
        if (verseNumber == null) continue;

        final words = <QuranWord>[];
        final rawWords = raw['words'];
        if (rawWords is List) {
          for (final wordRaw in rawWords) {
            if (wordRaw is! Map<String, dynamic>) continue;
            if (wordRaw['char_type_name']?.toString() == 'end') continue;

            final arabic = wordRaw['text_uthmani']?.toString() ??
                wordRaw['text']?.toString() ?? '';
            if (arabic.trim().isEmpty) continue;

            words.add(
              QuranWord(
                arabic: arabic,
                translation: _wordTranslation(wordRaw['translation']),
              ),
            );
          }
        }

        result[verseNumber] = QuranExternalData(
          indopak: raw['text_indopak']?.toString(),
          transliteration: _translationText(raw['translations'], 57),
          tajwidText: raw['text_uthmani_tajweed']?.toString(),
          words: words,
        );
      }

      return result;
    } catch (e) {
      debugPrint('Quran.com enhancement unavailable: $e');
      return <int, QuranExternalData>{};
    }
  }

  String _languageCodeFromEdition(String edition) {
    final code = edition.split('-').first.trim().toLowerCase();
    const supported = <String>{
      'en', 'id', 'ar', 'bn', 'bs', 'cs', 'de', 'dv', 'es', 'fa', 'fr', 'ha',
      'hi', 'it', 'ja', 'ko', 'ku', 'ml', 'ms', 'nl', 'no', 'pl', 'pt', 'ro',
      'ru', 'sd', 'so', 'sq', 'sv', 'sw', 'ta', 'th', 'tr', 'tt', 'ug', 'ur',
      'uz', 'zh',
    };
    return supported.contains(code) ? code : 'en';
  }

  String _translationText(dynamic value, int resourceId) {
    if (value is! List) return '';
    for (final item in value) {
      if (item is Map<String, dynamic> && item['resource_id'] == resourceId) {
        return (item['text'] ?? '').toString().trim();
      }
    }
    return '';
  }

  String _wordTranslation(dynamic value) {
    if (value is String) return value.trim();
    if (value is Map<String, dynamic>) {
      return (value['text'] ?? value['translation'] ?? '').toString().trim();
    }
    return '';
  }
}

class QuranExternalData {
  final String? indopak;
  final String? transliteration;
  final String? tajwidText;
  final List<QuranWord> words;

  const QuranExternalData({
    this.indopak,
    this.transliteration,
    this.tajwidText,
    this.words = const <QuranWord>[],
  });
}
