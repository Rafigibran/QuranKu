class Ayah {
  final int number; // Ayah number in Surah
  final String arabic;
  final String translation;
  final String transliteration;

  Ayah({
    required this.number,
    required this.arabic,
    required this.translation,
    this.transliteration = '',
  });

  Map<String, dynamic> toJson() => {
    'number': number,
    'arabic': arabic,
    'translation': translation,
    'transliteration': transliteration,
  };

  factory Ayah.fromJson(Map<String, dynamic> json) => Ayah(
    number: json['number'] as int,
    arabic: json['arabic'] as String? ?? '',
    translation: json['translation'] as String? ?? '',
    transliteration: json['transliteration'] as String? ?? '',
  );

  Ayah copyWith({
    String? arabic,
    String? translation,
    String? transliteration,
  }) => Ayah(
    number: number,
    arabic: arabic ?? this.arabic,
    translation: translation ?? this.translation,
    transliteration: transliteration ?? this.transliteration,
  );
}
