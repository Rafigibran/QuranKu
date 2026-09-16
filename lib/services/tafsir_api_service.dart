import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/tafsir_edition.dart';
import 'mirrored_json.dart';

/// Normalizes any tafsir_api payload into `{ayahNumber: text}`.
///
/// The upstream API is not self-consistent. Three shapes are observed:
///   * `[{"text": "...", "ayah": 1, "surah": 114}, ...]`
///   * `{"ayahs": [{"ayah": 1, "surah": 114, "text": "..."}, ...]}`
///   * `{"surah": 1, "ayah": 1, "text": "..."}`  (per-ayah endpoint)
/// Anything else — including plain-text 404 bodies and empty arrays — yields an
/// empty map.
Map<int, String> tafsirEntriesFrom(dynamic decoded) {
  final result = <int, String>{};
  if (decoded is Map) {
    final ayahs = decoded['ayahs'];
    if (ayahs is List) {
      _collectEntries(ayahs, result);
      return result;
    }
    final entry = _entryFrom(decoded);
    if (entry != null) result[entry.key] = entry.value;
    return result;
  }
  if (decoded is List) {
    _collectEntries(decoded, result);
  }
  return result;
}

/// Convenience wrapper over [tafsirEntriesFrom] for a raw JSON body.
Map<int, String> normalizeTafsirPayload(String body) =>
    tafsirEntriesFrom(decodeJsonBody(body));

void _collectEntries(List<dynamic> list, Map<int, String> into) {
  for (final item in list) {
    if (item is! Map) continue;
    final entry = _entryFrom(item);
    if (entry != null) into[entry.key] = entry.value;
  }
}

MapEntry<int, String>? _entryFrom(Map item) {
  final ayah = item['ayah'];
  final text = item['text'];
  if (ayah is! num || text is! String) return null;
  final trimmed = text.trim();
  if (trimmed.isEmpty) return null;
  return MapEntry(ayah.toInt(), trimmed);
}

/// Read-only client for the tafsir_api static CDN
/// (https://github.com/spa5k/tafsir_api).
///
/// Requests go through [MirroredJsonClient], which tries each mirror in order.
/// Responses are cached in SharedPreferences under the `cache_` prefix so
/// `SettingsService.clearAllCache()` clears them too.
class TafsirApiService {
  TafsirApiService({http.Client? client, List<String>? mirrors})
    : _http = MirroredJsonClient(
        mirrors: mirrors ?? defaultMirrors,
        client: client,
      );

  final MirroredJsonClient _http;

  /// Tried in order. jsDelivr is fastest, then the GitHub raw endpoint and
  /// Statically as fallbacks.
  static const List<String> defaultMirrors = [
    'https://cdn.jsdelivr.net/gh/spa5k/tafsir_api@main/tafsir',
    'https://raw.githubusercontent.com/spa5k/tafsir_api/main/tafsir',
    'https://cdn.statically.io/gh/spa5k/tafsir_api/main/tafsir',
  ];

  static const String _keyEditions = 'cache_tafsir_editions_v1';

  /// Cache key for one edition's tafsir of one surah.
  static String surahCacheKey(String slug, int surah) =>
      'cache_tafsir_${slug}_${surah}_v1';

  /// The full upstream catalogue (122 editions).
  Future<List<TafsirEdition>> fetchEditions({bool forceRefresh = false}) async {
    final prefs = await SharedPreferences.getInstance();
    if (!forceRefresh) {
      final cached = prefs.getString(_keyEditions);
      if (cached != null) {
        final editions = _editionsFrom(decodeJsonBody(cached));
        if (editions.isNotEmpty) return editions;
      }
    }

    final editions = _editionsFrom(await _http.getJson('editions.json'));
    if (editions.isNotEmpty) {
      await prefs.setString(
        _keyEditions,
        json.encode([for (final e in editions) e.toJson()]),
      );
    }
    return editions;
  }

  /// `{ayahNumber: text}` for a whole surah, cached per edition.
  ///
  /// An empty map means the edition has no content for that surah — some
  /// editions are partial, and some are empty for the last surahs.
  Future<Map<int, String>> fetchSurahTafsir(
    String slug,
    int surah, {
    bool forceRefresh = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final key = surahCacheKey(slug, surah);

    if (!forceRefresh) {
      final cached = prefs.getString(key);
      if (cached != null) {
        final entries = tafsirEntriesFrom(decodeJsonBody(cached));
        if (entries.isNotEmpty) return entries;
      }
    }

    final entries = tafsirEntriesFrom(await _http.getJson('$slug/$surah.json'));
    if (entries.isNotEmpty) {
      await prefs.setString(
        key,
        json.encode([
          for (final e in entries.entries) {'ayah': e.key, 'text': e.value},
        ]),
      );
    }
    return entries;
  }

  /// Text for a single ayah, or null when the edition has nothing for it.
  Future<String?> fetchAyahTafsir(String slug, int surah, int ayah) async {
    final entries = await fetchSurahTafsir(slug, surah);
    final text = entries[ayah];
    return (text == null || text.isEmpty) ? null : text;
  }

  List<TafsirEdition> _editionsFrom(dynamic decoded) {
    if (decoded is! List) return const [];
    return [
      for (final e in decoded)
        if (e is Map && (e['slug'] as String? ?? '').trim().isNotEmpty)
          TafsirEdition.fromJson(e),
    ];
  }
}
