/// Kategorisasi Juz 1-30 sesuai mushaf Madinah (batas standar).
/// Setiap entri: Juz -> [surah:ayat awal, surah:ayat akhir] inklusif.
class JuzInfo {
  final int number;
  final int startSurah;
  final int startAyah;
  final int endSurah;
  final int endAyah;

  const JuzInfo({
    required this.number,
    required this.startSurah,
    required this.startAyah,
    required this.endSurah,
    required this.endAyah,
  });

  static const List<JuzInfo> all = [
    JuzInfo(number: 1, startSurah: 1, startAyah: 1, endSurah: 2, endAyah: 141),
    JuzInfo(
      number: 2,
      startSurah: 2,
      startAyah: 142,
      endSurah: 2,
      endAyah: 252,
    ),
    JuzInfo(number: 3, startSurah: 2, startAyah: 253, endSurah: 3, endAyah: 92),
    JuzInfo(number: 4, startSurah: 3, startAyah: 93, endSurah: 4, endAyah: 23),
    JuzInfo(number: 5, startSurah: 4, startAyah: 24, endSurah: 4, endAyah: 147),
    JuzInfo(number: 6, startSurah: 4, startAyah: 148, endSurah: 5, endAyah: 81),
    JuzInfo(number: 7, startSurah: 5, startAyah: 82, endSurah: 6, endAyah: 110),
    JuzInfo(number: 8, startSurah: 6, startAyah: 111, endSurah: 7, endAyah: 87),
    JuzInfo(number: 9, startSurah: 7, startAyah: 88, endSurah: 8, endAyah: 40),
    JuzInfo(number: 10, startSurah: 8, startAyah: 41, endSurah: 9, endAyah: 92),
    JuzInfo(number: 11, startSurah: 9, startAyah: 93, endSurah: 11, endAyah: 5),
    JuzInfo(
      number: 12,
      startSurah: 11,
      startAyah: 6,
      endSurah: 12,
      endAyah: 52,
    ),
    JuzInfo(
      number: 13,
      startSurah: 12,
      startAyah: 53,
      endSurah: 14,
      endAyah: 52,
    ),
    JuzInfo(
      number: 14,
      startSurah: 15,
      startAyah: 1,
      endSurah: 16,
      endAyah: 128,
    ),
    JuzInfo(
      number: 15,
      startSurah: 17,
      startAyah: 1,
      endSurah: 18,
      endAyah: 74,
    ),
    JuzInfo(
      number: 16,
      startSurah: 18,
      startAyah: 75,
      endSurah: 20,
      endAyah: 135,
    ),
    JuzInfo(
      number: 17,
      startSurah: 21,
      startAyah: 1,
      endSurah: 22,
      endAyah: 78,
    ),
    JuzInfo(
      number: 18,
      startSurah: 23,
      startAyah: 1,
      endSurah: 25,
      endAyah: 20,
    ),
    JuzInfo(
      number: 19,
      startSurah: 25,
      startAyah: 21,
      endSurah: 27,
      endAyah: 55,
    ),
    JuzInfo(
      number: 20,
      startSurah: 27,
      startAyah: 56,
      endSurah: 29,
      endAyah: 45,
    ),
    JuzInfo(
      number: 21,
      startSurah: 29,
      startAyah: 46,
      endSurah: 33,
      endAyah: 30,
    ),
    JuzInfo(
      number: 22,
      startSurah: 33,
      startAyah: 31,
      endSurah: 36,
      endAyah: 27,
    ),
    JuzInfo(
      number: 23,
      startSurah: 36,
      startAyah: 28,
      endSurah: 39,
      endAyah: 31,
    ),
    JuzInfo(
      number: 24,
      startSurah: 39,
      startAyah: 32,
      endSurah: 41,
      endAyah: 46,
    ),
    JuzInfo(
      number: 25,
      startSurah: 41,
      startAyah: 47,
      endSurah: 45,
      endAyah: 37,
    ),
    JuzInfo(
      number: 26,
      startSurah: 46,
      startAyah: 1,
      endSurah: 51,
      endAyah: 30,
    ),
    JuzInfo(
      number: 27,
      startSurah: 51,
      startAyah: 31,
      endSurah: 57,
      endAyah: 29,
    ),
    JuzInfo(
      number: 28,
      startSurah: 58,
      startAyah: 1,
      endSurah: 66,
      endAyah: 12,
    ),
    JuzInfo(
      number: 29,
      startSurah: 67,
      startAyah: 1,
      endSurah: 77,
      endAyah: 50,
    ),
    JuzInfo(
      number: 30,
      startSurah: 78,
      startAyah: 1,
      endSurah: 114,
      endAyah: 6,
    ),
  ];

  static int _cmp(int s1, int a1, int s2, int a2) {
    if (s1 != s2) return s1.compareTo(s2);
    return a1.compareTo(a2);
  }

  /// Juz (1-30) untuk posisi QS surah:ayah.
  static int juzOf(int surah, int ayah) {
    for (final j in all) {
      if (_cmp(surah, ayah, j.startSurah, j.startAyah) >= 0 &&
          _cmp(surah, ayah, j.endSurah, j.endAyah) <= 0) {
        return j.number;
      }
    }
    if (_cmp(surah, ayah, 1, 1) < 0) return 1;
    return 30;
  }

  /// Rentang Juz yang dilalui sebuah surah (mis. [1, 2]).
  static List<int> juzRangeOfSurah(int surah, int totalAyahs) {
    if (totalAyahs < 1) return [juzOf(surah, 1)];
    final first = juzOf(surah, 1);
    final last = juzOf(surah, totalAyahs);
    return [for (var j = first; j <= last; j++) j];
  }

  /// Segmen surah di dalam Juz ini: [(surah, ayahAwal, ayahAkhir)].
  /// [totals] memetakan nomor surah -> jumlah ayat (untuk batas akhir
  /// segmen terakhir tiap surah).
  List<(int surah, int fromAyah, int toAyah)> segments(
    Map<int, int> totals,
  ) {
    final out = <(int, int, int)>[];
    for (var s = startSurah; s <= endSurah; s++) {
      final from = s == startSurah ? startAyah : 1;
      int to;
      if (s == endSurah) {
        to = endAyah;
      } else {
        to = totals[s] ?? endAyah;
      }
      if (to >= from) out.add((s, from, to));
    }
    return out;
  }

  /// Total ayat dalam Juz ini menurut [totals].
  int ayahCount(Map<int, int> totals) {
    var n = 0;
    for (final seg in segments(totals)) {
      n += seg.$3 - seg.$2 + 1;
    }
    return n;
  }

  /// Ayat terbaca dalam Juz ini; [isRead] mis. `SettingsService.isRead`.
  int readCount(Map<int, int> totals, bool Function(int, int) isRead) {
    var n = 0;
    for (final seg in segments(totals)) {
      for (var a = seg.$2; a <= seg.$3; a++) {
        if (isRead(seg.$1, a)) n++;
      }
    }
    return n;
  }
}
