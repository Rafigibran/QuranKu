import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/ayah.dart';
import '../models/surah.dart';

/// Single source of truth for Quran search (Home unified search).
///
/// Covers: direct `surah:ayah` jump (e.g. `2:255`), surah title matches,
/// and full-text ayat search over locally cached surahs.
class QuranSearchService {
  static const recentKey = 'search_recent';
  static const maxRecent = 8;
  static const maxHits = 80;
  static const maxScannedSurahs = 30;

  /// Parse `2:255`-style jump references. Pure — unit tested.
  static ({int surah, int ayah})? parseJump(String raw) {
    final m = RegExp(r'^(\d+)\s*[:.\-\s]\s*(\d+)$').firstMatch(raw.trim());
    if (m == null) return null;
    final s = int.tryParse(m.group(1)!);
    final a = int.tryParse(m.group(2)!);
    if (s == null || a == null) return null;
    return (surah: s, ayah: a);
  }

  /// Arabic normalization for matching. Pure — unit tested.
  static String stripDiacritics(String s) {
    return s
        .replaceAll(RegExp(r'[ً-ٰٟ]'), '')
        .replaceAll(RegExp(r'[أإآٱ]'), 'ا')
        .replaceAll('ة', 'ه')
        .replaceAll('ى', 'ي')
        .toLowerCase();
  }

  /// Surah title / number matches. Pure — unit tested.
  static List<Surah> matchSurahs(List<Surah> all, String raw) {
    final q = raw.trim();
    if (q.isEmpty) return all;
    final qLower = q.toLowerCase();
    return all
        .where(
          (s) =>
              s.name.toLowerCase().contains(qLower) ||
              s.nameAr.contains(q) ||
              s.number.toString() == q,
        )
        .toList();
  }

  /// Decide whether a query deserves AI semantic follow-up. Pure.
  /// Local-only: jump refs (`2:255`), pure numbers, 1-2 short words that
  /// already hit. AI: natural sentences (>=3 words), or 2+ words with zero
  /// local hits (likely a meaning question, not a keyword).
  static bool shouldUseAi(String raw, {required int localHitCount}) {
    final q = raw.trim();
    if (q.isEmpty) return false;
    if (parseJump(q) != null) return false;
    if (RegExp(r'^\d+$').hasMatch(q)) return false;
    final words = q
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.length >= 3) return true;
    if (localHitCount == 0 && words.length >= 2) return true;
    return false;
  }

  /// Full unified search: jump + surah titles + cached ayat text.
  /// [field] is one of `Semua`, `Arab`, `Latin`, `Terjemah`.
  static Future<List<SearchHit>> search({
    required List<Surah> allSurahs,
    required String raw,
    String field = 'Semua',
  }) async {
    final q = raw.trim();
    if (q.isEmpty) return const [];

    final hits = <SearchHit>[];

    final jump = parseJump(q);
    if (jump != null) {
      final surah = _surahOrPlaceholder(allSurahs, jump.surah);
      hits.add(
        SearchHit(
          surah: surah,
          ayah: Ayah(
            number: jump.ayah,
            arabic: '',
            translation: 'Langsung ke ayat',
            transliteration: '',
          ),
          snippet: 'QS ${jump.surah}:${jump.ayah}',
          matchField: 'jump',
        ),
      );
      return hits;
    }

    final qLower = q.toLowerCase();
    final qStripped = stripDiacritics(q);

    for (final surah in matchSurahs(allSurahs, q)) {
      hits.add(
        SearchHit(
          surah: surah,
          snippet: '${surah.name} • ${surah.nameAr}',
          matchField: 'surah',
        ),
      );
    }

    final prefs = await SharedPreferences.getInstance();
    final keys = prefs
        .getKeys()
        .where(
          (k) =>
              k.startsWith('cache_surah_') &&
              (k.endsWith('_v5') || k.endsWith('_v4')),
        )
        .toList();

    final Map<int, String> surahCacheKey = {};
    for (final k in keys) {
      final parts = k.split('_');
      if (parts.length >= 3) {
        final n = int.tryParse(parts[2]);
        if (n != null && !surahCacheKey.containsKey(n)) {
          final prefix = 'cache_surah_${n}_';
          final hasV5 = keys.any(
            (e) => e.startsWith(prefix) && e.endsWith('_v5'),
          );
          surahCacheKey[n] = hasV5
              ? keys.firstWhere(
                  (e) => e.startsWith(prefix) && e.endsWith('_v5'),
                  orElse: () => k,
                )
              : k;
        }
      }
    }

    int scanned = 0;
    for (final entry in surahCacheKey.entries) {
      if (scanned > maxScannedSurahs || hits.length > maxHits) break;
      final dataStr = prefs.getString(entry.value);
      if (dataStr == null) continue;
      try {
        final List<dynamic> data = json.decode(dataStr);
        for (final item in data) {
          final ayah = Ayah(
            number: item['number'] as int,
            arabic: item['arabic'] as String? ?? '',
            translation: item['translation'] as String? ?? '',
            transliteration: item['transliteration'] as String? ?? '',
          );
          final match = _matchAyah(ayah, q, qLower, qStripped, field);
          if (match != null) {
            hits.add(
              SearchHit(
                surah: _surahOrPlaceholder(allSurahs, entry.key),
                ayah: ayah,
                snippet: match.snippet,
                matchField: match.field,
              ),
            );
            if (hits.length > maxHits) break;
          }
        }
        scanned++;
      } catch (_) {}
    }

    return hits;
  }

  static ({String field, String snippet})? _matchAyah(
    Ayah ayah,
    String q,
    String qLower,
    String qStripped,
    String field,
  ) {
    if (field == 'Semua' || field == 'Arab') {
      if (ayah.arabic.contains(q) ||
          stripDiacritics(ayah.arabic).contains(qStripped)) {
        return (field: 'arab', snippet: ayah.arabic);
      }
    }
    if (field == 'Semua' || field == 'Latin') {
      if (ayah.transliteration.toLowerCase().contains(qLower)) {
        return (field: 'latin', snippet: ayah.transliteration);
      }
    }
    if (field == 'Semua' || field == 'Terjemah') {
      if (ayah.translation.toLowerCase().contains(qLower)) {
        return (field: 'terjemah', snippet: ayah.translation);
      }
    }
    if (ayah.number.toString() == q) {
      return (
        field: 'ayat',
        snippet: ayah.translation.isNotEmpty
            ? ayah.translation
            : ayah.arabic,
      );
    }
    return null;
  }

  static Surah _surahOrPlaceholder(List<Surah> all, int number) {
    return all.firstWhere(
      (s) => s.number == number,
      orElse: () => Surah(
        number: number,
        name: 'Surah $number',
        nameAr: '',
        type: '',
        totalAyahs: 0,
      ),
    );
  }

  static Future<List<String>> loadRecent() async {
    final p = await SharedPreferences.getInstance();
    return p.getStringList(recentKey) ?? [];
  }

  static Future<List<String>> saveRecent(String q, List<String> current) async {
    if (q.trim().isEmpty) return current;
    final list = List<String>.from(current)..remove(q);
    list.insert(0, q);
    if (list.length > maxRecent) list.removeLast();
    final p = await SharedPreferences.getInstance();
    await p.setStringList(recentKey, list);
    return list;
  }

  static Future<void> clearRecent() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(recentKey);
  }
}

class SearchHit {
  final Surah surah;
  final Ayah? ayah;
  final String snippet;
  final String matchField;

  const SearchHit({
    required this.surah,
    this.ayah,
    required this.snippet,
    required this.matchField,
  });

  bool get isSurah => ayah == null;
}
