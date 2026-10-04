from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PATH = ROOT / 'lib' / 'screens' / 'surah_detail_screen.dart'

BUILD_TAJWID_START = "  Widget _buildTajwid(String markup, ColorScheme scheme) {"
TAJWID_COLOR_START = "  Color _tajwidColor(String className, ColorScheme scheme) {"
STRIP_START = "  String _stripTags"

BUILD_TAJWID = r'''  Widget _buildTajwid(String markup, ColorScheme scheme) {
    final spans = <InlineSpan>[];

    // Quran.com returns Tajweed markup using <tajweed class=...> tags
    // (and <span class=...> markers such as verse endings).
    final regex = RegExp(
      r"""<(?:tajweed|rule|span)\b[^>]*\bclass\s*=\s*["']?([^"'>\s]+)["']?[^>]*>(.*?)</(?:tajweed|rule|span)>""",
      dotAll: true,
      caseSensitive: false,
    );

    var cursor = 0;
    for (final match in regex.allMatches(markup)) {
      if (match.start > cursor) {
        spans.add(
          TextSpan(text: _stripTags(markup.substring(cursor, match.start))),
        );
      }

      final className = match.group(1) ?? '';
      final text = _stripTags(match.group(2) ?? '');
      spans.add(
        TextSpan(
          text: text,
          style: TextStyle(color: _tajwidColor(className, scheme)),
        ),
      );
      cursor = match.end;
    }

    if (cursor < markup.length) {
      spans.add(TextSpan(text: _stripTags(markup.substring(cursor))));
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: RichText(
        textAlign: TextAlign.right,
        text: TextSpan(
          style: GoogleFonts.notoNaskhArabic(
            fontSize: 30,
            height: 2.0,
            fontWeight: FontWeight.w600,
            color: scheme.onSurface,
          ),
          children: spans,
        ),
      ),
    );
  }
'''

TAJWID_COLORS = r'''  Color _tajwidColor(String className, ColorScheme scheme) {
    final c = className
        .toLowerCase()
        .replaceAll('-', '_')
        .replaceAll(' ', '_');

    // Palette follows the colour-coded Tajweed convention used by Quran
    // readers, tuned for the app's dark Eigengrau background.
    if (c == 'ham_wasl' || c == 'hamzat_wasl') {
      return const Color(0xFF9CFC4A);
    }
    if (c == 'slnt' ||
        c == 'silent' ||
        c == 'end' ||
        c == 'laam_shamsiyah' ||
        c == 'lam_shamsiyyah') {
      if (c == 'laam_shamsiyah' || c == 'lam_shamsiyyah') {
        return const Color(0xFFD44DFF);
      }
      return const Color(0xFFAAAAAA);
    }

    if (c == 'madda_normal' || c == 'madd_normal') {
      return const Color(0xFF4B83FF);
    }
    if (c == 'madda_permissible' ||
        c == 'madd_permissible' ||
        c == 'madda_jaiz_munfasil' ||
        c == 'madd_jaiz_munfasil' ||
        c == 'madd_246') {
      return const Color(0xFFD928E6);
    }
    if (c == 'madda_necessary' ||
        c == 'madd_necessary' ||
        c == 'madda_lazim' ||
        c == 'madd_lazim' ||
        c == 'madd_6') {
      return const Color(0xFFFF4FB3);
    }
    if (c == 'madda_obligatory' ||
        c == 'madd_obligatory' ||
        c == 'madda_wajib_muttasil' ||
        c == 'madd_wajib_muttasil' ||
        c == 'madd_muttasil') {
      return const Color(0xFFFF5A5F);
    }
    if (c == 'qalaqah' || c == 'qalqalah' || c == 'qlq') {
      return const Color(0xFF3F7CFF);
    }
    if (c == 'ikhfa_shafawi' || c == 'ikhf_shfw' || c == 'ikhfa') {
      return const Color(0xFF36C2A0);
    }
    if (c == 'iqlab' || c == 'iqlb') {
      return const Color(0xFFA14BCB);
    }
    if (c == 'idgham_shafawi' || c == 'idghaam_shafawi' || c == 'idghm_shfw') {
      return const Color(0xFF47B86B);
    }
    if (c == 'idgham_ghunnah' ||
        c == 'idghaam_ghunnah' ||
        c == 'idgham_with_ghunnah' ||
        c == 'idghaam_with_ghunnah' ||
        c == 'idgh_ghn') {
      return const Color(0xFF20B879);
    }
    if (c == 'idgham_without_ghunnah' ||
        c == 'idghaam_without_ghunnah' ||
        c == 'idgham_bila_ghunnah' ||
        c == 'idghaam_bila_ghunnah' ||
        c == 'idgh_w_ghn') {
      return const Color(0xFF169C47);
    }
    if (c == 'idgham_mutajanisayn' ||
        c == 'idghaam_mutajanisayn' ||
        c == 'idgham_mutamathilayn' ||
        c == 'idgham_mutaqaribayn' ||
        c == 'idghaam_mutaqaaribayn') {
      return const Color(0xFFC55CFF);
    }
    if (c == 'ghunnah' || c == 'ghn') {
      return const Color(0xFFFF7E1E);
    }
    if (c == 'waqf_lazim' ||
        c == 'waqf_jaiz' ||
        c == 'waqf_muaqabah' ||
        c == 'waqf_muanaqah' ||
        c == 'waqf_muanqah') {
      return const Color(0xFF537FFF);
    }

    return scheme.onSurface;
  }
'''
def replace_range(text: str, start_marker: str, end_marker: str, replacement: str) -> str:
    start = text.find(start_marker)
    if start < 0:
        raise RuntimeError(f'Not found: {start_marker}')
    end = text.find(end_marker, start)
    if end < 0:
        raise RuntimeError(f'Not found: {end_marker}')
    return text[:start] + replacement + text[end:]

def main() -> None:
    text = PATH.read_text(encoding='utf-8')
    text = replace_range(text, BUILD_TAJWID_START, TAJWID_COLOR_START, BUILD_TAJWID + '\n')
    text = replace_range(text, TAJWID_COLOR_START, STRIP_START, TAJWID_COLORS + '\n')
    text = text.replace(
        'GoogleFonts.amiri(',
        'GoogleFonts.notoNaskhArabic(fontWeight: FontWeight.w600,',
    )
    PATH.write_text(text, encoding='utf-8')
    print('Applied Quran.com Tajweed tag parsing, documented Tajweed colors, and Noto Naskh Arabic.')

if __name__ == '__main__':
    main()
