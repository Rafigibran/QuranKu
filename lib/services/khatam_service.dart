import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/khatam.dart';
import '../models/surah.dart';

/// Target Khatam Quran with Madinah 604-page mapping (bundled asset).
/// Daily quota resets at local 00:00 via date-bucket rollover on access
/// plus a midnight timer while the app stays open.
class KhatamService extends ChangeNotifier {
  static final KhatamService _instance = KhatamService._internal();
  factory KhatamService() => _instance;
  KhatamService._internal();

  static const _keyTarget = 'khatam_target';
  static const _keyLogs = 'khatam_logs';
  static const _keyHistory = 'khatam_history';
  static const _keyCount = 'khatam_completed_count';

  KhatamTarget? _target;
  List<KhatamLog> _logs = [];
  List<KhatamHistory> _history = [];
  int _completedCount = 0;
  bool _initialized = false;

  // surah number -> page per ayah (index ayah-1), Madinah mushaf
  Map<int, List<int>> _pages = {};
  List<Surah>? _surahs;
  Timer? _midnightTimer;

  KhatamTarget? get target => _target;
  List<KhatamLog> get logs => List.unmodifiable(_logs);
  List<KhatamHistory> get history => List.unmodifiable(_history);
  int get completedCount => _completedCount;
  bool get isInitialized => _initialized;
  bool get hasActive => _target != null;

  static String dayKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  static String todayKey() => dayKey(DateTime.now());

  Future<void> init() async {
    if (_initialized) return;
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_keyTarget);
    if (raw != null && raw.isNotEmpty) {
      try {
        _target = KhatamTarget.fromJson(json.decode(raw));
      } catch (_) {
        _target = null;
      }
    }
    _logs = KhatamLog.decodeList(p.getString(_keyLogs) ?? '[]');
    _history = KhatamHistory.decodeList(p.getString(_keyHistory) ?? '[]');
    _completedCount = p.getInt(_keyCount) ?? 0;
    await _ensurePages();
    _rolloverIfNeeded();
    _scheduleMidnightRollover();
    _initialized = true;
    notifyListeners();
  }

  Future<void> _ensurePages() async {
    if (_pages.isNotEmpty) return;
    try {
      final s = await rootBundle.loadString('assets/mushaf_pages.json');
      final Map<String, dynamic> j = json.decode(s);
      _pages = j.map(
        (k, v) => MapEntry(
          int.parse(k),
          (v as List).map((e) => (e as num).toInt()).toList(),
        ),
      );
    } catch (e) {
      debugPrint('mushaf_pages missing: $e');
    }
  }

  Future<List<Surah>> _ensureSurahs(List<Surah>? provided) async {
    if (provided != null) {
      _surahs = provided;
      return provided;
    }
    if (_surahs != null) return _surahs!;
    try {
      final s = await rootBundle.loadString('assets/surah_list.json');
      final body = json.decode(s) as Map<String, dynamic>;
      _surahs = (body['data'] as List).map((e) => Surah.fromJson(e)).toList();
      return _surahs!;
    } catch (_) {
      return [];
    }
  }

  /// Global ayah index 0..6235 for (surah, ayah). -1 if invalid.
  int _globalIndex(int surah, int ayah, List<Surah> list) {
    if (surah < 1 || surah > 114 || ayah < 1) return -1;
    var offset = 0;
    for (final s in list) {
      if (s.number == surah) {
        if (ayah > s.totalAyahs) return -1;
        return offset + (ayah - 1);
      }
      offset += s.totalAyahs;
    }
    return -1;
  }

  /// Distinct Madinah pages covered from (fromS,fromA) to (toS,toA) inclusive.
  int pagesBetween(int fromS, int fromA, int toS, int toA, List<Surah> list) {
    final a = _globalIndex(fromS, fromA, list);
    final b = _globalIndex(toS, toA, list);
    if (a < 0 || b < 0 || b < a) return 0;
    // Walk ayahs collecting pages (max 6236 iterations, cheap)
    final seen = <int>{};
    var idx = 0;
    for (final s in list) {
      final pg = _pages[s.number];
      for (var ay = 1; ay <= s.totalAyahs; ay++, idx++) {
        if (idx < a || idx > b) continue;
        if (pg != null && ay - 1 < pg.length) {
          seen.add(pg[ay - 1]);
        }
      }
    }
    return seen.length;
  }

  int ayahsBetween(int fromS, int fromA, int toS, int toA, List<Surah> list) {
    final a = _globalIndex(fromS, fromA, list);
    final b = _globalIndex(toS, toA, list);
    if (a < 0 || b < 0 || b < a) return 0;
    return b - a + 1;
  }

  void _rolloverIfNeeded() {
    if (_target == null) return;
    final today = todayKey();
    if (_target!.dailyKey != today) {
      _target!.dailyKey = today;
      _target!.doneTodayPages = 0;
      _persistTarget();
    }
  }

  void _scheduleMidnightRollover() {
    _midnightTimer?.cancel();
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day + 1);
    final wait = midnight.difference(now) + const Duration(seconds: 5);
    _midnightTimer = Timer(wait, () {
      _rolloverIfNeeded();
      notifyListeners();
      _scheduleMidnightRollover();
    });
  }

  Future<void> _persistTarget() async {
    final p = await SharedPreferences.getInstance();
    if (_target == null) {
      await p.remove(_keyTarget);
    } else {
      await p.setString(_keyTarget, json.encode(_target!.toJson()));
    }
  }

  Future<void> _persistLists() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_keyLogs, KhatamLog.encodeList(_logs));
    await p.setString(_keyHistory, KhatamHistory.encodeList(_history));
    await p.setInt(_keyCount, _completedCount);
  }

  /// Create a new target. Throws on invalid input.
  Future<void> createTarget({
    required KhatamType type,
    int? pagesPerDay,
    DateTime? targetDate,
    required int startSurah,
    required int startAyah,
    List<Surah>? surahs,
  }) async {
    final list = await _ensureSurahs(surahs);
    await _ensurePages();
    if (list.isEmpty) throw Exception('Data surah belum tersedia.');
    if (_globalIndex(startSurah, startAyah, list) < 0)
      throw Exception('Ayat mulai tidak valid.');
    if (type == KhatamType.pagesPerDay) {
      if (pagesPerDay == null || pagesPerDay < 1 || pagesPerDay > 604) {
        throw Exception('Target halaman per hari harus 1-604.');
      }
    } else {
      if (targetDate == null) throw Exception('Pilih tanggal khatam.');
      final today = DateTime.now();
      final t = DateTime(targetDate.year, targetDate.month, targetDate.day);
      final now = DateTime(today.year, today.month, today.day);
      if (!t.isAfter(now))
        throw Exception('Tanggal khatam harus besok atau setelahnya.');
    }

    final totalPages = pagesBetween(
      startSurah,
      startAyah,
      114,
      list.last.totalAyahs,
      list,
    );
    final totalAyahs = ayahsBetween(
      startSurah,
      startAyah,
      114,
      list.last.totalAyahs,
      list,
    );
    if (totalPages <= 0) throw Exception('Rentang bacaan tidak valid.');

    int ppd;
    DateTime? td;
    if (type == KhatamType.pagesPerDay) {
      ppd = pagesPerDay!;
    } else {
      td = DateTime(targetDate!.year, targetDate.month, targetDate.day);
      final days = _daysInclusive(DateTime.now(), td);
      ppd = (totalPages / days).ceil().clamp(1, 604);
    }

    _target = KhatamTarget(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: type,
      pagesPerDay: ppd,
      targetDate: td,
      startSurah: startSurah,
      startAyah: startAyah,
      curSurah: startSurah,
      curAyah: startAyah,
      totalPages: totalPages,
      totalAyahs: totalAyahs,
      dailyKey: todayKey(),
    );
    await _persistTarget();
    notifyListeners();
  }

  static int _daysInclusive(DateTime from, DateTime to) {
    final a = DateTime(from.year, from.month, from.day);
    final b = DateTime(to.year, to.month, to.day);
    return b.difference(a).inDays + 1;
  }

  /// Days remaining for byDate target (inclusive, can be <= 0 when overdue).
  int? daysRemaining() {
    final t = _target;
    if (t == null || t.type != KhatamType.byDate || t.targetDate == null)
      return null;
    return _daysInclusive(DateTime.now(), t.targetDate!);
  }

  int todayQuotaLeft() {
    final t = _target;
    if (t == null) return 0;
    return (t.pagesPerDay - t.doneTodayPages).clamp(0, t.pagesPerDay);
  }

  /// Log reading up to (toSurah, toAyah). Advances position.
  /// Throws on invalid range. Completes khatam when reaching 114:6.
  Future<KhatamLog> logReading({
    required int toSurah,
    required int toAyah,
    List<Surah>? surahs,
  }) async {
    final t = _target;
    if (t == null) throw Exception('Belum ada target aktif.');
    _rolloverIfNeeded();
    final list = await _ensureSurahs(surahs);
    final fromS = t.curSurah;
    final fromA = t.curAyah;
    // First log starts AT start position: range includes start ayah
    final pages = pagesBetween(fromS, fromA, toSurah, toAyah, list);
    final ayahs = ayahsBetween(fromS, fromA, toSurah, toAyah, list);
    if (pages <= 0 || ayahs <= 0)
      throw Exception(
        'Rentang tidak valid. Pilih ayat setelah posisi saat ini.',
      );
    // Advance past logged range
    final next = _nextPosition(toSurah, toAyah, list);
    final log = KhatamLog(
      date: todayKey(),
      fromSurah: fromS,
      fromAyah: fromA,
      toSurah: toSurah,
      toAyah: toAyah,
      pages: pages,
      ayahs: ayahs,
    );
    _logs.insert(0, log);
    t.pagesDone = (t.pagesDone + pages).clamp(0, t.totalPages);
    t.ayahsDone += ayahs;
    t.doneTodayPages += pages;

    final last = list.last;
    if (toSurah == last.number && toAyah == last.totalAyahs) {
      // Khatam complete
      final daysUsed = _daysInclusive(t.createdAt, DateTime.now());
      _history.insert(
        0,
        KhatamHistory(
          completedAt: DateTime.now(),
          type: t.type.name,
          daysUsed: daysUsed,
          totalPages: t.totalPages,
        ),
      );
      _completedCount++;
      _target = null;
    } else if (next != null) {
      t.curSurah = next[0];
      t.curAyah = next[1];
    }
    await _persistTarget();
    await _persistLists();
    notifyListeners();
    return log;
  }

  /// Position right after (surah, ayah), or null if at end.
  List<int>? _nextPosition(int surah, int ayah, List<Surah> list) {
    for (final s in list) {
      if (s.number == surah) {
        if (ayah < s.totalAyahs) return [surah, ayah + 1];
        // next surah with ayah 1
        final idx = list.indexWhere((e) => e.number == surah);
        if (idx >= 0 && idx + 1 < list.length) {
          return [list[idx + 1].number, 1];
        }
        return null;
      }
    }
    return null;
  }

  Future<void> deleteTarget() async {
    _target = null;
    await _persistTarget();
    notifyListeners();
  }

  Future<void> clearHistory() async {
    _history = [];
    _logs = [];
    await _persistLists();
    notifyListeners();
  }

  String positionLabel() {
    final t = _target;
    if (t == null) return '-';
    return 'QS ${t.curSurah}:${t.curAyah}';
  }
}
