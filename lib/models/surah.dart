class Surah {
  final int number;
  final String name;
  final String nameAr;
  final String type;
  final int totalAyahs;

  Surah({
    required this.number,
    required this.name,
    required this.nameAr,
    required this.type,
    required this.totalAyahs,
  });

  factory Surah.fromJson(Map<String, dynamic> json) {
    return Surah(
      number: (json['number'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? '',
      nameAr: json['name_ar']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      totalAyahs: (json['total_ayahs'] as num?)?.toInt() ?? 0,
    );
  }
}
