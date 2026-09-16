import 'dart:convert';

enum KhatamType { pagesPerDay, byDate }

class KhatamTarget {
  final String id;
  final KhatamType type;
  int pagesPerDay;
  DateTime? targetDate; // only for byDate
  final int startSurah;
  final int startAyah;
  int curSurah;
  int curAyah;
  final int totalPages;
  final int totalAyahs;
  int pagesDone;
  int ayahsDone;
  String dailyKey; // yyyy-MM-dd local
  int doneTodayPages;
  final DateTime createdAt;

  KhatamTarget({
    required this.id,
    required this.type,
    required this.pagesPerDay,
    this.targetDate,
    required this.startSurah,
    required this.startAyah,
    required this.curSurah,
    required this.curAyah,
    required this.totalPages,
    required this.totalAyahs,
    this.pagesDone = 0,
    this.ayahsDone = 0,
    required this.dailyKey,
    this.doneTodayPages = 0,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  double get progress =>
      totalPages <= 0 ? 0 : (pagesDone / totalPages).clamp(0.0, 1.0);

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'pagesPerDay': pagesPerDay,
    'targetDate': targetDate?.toIso8601String(),
    'startSurah': startSurah,
    'startAyah': startAyah,
    'curSurah': curSurah,
    'curAyah': curAyah,
    'totalPages': totalPages,
    'totalAyahs': totalAyahs,
    'pagesDone': pagesDone,
    'ayahsDone': ayahsDone,
    'dailyKey': dailyKey,
    'doneTodayPages': doneTodayPages,
    'createdAt': createdAt.toIso8601String(),
  };

  factory KhatamTarget.fromJson(Map<String, dynamic> j) => KhatamTarget(
    id: j['id'] as String,
    type: (j['type'] as String) == 'byDate'
        ? KhatamType.byDate
        : KhatamType.pagesPerDay,
    pagesPerDay: (j['pagesPerDay'] as num).toInt(),
    targetDate: j['targetDate'] != null
        ? DateTime.tryParse(j['targetDate'])
        : null,
    startSurah: (j['startSurah'] as num).toInt(),
    startAyah: (j['startAyah'] as num).toInt(),
    curSurah: (j['curSurah'] as num).toInt(),
    curAyah: (j['curAyah'] as num).toInt(),
    totalPages: (j['totalPages'] as num).toInt(),
    totalAyahs: (j['totalAyahs'] as num).toInt(),
    pagesDone: (j['pagesDone'] as num?)?.toInt() ?? 0,
    ayahsDone: (j['ayahsDone'] as num?)?.toInt() ?? 0,
    dailyKey: j['dailyKey'] as String? ?? '',
    doneTodayPages: (j['doneTodayPages'] as num?)?.toInt() ?? 0,
    createdAt: j['createdAt'] != null
        ? DateTime.tryParse(j['createdAt']) ?? DateTime.now()
        : DateTime.now(),
  );
}

class KhatamLog {
  final String date; // yyyy-MM-dd
  final int fromSurah;
  final int fromAyah;
  final int toSurah;
  final int toAyah;
  final int pages;
  final int ayahs;
  final DateTime at;

  KhatamLog({
    required this.date,
    required this.fromSurah,
    required this.fromAyah,
    required this.toSurah,
    required this.toAyah,
    required this.pages,
    required this.ayahs,
    DateTime? at,
  }) : at = at ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'date': date,
    'fromSurah': fromSurah,
    'fromAyah': fromAyah,
    'toSurah': toSurah,
    'toAyah': toAyah,
    'pages': pages,
    'ayahs': ayahs,
    'at': at.toIso8601String(),
  };

  factory KhatamLog.fromJson(Map<String, dynamic> j) => KhatamLog(
    date: j['date'] as String,
    fromSurah: (j['fromSurah'] as num).toInt(),
    fromAyah: (j['fromAyah'] as num).toInt(),
    toSurah: (j['toSurah'] as num).toInt(),
    toAyah: (j['toAyah'] as num).toInt(),
    pages: (j['pages'] as num).toInt(),
    ayahs: (j['ayahs'] as num).toInt(),
    at: j['at'] != null
        ? DateTime.tryParse(j['at']) ?? DateTime.now()
        : DateTime.now(),
  );

  static String encodeList(List<KhatamLog> l) =>
      json.encode(l.map((e) => e.toJson()).toList());
  static List<KhatamLog> decodeList(String s) {
    try {
      return (json.decode(s) as List)
          .map((e) => KhatamLog.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }
}

class KhatamHistory {
  final DateTime completedAt;
  final String type;
  final int daysUsed;
  final int totalPages;

  KhatamHistory({
    required this.completedAt,
    required this.type,
    required this.daysUsed,
    required this.totalPages,
  });

  Map<String, dynamic> toJson() => {
    'completedAt': completedAt.toIso8601String(),
    'type': type,
    'daysUsed': daysUsed,
    'totalPages': totalPages,
  };

  factory KhatamHistory.fromJson(Map<String, dynamic> j) => KhatamHistory(
    completedAt:
        DateTime.tryParse(j['completedAt'] as String? ?? '') ?? DateTime.now(),
    type: j['type'] as String? ?? 'pagesPerDay',
    daysUsed: (j['daysUsed'] as num?)?.toInt() ?? 0,
    totalPages: (j['totalPages'] as num?)?.toInt() ?? 0,
  );

  static String encodeList(List<KhatamHistory> l) =>
      json.encode(l.map((e) => e.toJson()).toList());
  static List<KhatamHistory> decodeList(String s) {
    try {
      return (json.decode(s) as List)
          .map((e) => KhatamHistory.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }
}
