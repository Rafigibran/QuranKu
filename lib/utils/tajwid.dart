import 'package:flutter/material.dart';

// International Tajwid palette — standard mushaf colors
class TajwidPalette {
  static const ghunnah = Color(0xFFFF8A65); // orange
  static const qalqalah = Color(0xFFEF5350); // red
  static const ikhfa = Color(0xFF66BB6A); // green
  static const idgham = Color(0xFF42A5F5); // blue
  static const iqlab = Color(0xFFAB47BC); // purple
  static const mad = Color(0xFF26C6DA); // cyan
  static const hamz = Color(0xFFFFCA28); // amber

  static const Map<String, Color> byRule = {
    'ghunnah': ghunnah,
    'qalqalah': qalqalah,
    'ikhfa': ikhfa,
    'idgham': idgham,
    'iqlab': iqlab,
    'mad': mad,
  };
}

class TajwidToken {
  final String text;
  final String? rule; // null = normal
  TajwidToken(this.text, this.rule);
}

// Verified Tajwid parser — source: quran.com word-level uthmani tajweed.
// Tags look like <rule class=ghunnah>...</rule> (no quotes).
// Zero-fabrication rule: unknown classes stay plain, never guessed.
const Map<String, String> _tagToRule = {
  'ghunnah': 'ghunnah',
  'qalaqah': 'qalqalah',
  'qalqalah': 'qalqalah',
  'ikhafa': 'ikhfa',
  'ikhfa': 'ikhfa',
  'ikhafa_shafawi': 'ikhfa',
  'ikhfa_shfw': 'ikhfa',
  'idgham_ghunnah': 'idgham',
  'idgham_shafawi': 'idgham',
  'idgham_wo_ghunnah': 'idgham',
  'idgham_ghn': 'idgham',
  'idgham_msl': 'idgham',
  'idgham_mstk': 'idgham',
  'iqlab': 'iqlab',
  'madda_normal': 'mad',
  'madda_necessary': 'mad',
  'madda_obligatory_monfasel': 'mad',
  'madda_obligatory_mottasel': 'mad',
  'madda_permissible': 'mad',
  'madd_246': 'mad',
  'madd_mnsl': 'mad',
  'madd_mttl': 'mad',
  // Pronunciation guides below stay plain (no color):
  // ham_wasl, laam_shamsiyah, slnt, sakt, custom-alef-maksora
};

List<TajwidToken> parseTajweedTagged(String tagged) {
  if (tagged.isEmpty) return [TajwidToken(tagged, null)];
  if (!tagged.contains('<rule')) return [TajwidToken(tagged, null)];
  final tokens = <TajwidToken>[];
  final tagRe = RegExp(r'<rule class=([^>]+)>(.*?)</rule>', dotAll: true);
  int pos = 0;
  for (final m in tagRe.allMatches(tagged)) {
    if (m.start > pos) {
      tokens.add(TajwidToken(tagged.substring(pos, m.start), null));
    }
    final cls = m.group(1)!.trim().toLowerCase();
    final inner = m.group(2) ?? '';
    tokens.add(TajwidToken(inner, _tagToRule[cls]));
    pos = m.end;
  }
  if (pos < tagged.length) {
    tokens.add(TajwidToken(tagged.substring(pos), null));
  }
  // Strip any leftover markup so raw tags never leak to UI.
  final clean = tokens
      .map(
        (t) => TajwidToken(t.text.replaceAll(RegExp(r'<[^>]*>'), ''), t.rule),
      )
      .where((t) => t.text.isNotEmpty)
      .toList();
  if (clean.isEmpty)
    return [TajwidToken(tagged.replaceAll(RegExp(r'<[^>]*>'), ''), null)];
  return clean;
}

// Legacy entry kept for compatibility but now SAFE: no guessing.
// Returns plain text only. Use parseTajweedTagged with verified data.
List<TajwidToken> tokenizeTajwid(String arabic) {
  if (arabic.isEmpty) return [TajwidToken(arabic, null)];
  return [TajwidToken(arabic, null)];
}

Color tajwidColor(String? rule) {
  if (rule == null) return Colors.transparent;
  return TajwidPalette.byRule[rule] ?? Colors.transparent;
}
