import 'package:flutter_test/flutter_test.dart';
import 'package:quranku/models/juz.dart';

const _totals = <int, int>{1: 7, 2: 286, 3: 200};

void main() {
  group('segments', () {
    test('juz 1 spans two surahs', () {
      final segs = JuzInfo.all[0].segments(_totals);
      expect(segs, [(1, 1, 7), (2, 1, 141)]);
    });

    test('single-surah juz', () {
      final j = JuzInfo.all[1]; // 2:142-252
      expect(j.segments(_totals), [(2, 142, 252)]);
    });

    test('juz 30 tail without totals falls back safely', () {
      final j = JuzInfo.all[29];
      final segs = j.segments(const {});
      expect(segs.first.$1, 78);
      expect(segs.last, (114, 1, 6));
    });
  });

  group('counts', () {
    test('juz 1 ayah total', () {
      expect(JuzInfo.all[0].ayahCount(_totals), 7 + 141);
    });

    test('readCount counts only marked ayahs', () {
      final j = JuzInfo.all[0];
      var n = j.readCount(_totals, (s, a) => s == 1 && a <= 3);
      expect(n, 3);
      n = j.readCount(_totals, (s, a) => false);
      expect(n, 0);
    });
  });

  group('juzOf', () {
    test('boundaries', () {
      expect(JuzInfo.juzOf(1, 1), 1);
      expect(JuzInfo.juzOf(2, 141), 1);
      expect(JuzInfo.juzOf(2, 142), 2);
    });
  });
}
