import 'dart:convert';

class Dhikr {
  final String id;
  final String arabic;
  final String latin;
  final String translation;

  /// English translation of [translation]. Empty for user-authored dhikr —
  /// those are never machine-translated, so they fall back to [translation].
  final String translationEn;
  final String category; // shalawat, dzikir, doa, custom
  final int target;
  int count;
  int totalCompleted;
  final DateTime createdAt;
  DateTime? lastUsedAt;

  Dhikr({
    required this.id,
    required this.arabic,
    this.latin = '',
    this.translation = '',
    this.translationEn = '',
    this.category = 'custom',
    this.target = 33,
    this.count = 0,
    this.totalCompleted = 0,
    DateTime? createdAt,
    this.lastUsedAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Translation in [languageCode], falling back to the source language.
  String translationFor(String languageCode) =>
      languageCode.startsWith('en') && translationEn.isNotEmpty
      ? translationEn
      : translation;

  Dhikr copyWith({
    String? arabic,
    String? latin,
    String? translation,
    String? translationEn,
    String? category,
    int? target,
    int? count,
    int? totalCompleted,
    DateTime? lastUsedAt,
  }) => Dhikr(
    id: id,
    arabic: arabic ?? this.arabic,
    latin: latin ?? this.latin,
    translation: translation ?? this.translation,
    translationEn: translationEn ?? this.translationEn,
    category: category ?? this.category,
    target: target ?? this.target,
    count: count ?? this.count,
    totalCompleted: totalCompleted ?? this.totalCompleted,
    createdAt: createdAt,
    lastUsedAt: lastUsedAt ?? this.lastUsedAt,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'arabic': arabic,
    'latin': latin,
    'translation': translation,
    'translationEn': translationEn,
    'category': category,
    'target': target,
    'count': count,
    'totalCompleted': totalCompleted,
    'createdAt': createdAt.toIso8601String(),
    'lastUsedAt': lastUsedAt?.toIso8601String(),
  };

  factory Dhikr.fromJson(Map<String, dynamic> j) => Dhikr(
    id: j['id'] as String,
    arabic: j['arabic'] as String? ?? '',
    latin: j['latin'] as String? ?? '',
    translation: j['translation'] as String? ?? '',
    translationEn: j['translationEn'] as String? ?? '',
    category: j['category'] as String? ?? 'custom',
    target: (j['target'] as num?)?.toInt() ?? 33,
    count: (j['count'] as num?)?.toInt() ?? 0,
    totalCompleted: (j['totalCompleted'] as num?)?.toInt() ?? 0,
    createdAt: j['createdAt'] != null
        ? DateTime.tryParse(j['createdAt']) ?? DateTime.now()
        : DateTime.now(),
    lastUsedAt: j['lastUsedAt'] != null
        ? DateTime.tryParse(j['lastUsedAt'])
        : null,
  );

  static String encodeList(List<Dhikr> list) =>
      json.encode(list.map((e) => e.toJson()).toList());
  static List<Dhikr> decodeList(String s) {
    try {
      final List<dynamic> arr = json.decode(s);
      return arr.map((e) => Dhikr.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }
}
