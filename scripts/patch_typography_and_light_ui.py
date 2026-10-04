from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def patch_file(path: Path, transform):
    text = path.read_text(encoding='utf-8')
    new_text = transform(text)
    if new_text != text:
        path.write_text(new_text, encoding='utf-8')
        print(f'Patched {path.relative_to(ROOT)}')


def patch_typography(text: str) -> str:
    # Google Sans is not distributed through Google Fonts. Use Inter as the
    # stable, open-source UI fallback with similar clean proportions.
    text = text.replace(
        "GoogleFonts.spaceGroteskTextTheme(",
        "GoogleFonts.interTextTheme(",
    )
    text = text.replace(
        "GoogleFonts.spaceGrotesk(",
        "GoogleFonts.inter(",
    )

    # Idiqlat is primarily an East Syriac typeface and is not suitable as the
    # primary Arabic Quran face. Keep the Arabic text on a Quran-appropriate
    # Arabic font so shaping/harakat remain correct and glyphs never disappear.
    text = text.replace(
        "GoogleFonts.amiriQuran(",
        "GoogleFonts.amiriQuran(",
    )
    text = text.replace(
        "GoogleFonts.amiri(",
        "GoogleFonts.amiriQuran(",
    )
    text = text.replace(
        "GoogleFonts.amiriTextTheme(",
        "GoogleFonts.notoNaskhArabicTextTheme(",
    )
    return text


def patch_theme(text: str) -> str:
    replacements = {
        "final background = isDark ? const Color(0xFF0C1C1B) : const Color(0xFFFFFBEE);":
            "final background = isDark ? const Color(0xFF0B1211) : const Color(0xFFF7F8F7);",
        "final surface = isDark ? const Color(0xFF122625) : Colors.white;":
            "final surface = isDark ? const Color(0xFF121A19) : Colors.white;",
        "final onSurface = isDark ? Colors.white : const Color(0xFF19302E);":
            "final onSurface = isDark ? const Color(0xFFF5F7F6) : const Color(0xFF18201F);",
        "final muted = isDark ? const Color(0xFFAFC8C5) : const Color(0xFF6B7F7C);":
            "final muted = isDark ? const Color(0xFFAAB9B7) : const Color(0xFF66716F);",
        "final outline = isDark ? const Color(0xFF24413F) : const Color(0xFFE3E6DA);":
            "final outline = isDark ? const Color(0xFF263432) : const Color(0xFFE1E4E3);",
    }
    for old, new in replacements.items():
        text = text.replace(old, new)
    return text


def patch_bottom_navigation(text: str) -> str:
    text = text.replace(
        "_navItem(context, 1, Icons.access_time_filled_rounded, 'Jadwal')",
        "_navItem(context, 1, Icons.access_time_filled_rounded, 'Jadwal')",
    )
    text = text.replace(
        "final background = isDark ? const Color(0xFF15302E) : Colors.white;",
        "final background = isDark ? const Color(0xFF111917) : Colors.white;",
    )
    text = text.replace(
        "final border = isDark ? const Color(0xFF244A47) : const Color(0xFFE4E8DC);",
        "final border = isDark ? const Color(0xFF2A3A38) : const Color(0xFFE2E5E4);",
    )
    text = text.replace(
        "final selectedFill = scheme.primary.withValues(alpha: 0.12);",
        "final selectedFill = Theme.of(context).brightness == Brightness.dark\n        ? const Color(0xFF1E3B38)\n        : const Color(0xFFDDF4F1);",
    )
    return text


for dart_file in (ROOT / 'lib').rglob('*.dart'):
    patch_file(dart_file, patch_typography)

patch_file(ROOT / 'lib' / 'main.dart', patch_theme)
patch_file(ROOT / 'lib' / 'screens' / 'main_screen.dart', patch_bottom_navigation)
