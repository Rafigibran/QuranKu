class Word {
  final String arabic;
  final String transliteration;
  final String translation;
  final int position;

  Word({
    required this.arabic,
    this.transliteration = '',
    this.translation = '',
    required this.position,
  });

  Map<String, dynamic> toJson() => {
    'arabic': arabic,
    'transliteration': transliteration,
    'translation': translation,
    'position': position,
  };

  factory Word.fromJson(Map<String, dynamic> j) => Word(
    arabic: j['arabic'] as String? ?? '',
    transliteration: j['transliteration'] as String? ?? '',
    translation: j['translation'] as String? ?? '',
    position: (j['position'] as num?)?.toInt() ?? 0,
  );
}
