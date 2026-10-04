class QuranWord {
  final String arabic;
  final String translation;

  const QuranWord({required this.arabic, required this.translation});
}

class Ayah {
  final int number;
  final String arabic;
  final String translation;
  final String? indopak;
  final String? transliteration;
  final String? tajwidText;
  final List<QuranWord> words;
  final String? tajwidSource;
  final String? wordTranslationSource;

  Ayah({
    required this.number,
    required this.arabic,
    required this.translation,
    this.indopak,
    this.transliteration,
    this.tajwidText,
    this.words = const <QuranWord>[],
    this.tajwidSource,
    this.wordTranslationSource,
  });

  Ayah copyWith({
    String? indopak,
    String? transliteration,
    String? tajwidText,
    List<QuranWord>? words,
    String? tajwidSource,
    String? wordTranslationSource,
  }) => Ayah(
        number: number,
        arabic: arabic,
        translation: translation,
        indopak: indopak ?? this.indopak,
        transliteration: transliteration ?? this.transliteration,
        tajwidText: tajwidText ?? this.tajwidText,
        words: words ?? this.words,
        tajwidSource: tajwidSource ?? this.tajwidSource,
        wordTranslationSource: wordTranslationSource ?? this.wordTranslationSource,
      );
}
