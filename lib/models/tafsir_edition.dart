/// A tafsir (Qur'an interpretation) edition the reader can display.
///
/// Editions come from the public tafsir_api catalogue
/// (https://github.com/spa5k/tafsir_api), except the built-in Kemenag tafsir
/// which is served by equran.id and identified by [slug] == 'kemenag-id'.
class TafsirEdition {
  /// Stable id: also the tafsir_api `slug`.
  final String slug;
  final String name;
  final String authorName;

  /// Lower-case English language name as published upstream,
  /// e.g. `indonesian`, `english`, `arabic`.
  final String languageName;
  final String source;
  final int? upstreamId;

  const TafsirEdition({
    required this.slug,
    required this.name,
    required this.authorName,
    required this.languageName,
    required this.source,
    this.upstreamId,
  });

  factory TafsirEdition.fromJson(Map<dynamic, dynamic> json) => TafsirEdition(
    slug: (json['slug'] as String? ?? '').trim(),
    name: (json['name'] as String? ?? '').trim(),
    authorName: (json['author_name'] as String? ?? '').trim(),
    languageName: (json['language_name'] as String? ?? '').trim().toLowerCase(),
    source: (json['source'] as String? ?? '').trim(),
    upstreamId: (json['id'] as num?)?.toInt(),
  );

  Map<String, dynamic> toJson() => {
    'slug': slug,
    'name': name,
    'author_name': authorName,
    'language_name': languageName,
    'source': source,
    if (upstreamId != null) 'id': upstreamId,
  };

  @override
  String toString() => 'TafsirEdition($slug)';
}
