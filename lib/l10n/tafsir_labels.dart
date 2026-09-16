import 'app_localizations.dart';

/// Display label for a tafsir edition's language.
///
/// Upstream `language_name` values are lower-case English (`indonesian`,
/// `english`, `arabic`, ...), so they cannot be shown raw in an Indonesian UI.
/// Unknown languages fall back to the upstream name, sentence-cased — a proper
/// noun reads better than "other language".
String tafsirLanguageLabel(AppLocalizations l, String languageName) {
  final normalized = languageName.trim().toLowerCase();
  switch (normalized) {
    case 'indonesian':
      return l.tafsirLanguageIndonesian;
    case 'english':
      return l.tafsirLanguageEnglish;
    case 'arabic':
      return l.tafsirLanguageArabic;
    case '':
      return l.tafsirLanguageOther;
    default:
      return normalized[0].toUpperCase() + normalized.substring(1);
  }
}
