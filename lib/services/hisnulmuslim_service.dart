import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../data/daily_duas.dart';
import 'mirrored_json.dart';

/// One chapter of Hisn al-Muslim ("Fortress of the Muslim").
class HmChapter {
  final int id;
  final String titleEn;
  final int itemCount;

  const HmChapter({
    required this.id,
    required this.titleEn,
    required this.itemCount,
  });

  factory HmChapter.fromJson(Map json) => HmChapter(
    id: (json['id'] as num?)?.toInt() ?? 0,
    titleEn: '${json['title_en'] ?? ''}'.trim(),
    itemCount: (json['item_count'] as num?)?.toInt() ?? 0,
  );
}

/// English duas from Hisn al-Muslim, served as static JSON from GitHub.
///
/// The upstream API has no bulk endpoint — 267 supplications are spread across
/// 132 chapter files — so [loadAll] walks them with bounded concurrency and
/// caches each chapter verbatim. Later launches read everything from cache.
class HisnulmuslimService {
  HisnulmuslimService({http.Client? client, List<String>? mirrors})
    : _http = MirroredJsonClient(
        mirrors: mirrors ?? defaultMirrors,
        client: client,
      );

  final MirroredJsonClient _http;

  static const List<String> defaultMirrors = [
    'https://cdn.jsdelivr.net/gh/uthumany/hisn-al-muslim-api@master/api/v1',
    'https://uthumany.github.io/hisn-al-muslim-api/api/v1',
    'https://raw.githubusercontent.com/uthumany/hisn-al-muslim-api/master/api/v1',
  ];

  static const String sourceLabel = 'Hisn al-Muslim';
  static const String _keyChapters = 'cache_hm_chapters_v1';

  static String chapterCacheKey(int chapterId) =>
      'cache_hm_chapter_${chapterId}_v1';

  /// Chapter index (132 entries).
  Future<List<HmChapter>> fetchChapters({bool forceRefresh = false}) async {
    final prefs = await SharedPreferences.getInstance();
    if (!forceRefresh) {
      final cached = prefs.getString(_keyChapters);
      if (cached != null) {
        final chapters = _chaptersFrom(decodeJsonBody(cached));
        if (chapters.isNotEmpty) return chapters;
      }
    }

    final chapters = _chaptersFrom(await _http.getData('chapters.json'));
    if (chapters.isNotEmpty) {
      await prefs.setString(
        _keyChapters,
        json.encode([
          for (final c in chapters)
            {'id': c.id, 'title_en': c.titleEn, 'item_count': c.itemCount},
        ]),
      );
    }
    return chapters;
  }

  /// Supplications of one chapter.
  Future<List<DailyDua>> fetchChapter(
    int chapterId, {
    bool forceRefresh = false,
  }) async {
    final items = await _chapterItems(chapterId, forceRefresh: forceRefresh);
    return [for (final item in items) _toDua(item)];
  }

  /// Walks every chapter, reporting each batch as it arrives.
  ///
  /// Best effort: when the chapter index cannot be fetched (offline), this
  /// returns an empty list rather than throwing. Individual chapters that fail
  /// are skipped.
  ///
  /// [onBatch] is called from several concurrent workers, so the caller must
  /// tolerate being invoked from anywhere — and more than once.
  Future<List<DailyDua>> loadAll({
    void Function(List<DailyDua> batch)? onBatch,
    int concurrency = 6,
    bool forceRefresh = false,
  }) async {
    final List<HmChapter> chapters;
    try {
      chapters = await fetchChapters(forceRefresh: forceRefresh);
    } catch (e) {
      debugPrint('HisnulmuslimService.loadAll: chapter index failed: $e');
      return const [];
    }
    if (chapters.isEmpty) return const [];

    final loaded = <int, List<DailyDua>>{};
    var nextIndex = 0;

    Future<void> worker() async {
      while (true) {
        final index = nextIndex;
        nextIndex++;
        if (index >= chapters.length) return;

        final chapter = chapters[index];
        try {
          final duas = await fetchChapter(
            chapter.id,
            forceRefresh: forceRefresh,
          );
          loaded[chapter.id] = duas;
          if (duas.isNotEmpty) onBatch?.call(duas);
        } catch (e) {
          debugPrint('HisnulmuslimService.loadAll: chapter ${chapter.id}: $e');
        }
      }
    }

    await Future.wait([
      for (var i = 0; i < concurrency.clamp(1, 12); i++) worker(),
    ]);

    return [
      for (final chapter in chapters) ...?loaded[chapter.id],
    ];
  }

  /// Raw `items` array, cached verbatim so the cache codec is the API codec.
  Future<List<Map>> _chapterItems(
    int chapterId, {
    bool forceRefresh = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final key = chapterCacheKey(chapterId);

    if (!forceRefresh) {
      final cached = prefs.getString(key);
      if (cached != null) {
        final items = _itemsFrom(decodeJsonBody(cached));
        if (items.isNotEmpty) return items;
      }
    }

    final data = await _http.getData('chapters/$chapterId.json');
    final items = data is Map ? _itemsFrom(data['items']) : const <Map>[];
    if (items.isNotEmpty) {
      await prefs.setString(key, json.encode(items));
    }
    return items;
  }

  static List<Map> _itemsFrom(dynamic decoded) {
    if (decoded is! List) return const [];
    return [
      for (final e in decoded)
        if (e is Map) e,
    ];
  }

  static List<HmChapter> _chaptersFrom(dynamic decoded) {
    if (decoded is! List) return const [];
    return [
      for (final e in decoded)
        if (e is Map) HmChapter.fromJson(e),
    ];
  }

  static DailyDua _toDua(Map item) {
    final chapterId = (item['chapter_id'] as num?)?.toInt() ?? 0;
    final itemId = (item['id'] as num?)?.toInt() ?? 0;
    final chapterTitle = _sentenceCase('${item['chapter_title_en'] ?? ''}'.trim());
    final itemTitle = '${item['title_en'] ?? ''}'.trim();

    return DailyDua(
      id: 'hm-$chapterId-$itemId',
      arabic: '${item['arabic_text'] ?? ''}'.trim(),
      latin: _transliterationOf(item),
      texts: {
        'en': DuaText(
          title: _sentenceCase(itemTitle.isNotEmpty ? itemTitle : chapterTitle),
          category: chapterTitle.isNotEmpty ? chapterTitle : sourceLabel,
          translation: '${item['english_text'] ?? ''}'.trim(),
          source: sourceLabel,
        ),
      },
    );
  }

  static String _transliterationOf(Map item) {
    final latin = item['LANGUAGE_ARABIC_TRANSLATED_TEXT'];
    if (latin is Map) {
      final raw = '${latin['raw'] ?? ''}'.trim();
      if (raw.isNotEmpty) return raw;
    }
    return '${item['transliteration'] ?? ''}'.trim();
  }

  static String _sentenceCase(String value) => value.isEmpty
      ? value
      : value[0].toUpperCase() + value.substring(1);
}
