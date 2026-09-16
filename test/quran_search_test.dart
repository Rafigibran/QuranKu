import 'package:flutter_test/flutter_test.dart';
import 'package:quranku/models/surah.dart';
import 'package:quranku/services/quran_search_service.dart';

Surah _s(int n, String name, [String ar = '']) => Surah(
  number: n,
  name: name,
  nameAr: ar,
  type: 'Makkiyah',
  totalAyahs: 7,
);

void main() {
  group('parseJump', () {
    test('parses 2:255 variants', () {
      expect(QuranSearchService.parseJump('2:255'), (surah: 2, ayah: 255));
      expect(QuranSearchService.parseJump('2.255'), (surah: 2, ayah: 255));
      expect(QuranSearchService.parseJump('2 255'), (surah: 2, ayah: 255));
      expect(QuranSearchService.parseJump(' 112 : 4 '), (surah: 112, ayah: 4));
    });

    test('rejects non-jump queries', () {
      expect(QuranSearchService.parseJump('al-fatihah'), isNull);
      expect(QuranSearchService.parseJump('yasin'), isNull);
      expect(QuranSearchService.parseJump('2'), isNull);
      expect(QuranSearchService.parseJump(''), isNull);
    });
  });

  group('stripDiacritics', () {
    test('normalizes hamza forms and ta marbuta', () {
      expect(QuranSearchService.stripDiacritics('أإآٱ'), 'اااا');
      expect(QuranSearchService.stripDiacritics('سورة'), 'سوره');
    });
  });

  group('matchSurahs', () {
    final all = [_s(1, 'Al-Fatihah', 'الفاتحة'), _s(36, 'Yasin', 'يس')];

    test('matches latin name case-insensitively', () {
      final r = QuranSearchService.matchSurahs(all, 'yasin');
      expect(r.map((s) => s.number), [36]);
    });

    test('matches arabic name and number', () {
      expect(
        QuranSearchService.matchSurahs(all, 'الفاتحة').map((s) => s.number),
        [1],
      );
      expect(
        QuranSearchService.matchSurahs(all, '36').map((s) => s.number),
        [36],
      );
    });

    test('empty query returns all', () {
      expect(QuranSearchService.matchSurahs(all, '  ').length, 2);
    });
  });

  group('shouldUseAi', () {
    test('local-only: jump, numbers, short hits', () {
      expect(
        QuranSearchService.shouldUseAi('2:255', localHitCount: 1),
        isFalse,
      );
      expect(
        QuranSearchService.shouldUseAi('36', localHitCount: 1),
        isFalse,
      );
      expect(
        QuranSearchService.shouldUseAi('yasin', localHitCount: 1),
        isFalse,
      );
      expect(QuranSearchService.shouldUseAi('', localHitCount: 0), isFalse);
    });

    test('AI: natural sentences', () {
      expect(
        QuranSearchService.shouldUseAi(
          'ayat tentang sabar',
          localHitCount: 5,
        ),
        isTrue,
      );
      expect(
        QuranSearchService.shouldUseAi(
          'cara bersabar dalam ujian',
          localHitCount: 0,
        ),
        isTrue,
      );
    });

    test('AI: two words with zero local hits', () {
      expect(
        QuranSearchService.shouldUseAi('sabar ujian', localHitCount: 0),
        isTrue,
      );
      expect(
        QuranSearchService.shouldUseAi('sabar ujian', localHitCount: 2),
        isFalse,
      );
    });
  });
}
