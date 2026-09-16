/// Picks the best match for [languageCode] from a map of localized variants.
///
/// Falls back to `id` — the app's source language — and finally to any entry,
/// so a partially translated map never yields null.
T localizedValue<T>(Map<String, T> variants, String languageCode) {
  final primary = languageCode.split(RegExp('[-_]')).first;
  return variants[primary] ?? variants['id'] ?? variants.values.first;
}
