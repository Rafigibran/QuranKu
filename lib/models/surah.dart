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
      number: json['number'],
      name: json['name'],
      nameAr: json['name_ar'],
      type: json['type'],
      totalAyahs: json['total_ayahs'],
    );
  }

  Map<String, dynamic> toJson() => {
    'number': number,
    'name': name,
    'name_ar': nameAr,
    'type': type,
    'total_ayahs': totalAyahs,
  };
}
