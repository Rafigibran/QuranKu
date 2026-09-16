import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:quranku/data/daily_duas.dart';
import 'package:quranku/services/hisnulmuslim_service.dart';
import 'package:quranku/services/mirrored_json.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> _chapter(int id, String title, int itemCount) => {
  'id': id,
  'title_ar': null,
  'title_en': title,
  'item_count': itemCount,
};

Map<String, dynamic> _item({
  required int id,
  required int chapterId,
  required String chapterTitle,
  String? title,
  String arabic = 'arabic',
  String english = 'english',
  String? transliteration,
  String? arabicTranslated,
}) => {
  'id': id,
  'chapter_id': chapterId,
  'chapter_title_en': chapterTitle,
  'title_en': title,
  'arabic_text': arabic,
  'english_text': english,
  'transliteration': transliteration,
  'LANGUAGE_ARABIC_TRANSLATED_TEXT': arabicTranslated == null
      ? null
      : {'raw': arabicTranslated},
};

http.Response _ok(Object data) => http.Response(
  json.encode({'success': true, 'message': 'ok', 'data': data}),
  200,
  // Arabic payloads only survive the round trip with an explicit charset.
  headers: {'content-type': 'application/json; charset=utf-8'},
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('DuaText / DailyDua', () {
    test('textFor picks the requested language', () {
      final dua = dailyDuas.first;
      expect(dua.textFor('id').title, 'Kebaikan dunia akhirat');
      expect(dua.textFor('en').title, 'Good in this world and the Hereafter');
    });

    test('textFor accepts regional tags and falls back to id', () {
      final dua = dailyDuas.first;
      expect(dua.textFor('en_US').title, dua.textFor('en').title);
      expect(dua.textFor('fr').title, dua.textFor('id').title);
    });

    test('every bundled dua has an id, an id variant and an en variant', () {
      for (final dua in dailyDuas) {
        expect(dua.id, startsWith('bundled-'));
        expect(dua.texts.keys, containsAll(<String>['id', 'en']));
        for (final text in dua.texts.values) {
          expect(text.title.trim(), isNotEmpty);
          expect(text.category.trim(), isNotEmpty);
          expect(text.translation.trim(), isNotEmpty);
          expect(text.source.trim(), isNotEmpty);
        }
      }
    });

    test('ids are unique and match the bundled count', () {
      final ids = dailyDuas.map((d) => d.id).toList();
      expect(ids.toSet(), hasLength(ids.length));
      expect(ids, hasLength(10));
    });

    test('legacy bookmark ids map every Indonesian title to its id', () {
      final legacy = legacyDuaBookmarkIds();
      expect(legacy, hasLength(dailyDuas.length));
      for (final dua in dailyDuas) {
        expect(legacy[dua.indonesianText!.title], dua.id);
      }
    });
  });

  group('HisnulmuslimService.fetchChapters', () {
    test('unwraps the envelope and parses chapter metadata', () async {
      final client = MockClient(
        (request) async => _ok([
          _chapter(1, 'supplications for when you wake up', 4),
          _chapter(6, 'Invocation for entering the restroom', 1),
        ]),
      );
      final service = HisnulmuslimService(client: client);

      final chapters = await service.fetchChapters();
      expect(chapters, hasLength(2));
      expect(chapters.first.id, 1);
      expect(chapters.first.titleEn, 'supplications for when you wake up');
      expect(chapters.first.itemCount, 4);
    });

    test('caches the chapter index across calls', () async {
      var calls = 0;
      final client = MockClient((request) async {
        calls++;
        return _ok([_chapter(1, 'chapter', 1)]);
      });
      final service = HisnulmuslimService(client: client);

      await service.fetchChapters();
      await service.fetchChapters();
      expect(calls, 1);
    });

    test('surfaces a transport failure instead of posing as an empty list',
        () async {
      final client = MockClient(
        (request) async => throw http.ClientException('offline'),
      );
      final service = HisnulmuslimService(client: client);

      expect(
        () => service.fetchChapters(),
        throwsA(isA<MirroredJsonException>()),
      );
    });
  });

  group('HisnulmuslimService.fetchChapter', () {
    test('maps items onto DailyDua with a stable hm- id', () async {
      final client = MockClient(
        (request) async => _ok({
          'id': 6,
          'title_en': 'Invocation for entering the restroom',
          'item_count': 1,
          'items': [
            _item(
              id: 10,
              chapterId: 6,
              chapterTitle: 'Invocation for entering the restroom',
              arabic: 'اللَّهُمَّ',
              english: 'O Allah, I take refuge with you',
              arabicTranslated: 'Allahumma innee aAAoothu bika',
            ),
          ],
        }),
      );
      final service = HisnulmuslimService(client: client);

      final duas = await service.fetchChapter(6);
      expect(duas, hasLength(1));
      final dua = duas.single;
      expect(dua.id, 'hm-6-10');
      expect(dua.arabic, 'اللَّهُمَّ');
      expect(dua.latin, 'Allahumma innee aAAoothu bika');
      expect(dua.textFor('en').translation, 'O Allah, I take refuge with you');
      expect(dua.textFor('en').source, HisnulmuslimService.sourceLabel);
      expect(dua.textFor('en').category,
          'Invocation for entering the restroom');
    });

    test('falls back to the chapter title when item title_en is null',
        () async {
      final client = MockClient(
        (request) async => _ok({
          'items': [
            _item(
              id: 1,
              chapterId: 3,
              chapterTitle: 'Invocation when getting dressed',
              title: null,
            ),
          ],
        }),
      );
      final service = HisnulmuslimService(client: client);

      final dua = (await service.fetchChapter(3)).single;
      expect(dua.textFor('en').title, 'Invocation when getting dressed');
    });

    test('sentence-cases lower-case upstream titles', () async {
      final client = MockClient(
        (request) async => _ok({
          'items': [
            _item(
              id: 1,
              chapterId: 1,
              chapterTitle: 'supplications for when you wake up',
              title: 'what to say before sleeping',
            ),
          ],
        }),
      );
      final service = HisnulmuslimService(client: client);

      final dua = (await service.fetchChapter(1)).single;
      expect(dua.textFor('en').title, 'What to say before sleeping');
      expect(dua.textFor('en').category, 'Supplications for when you wake up');
    });

    test('prefers transliteration from LANGUAGE_ARABIC_TRANSLATED_TEXT',
        () async {
      final client = MockClient(
        (request) async => _ok({
          'items': [
            _item(
              id: 1,
              chapterId: 1,
              chapterTitle: 'Chapter',
              transliteration: 'plain transliteration',
              arabicTranslated: 'raw transliteration',
            ),
            _item(
              id: 2,
              chapterId: 1,
              chapterTitle: 'Chapter',
              transliteration: 'plain transliteration',
            ),
            _item(
              id: 3,
              chapterId: 1,
              chapterTitle: 'Chapter',
              transliteration: null,
              arabicTranslated: null,
            ),
          ],
        }),
      );
      final service = HisnulmuslimService(client: client);

      final duas = await service.fetchChapter(1);
      expect(duas[0].latin, 'raw transliteration');
      expect(duas[1].latin, 'plain transliteration');
      expect(duas[2].latin, isEmpty);
    });

    test('caches a chapter and does not re-request it', () async {
      var calls = 0;
      final client = MockClient((request) async {
        calls++;
        return _ok({
          'items': [_item(id: 1, chapterId: 2, chapterTitle: 'Chapter')],
        });
      });
      final service = HisnulmuslimService(client: client);

      await service.fetchChapter(2);
      await service.fetchChapter(2);
      expect(calls, 1);
    });

    test('does not cache an empty chapter, so a retry can succeed', () async {
      var calls = 0;
      final client = MockClient((request) async {
        calls++;
        if (calls == 1) return _ok({'items': []});
        return _ok({
          'items': [_item(id: 1, chapterId: 9, chapterTitle: 'Chapter')],
        });
      });
      final service = HisnulmuslimService(client: client);

      expect(await service.fetchChapter(9), isEmpty);
      expect(await service.fetchChapter(9), hasLength(1));
    });
  });

  group('HisnulmuslimService.loadAll', () {
    MockClient buildClient(List<int> chapterIds, {Set<int> failing = const {}}) {
      return MockClient((request) async {
        final path = request.url.path;
        if (path.endsWith('chapters.json')) {
          return _ok([
            for (final id in chapterIds) _chapter(id, 'chapter $id', 1),
          ]);
        }
        if (path.endsWith('/items.json')) return _ok(<dynamic>[]);
        final id = int.tryParse(path.split('/').last.replaceAll('.json', ''));
        if (id == null) return http.Response('nope', 404);
        if (failing.contains(id)) throw http.ClientException('boom $id');
        return _ok({
          'items': [
            _item(id: id * 100, chapterId: id, chapterTitle: 'chapter $id'),
          ],
        });
      });
    }

    test('aggregates every chapter in chapter order', () async {
      final service = HisnulmuslimService(client: buildClient([3, 1, 2]));

      final duas = await service.loadAll();
      expect(duas.map((d) => d.id).toList(), ['hm-3-300', 'hm-1-100', 'hm-2-200']);
    });

    test('reports each chapter as a batch', () async {
      final service = HisnulmuslimService(client: buildClient([1, 2, 3]));

      final batches = <List<DailyDua>>[];
      await service.loadAll(onBatch: batches.add);

      expect(batches, hasLength(3));
      expect(batches.expand((b) => b), hasLength(3));
    });

    test('keeps going when one chapter fails', () async {
      final service = HisnulmuslimService(
        client: buildClient([1, 2, 3], failing: {2}),
      );

      final duas = await service.loadAll();
      expect(duas.map((d) => d.id).toList(), ['hm-1-100', 'hm-3-300']);
    });

    test('never exceeds the configured concurrency', () async {
      var inFlight = 0;
      var peak = 0;
      final client = MockClient((request) async {
        final path = request.url.path;
        if (path.endsWith('chapters.json')) {
          return _ok([for (var id = 1; id <= 20; id++) _chapter(id, 'c$id', 1)]);
        }
        inFlight++;
        peak = peak > inFlight ? peak : inFlight;
        await Future<void>.delayed(const Duration(milliseconds: 5));
        inFlight--;
        return _ok({
          'items': [_item(id: 1, chapterId: 1, chapterTitle: 'c')],
        });
      });
      final service = HisnulmuslimService(client: client);

      await service.loadAll(concurrency: 4);
      expect(peak, lessThanOrEqualTo(4));
      expect(peak, greaterThan(1));
    });

    test('returns empty when the chapter index cannot be fetched', () async {
      final client = MockClient(
        (request) async => throw http.ClientException('offline'),
      );
      final service = HisnulmuslimService(client: client);

      expect(await service.loadAll(), isEmpty);
    });

    test('serves a second run entirely from cache', () async {
      var calls = 0;
      final client = MockClient((request) async {
        calls++;
        if (request.url.path.endsWith('chapters.json')) {
          return _ok([_chapter(1, 'c1', 1), _chapter(2, 'c2', 1)]);
        }
        return _ok({
          'items': [_item(id: 1, chapterId: 1, chapterTitle: 'c')],
        });
      });
      final first = HisnulmuslimService(client: client);
      await first.loadAll();
      final callsAfterFirstRun = calls;

      final second = HisnulmuslimService(client: client);
      final duas = await second.loadAll();

      expect(duas, hasLength(2));
      expect(calls, callsAfterFirstRun);
    });
  });

  group('mirrors', () {
    test('falls back to the next mirror when the first 404s', () async {
      final hosts = <String>[];
      final client = MockClient((request) async {
        hosts.add(request.url.host);
        if (request.url.host == 'one') return http.Response('nope', 404);
        return _ok([_chapter(1, 'c1', 1)]);
      });
      final service = HisnulmuslimService(
        client: client,
        mirrors: const ['https://one/api/v1', 'https://two/api/v1'],
      );

      expect(await service.fetchChapters(), hasLength(1));
      expect(hosts, ['one', 'two']);
    });
  });

  group('cache keys', () {
    test('use the cache_ prefix so clearAllCache wipes them', () {
      expect(
        HisnulmuslimService.chapterCacheKey(27),
        startsWith('cache_'),
      );
      expect(
        HisnulmuslimService.chapterCacheKey(27),
        isNot(HisnulmuslimService.chapterCacheKey(28)),
      );
    });
  });
}
