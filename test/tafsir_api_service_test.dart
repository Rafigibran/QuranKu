import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:quranku/models/tafsir_edition.dart';
import 'package:quranku/services/mirrored_json.dart';
import 'package:quranku/services/tafsir_api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The plain-text body jsDelivr returns for a file that does not exist.
const _jsdelivrMissing =
    "Couldn't find the requested file /tafsir/en-tafsir-ibn-kathir/114.json "
    'in spa5k/tafsir_api.';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('normalizeTafsirPayload', () {
    test('top-level array shape (most editions)', () {
      final body = json.encode([
        {'text': 'Ayat satu', 'ayah': 1, 'surah': 114},
        {'text': 'Ayat dua', 'ayah': 2, 'surah': 114},
      ]);
      expect(normalizeTafsirPayload(body), {1: 'Ayat satu', 2: 'Ayat dua'});
    });

    test('{"ayahs": [...]} shape (en-al-jalalayn)', () {
      final body = json.encode({
        'ayahs': [
          {'ayah': 1, 'surah': 114, 'text': 'Say I seek refuge'},
          {'ayah': 2, 'surah': 114, 'text': 'the King of mankind'},
        ],
      });
      expect(normalizeTafsirPayload(body), {
        1: 'Say I seek refuge',
        2: 'the King of mankind',
      });
    });

    test('single-object shape (per-ayah endpoint)', () {
      final body = json.encode({
        'surah': 1,
        'ayah': 1,
        'text': 'In the Name of God',
      });
      expect(normalizeTafsirPayload(body), {1: 'In the Name of God'});
    });

    test('empty edition yields an empty map', () {
      expect(normalizeTafsirPayload('[]'), isEmpty);
    });

    test('plain-text 404 body yields an empty map', () {
      expect(normalizeTafsirPayload(_jsdelivrMissing), isEmpty);
    });

    test('truncated JSON yields an empty map instead of throwing', () {
      expect(normalizeTafsirPayload('[{"text": "cut off"'), isEmpty);
    });

    test('skips malformed entries and blank text', () {
      final body = json.encode([
        {'text': 'ok', 'ayah': 1},
        {'text': 'no ayah'},
        {'ayah': 2},
        {'text': '   ', 'ayah': 3},
        {'text': 'ayah as string', 'ayah': '4'},
        'not a map',
        {'text': '  padded  ', 'ayah': 5},
      ]);
      expect(normalizeTafsirPayload(body), {1: 'ok', 5: 'padded'});
    });
  });

  group('TafsirEdition', () {
    test('parses an upstream catalogue entry', () {
      final edition = TafsirEdition.fromJson({
        'author_name': 'Hafiz Ibn Kathir',
        'id': 35,
        'language_name': 'english',
        'name': 'Tafsir Ibn Kathir',
        'slug': 'en-tafisr-ibn-kathir',
        'source': 'https://qul.tarteel.ai/resources/tafsir/35',
      });
      expect(edition.slug, 'en-tafisr-ibn-kathir');
      expect(edition.languageName, 'english');
      expect(edition.upstreamId, 35);
    });

    test('normalizes language_name casing and tolerates missing fields', () {
      final edition = TafsirEdition.fromJson({'slug': 'x', 'language_name': 'Kurdish'});
      expect(edition.languageName, 'kurdish');
      expect(edition.name, isEmpty);
      expect(edition.upstreamId, isNull);
    });

    test('toJson round-trips through fromJson', () {
      const original = TafsirEdition(
        slug: 'indonesian-mokhtasar',
        name: 'Al-Mukhtasar',
        authorName: 'Tafsir Center',
        languageName: 'indonesian',
        source: 'https://qul.tarteel.ai/resources/tafsir/260',
        upstreamId: 260,
      );
      final restored = TafsirEdition.fromJson(
        json.decode(json.encode(original.toJson())) as Map<String, dynamic>,
      );
      expect(restored.slug, original.slug);
      expect(restored.name, original.name);
      expect(restored.authorName, original.authorName);
      expect(restored.languageName, original.languageName);
      expect(restored.source, original.source);
      expect(restored.upstreamId, original.upstreamId);
    });
  });

  group('TafsirApiService mirrors and caching', () {
    test('falls back to the next mirror when the first 404s', () async {
      final requested = <String>[];
      final client = MockClient((request) async {
        requested.add(request.url.host);
        if (request.url.host == 'one') return http.Response(_jsdelivrMissing, 404);
        return http.Response(
          json.encode([
            {'text': 'from mirror two', 'ayah': 1},
          ]),
          200,
        );
      });
      final service = TafsirApiService(
        client: client,
        mirrors: const ['https://one/tafsir', 'https://two/tafsir'],
      );

      expect(await service.fetchSurahTafsir('slug', 1), {1: 'from mirror two'});
      expect(requested, ['one', 'two']);
    });

    test('treats a 2xx non-JSON body as missing and keeps trying', () async {
      final client = MockClient((request) async {
        if (request.url.host == 'one') {
          return http.Response('<html>error</html>', 200);
        }
        return http.Response(json.encode({'ayahs': []}), 200);
      });
      final service = TafsirApiService(
        client: client,
        mirrors: const ['https://one/tafsir', 'https://two/tafsir'],
      );

      expect(await service.fetchSurahTafsir('slug', 1), isEmpty);
    });

    test('returns empty (not throws) when every mirror is missing', () async {
      final client = MockClient(
        (request) async => http.Response(_jsdelivrMissing, 404),
      );
      final service = TafsirApiService(
        client: client,
        mirrors: const ['https://one/tafsir', 'https://two/tafsir'],
      );

      expect(await service.fetchSurahTafsir('slug', 114), isEmpty);
      expect(await service.fetchAyahTafsir('slug', 114, 1), isNull);
    });

    test('throws when no mirror can be reached at all', () async {
      final client = MockClient(
        (request) async => throw http.ClientException('offline'),
      );
      final service = TafsirApiService(
        client: client,
        mirrors: const ['https://one/tafsir', 'https://two/tafsir'],
      );

      expect(
        () => service.fetchSurahTafsir('slug', 1),
        throwsA(isA<MirroredJsonException>()),
      );
    });

    test('serves the second call from cache without hitting the network',
        () async {
      var calls = 0;
      final client = MockClient((request) async {
        calls++;
        return http.Response(
          json.encode([
            {'text': 'cached text', 'ayah': 1},
          ]),
          200,
        );
      });
      final service = TafsirApiService(client: client);

      expect(await service.fetchSurahTafsir('slug', 5), {1: 'cached text'});
      expect(await service.fetchSurahTafsir('slug', 5), {1: 'cached text'});
      expect(calls, 1);
    });

    test('does not cache an empty result, so a retry can still succeed',
        () async {
      var calls = 0;
      final client = MockClient((request) async {
        calls++;
        if (calls == 1) return http.Response('[]', 200);
        return http.Response(
          json.encode([
            {'text': 'now available', 'ayah': 1},
          ]),
          200,
        );
      });
      final service = TafsirApiService(client: client);

      expect(await service.fetchSurahTafsir('slug', 9), isEmpty);
      expect(await service.fetchSurahTafsir('slug', 9), {1: 'now available'});
      expect(calls, 2);
    });

    test('forceRefresh bypasses the cache', () async {
      var calls = 0;
      final client = MockClient((request) async {
        calls++;
        return http.Response(
          json.encode([
            {'text': 't$calls', 'ayah': 1},
          ]),
          200,
        );
      });
      final service = TafsirApiService(client: client);

      await service.fetchSurahTafsir('slug', 5);
      final refreshed = await service.fetchSurahTafsir(
        'slug',
        5,
        forceRefresh: true,
      );
      expect(refreshed, {1: 't2'});
      expect(calls, 2);
    });

    test('keeps editions with different slugs in separate cache entries',
        () async {
      final client = MockClient((request) async {
        final slug = request.url.pathSegments[request.url.pathSegments.length - 2];
        return http.Response(
          json.encode([
            {'text': 'text of $slug', 'ayah': 1},
          ]),
          200,
        );
      });
      final service = TafsirApiService(client: client);

      expect(await service.fetchSurahTafsir('en-al-jalalayn', 1), {
        1: 'text of en-al-jalalayn',
      });
      expect(await service.fetchSurahTafsir('indonesian-mokhtasar', 1), {
        1: 'text of indonesian-mokhtasar',
      });
    });
  });

  group('TafsirApiService.fetchEditions', () {
    test('parses the catalogue and skips entries without a slug', () async {
      final client = MockClient(
        (request) async => http.Response(
          json.encode([
            {
              'author_name': 'Tafsir Center',
              'id': 260,
              'language_name': 'indonesian',
              'name': 'Al-Mukhtasar',
              'slug': 'indonesian-mokhtasar',
              'source': 'qul',
            },
            {'name': 'broken entry'},
          ]),
          200,
        ),
      );
      final service = TafsirApiService(client: client);

      final editions = await service.fetchEditions();
      expect(editions, hasLength(1));
      expect(editions.single.slug, 'indonesian-mokhtasar');
      expect(editions.single.languageName, 'indonesian');
    });

    test('caches the catalogue across calls', () async {
      var calls = 0;
      final client = MockClient((request) async {
        calls++;
        return http.Response(
          json.encode([
            {'slug': 'a', 'name': 'A', 'language_name': 'english'},
          ]),
          200,
        );
      });
      final service = TafsirApiService(client: client);

      await service.fetchEditions();
      await service.fetchEditions();
      expect(calls, 1);
    });

    test('returns empty rather than throwing when every mirror is missing',
        () async {
      final client = MockClient(
        (request) async => http.Response(_jsdelivrMissing, 404),
      );
      final service = TafsirApiService(client: client);

      expect(await service.fetchEditions(), isEmpty);
    });
  });

  group('cache keys', () {
    test('use the cache_ prefix so clearAllCache wipes them', () {
      expect(TafsirApiService.surahCacheKey('en-al-jalalayn', 5), startsWith('cache_'));
      expect(TafsirApiService.surahCacheKey('en-al-jalalayn', 5),
          isNot(TafsirApiService.surahCacheKey('en-al-jalalayn', 6)));
    });
  });
}
