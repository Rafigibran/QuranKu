import 'package:flutter/foundation.dart';

import '../models/tafsir_edition.dart';
import 'api_service.dart';
import 'settings_service.dart';
import 'tafsir_api_service.dart';

/// Policy layer behind the reader's tafsir sheet.
///
/// Dispatches between the built-in Kemenag tafsir (equran.id, Indonesian) and
/// the multi-language tafsir_api catalogue, and presents one ordered edition
/// list to the settings picker.
class TafsirService {
  TafsirService({TafsirApiService? api, ApiService? quranApi})
    : _api = api ?? TafsirApiService(),
      _quranApi = quranApi ?? ApiService();

  final TafsirApiService _api;
  final ApiService _quranApi;

  /// Surfaced first in the picker, in display order. Verified to return data;
  /// `in-tafsir-jalalayn` (empty) and `en-tafsir-ibn-kathir` (404) are
  /// deliberately excluded. Everything else from the catalogue follows.
  static const List<String> curatedSlugs = [
    'indonesian-mokhtasar',
    'id-tafsir-as-saadi',
    'en-tafsir-al-mukhtasar',
    'en-al-jalalayn',
    'tafsir-al-jalalayn',
    'en-tazkirul-quran',
    'en-tafsir-maarif-ul-quran',
    'ar-tafsir-al-mukhtasar',
    'ar-tafsir-muyassar',
    'ar-tafsir-as-saadi',
  ];

  static const TafsirEdition kemenagEdition = TafsirEdition(
    slug: SettingsService.kemenagTafsirId,
    name: 'Tafsir Kemenag',
    authorName: 'Kementerian Agama RI',
    languageName: 'indonesian',
    source: 'equran.id',
  );

  /// Built-in edition first, then the curated shortlist, then the rest of the
  /// upstream catalogue.
  ///
  /// Never throws: when the catalogue cannot be fetched (offline, or the CDN is
  /// down) this degrades to whatever is known locally, so the picker always has
  /// something to show.
  Future<List<TafsirEdition>> availableEditions({
    bool forceRefresh = false,
  }) async {
    List<TafsirEdition> remote;
    try {
      remote = await _api.fetchEditions(forceRefresh: forceRefresh);
    } catch (e) {
      debugPrint('TafsirService.availableEditions: $e');
      remote = const [];
    }

    final remaining = {for (final e in remote) e.slug: e};
    final ordered = <TafsirEdition>[kemenagEdition];
    for (final slug in curatedSlugs) {
      final edition = remaining.remove(slug);
      if (edition != null) ordered.add(edition);
    }
    ordered.addAll(remaining.values);
    return ordered;
  }

  /// True when [editions] came back without the upstream catalogue, i.e. only
  /// the built-in edition is available.
  static bool isCatalogueMissing(List<TafsirEdition> editions) =>
      editions.length <= 1;

  /// Display name for an edition id. Falls back to the id itself so the reader
  /// can still label the sheet when the catalogue is unreachable.
  Future<String> editionName(String editionId) async {
    if (editionId == SettingsService.kemenagTafsirId) {
      return kemenagEdition.name;
    }
    try {
      for (final edition in await _api.fetchEditions()) {
        if (edition.slug == editionId) return edition.name;
      }
    } catch (e) {
      debugPrint('TafsirService.editionName: $e');
    }
    return editionId;
  }

  /// `{ayahNumber: text}` for a whole surah. Empty when the edition has no
  /// content for it. Throws when the network is unavailable.
  Future<Map<int, String>> surahTafsir({
    required String editionId,
    required int surah,
    bool forceRefresh = false,
  }) {
    if (editionId == SettingsService.kemenagTafsirId) {
      return _kemenagSurahTafsir(surah);
    }
    return _api.fetchSurahTafsir(editionId, surah, forceRefresh: forceRefresh);
  }

  /// Text for a single ayah, or null when the edition has nothing for it.
  Future<String?> ayahTafsir({
    required String editionId,
    required int surah,
    required int ayah,
  }) async {
    final entries = await surahTafsir(editionId: editionId, surah: surah);
    final text = entries[ayah];
    return (text == null || text.isEmpty) ? null : text;
  }

  Future<Map<int, String>> _kemenagSurahTafsir(int surah) async {
    final list = await _quranApi.fetchTafsirCached(surah);
    return {for (final t in list) t.ayah: t.teks};
  }
}
