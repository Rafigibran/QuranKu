from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
SCREENS = ROOT / 'lib' / 'screens'
WIDGETS = ROOT / 'lib' / 'widgets'


def write_if_changed(path: Path, text: str) -> None:
    old = path.read_text(encoding='utf-8')
    if text != old:
        path.write_text(text, encoding='utf-8')
        print(f'Redesigned {path.relative_to(ROOT)}')


def replace_method(text: str, signature: str, replacement: str) -> str:
    """Replace exactly one Dart method using balanced-brace scanning."""
    start = text.find(signature)
    if start < 0:
        return text
    brace_start = text.find('{', start)
    if brace_start < 0:
        return text

    depth = 0
    quote = None
    escape = False
    for i in range(brace_start, len(text)):
        ch = text[i]
        if quote is not None:
            if escape:
                escape = False
            elif ch == '\\':
                escape = True
            elif ch == quote:
                quote = None
            continue
        if ch in ('"', "'"):
            quote = ch
        elif ch == '{':
            depth += 1
        elif ch == '}':
            depth -= 1
            if depth == 0:
                return text[:start] + replacement + text[i + 1:]
    return text


def patch_fonts() -> None:
    for folder in (SCREENS, WIDGETS):
        for path in folder.glob('*.dart'):
            text = path.read_text(encoding='utf-8')
            text = text.replace('GoogleFonts.spaceGrotesk', 'GoogleFonts.ebGaramond')
            text = text.replace('FontWeight.w650', 'FontWeight.w600')
            write_if_changed(path, text)


def patch_liquid_surfaces() -> None:
    path = WIDGETS / 'liquid_glass.dart'
    text = path.read_text(encoding='utf-8')
    text = text.replace(
        'final border = scheme.outline.withValues(alpha: .72);',
        'final border = scheme.outline.withValues(alpha: .62);',
    )
    text = text.replace(
        'borderRadius: BorderRadius.circular(radius),\n        border: Border.all(color: border),',
        'borderRadius: BorderRadius.zero,\n        border: Border(bottom: BorderSide(color: border)),',
    )
    text = text.replace(
        'borderRadius: BorderRadius.circular(radius),\n          onTap: onTap,',
        'borderRadius: BorderRadius.zero,\n          onTap: onTap,',
    )
    write_if_changed(path, text)


def ensure_naming(text: str, import_anchor: str, field_anchor: str, add_listener: str, remove_listener: str) -> str:
    if "../services/surah_naming_service.dart" not in text:
        text = text.replace(import_anchor, import_anchor + "\nimport '../services/surah_naming_service.dart';", 1)
    if 'final SurahNamingService _naming = SurahNamingService();' not in text:
        text = text.replace(field_anchor, field_anchor + '\n  final SurahNamingService _naming = SurahNamingService();', 1)
        add_callback = add_listener[add_listener.find('(') + 1:add_listener.rfind(')')]
        remove_callback = remove_listener[remove_listener.find('(') + 1:remove_listener.rfind(')')]
        text = text.replace(add_listener, add_listener + '\n    _naming.addListener(' + add_callback + ');', 1)
        text = text.replace(remove_listener, remove_listener + '\n    _naming.removeListener(' + remove_callback + ');', 1)
    return text


def patch_surah_list() -> None:
    path = SCREENS / 'surah_list_screen.dart'
    text = path.read_text(encoding='utf-8')
    text = ensure_naming(
        text,
        "import '../services/settings_service.dart';",
        '  final SettingsService _settings = SettingsService();',
        '    _settings.addListener(_onSettingsUpdate);',
        '    _settings.removeListener(_onSettingsUpdate);',
    )

    card = '''  Widget _buildSurahCard(Surah surah) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isLastRead = _lastReadSurah == surah.number;
    final displayName = _naming.displayName(surah.number, surah.name);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openSurah(surah),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 11),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 38,
                child: Text(
                  _settings.formatNumber(surah.number),
                  style: GoogleFonts.ebGaramond(
                    color: scheme.primary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.ebGaramond(
                        color: scheme.onSurface,
                        fontSize: 19,
                        height: 1.05,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          '${_settings.formatNumber(surah.totalAyahs)} Ayat',
                          style: GoogleFonts.ebGaramond(
                            color: scheme.onSurfaceVariant,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(width: 7),
                        Text('•', style: TextStyle(color: scheme.outline)),
                        const SizedBox(width: 7),
                        Text(
                          surah.type == 'Meccan' ? 'Makkiyah' : 'Madaniyah',
                          style: GoogleFonts.ebGaramond(
                            color: scheme.onSurfaceVariant,
                            fontSize: 14,
                          ),
                        ),
                        if (isLastRead) ...[
                          const SizedBox(width: 8),
                          Icon(Icons.bookmark_rounded, size: 15, color: scheme.primary),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Text(
                surah.nameAr,
                textAlign: TextAlign.right,
                style: GoogleFonts.amiri(
                  color: isDark ? const Color(0xFFE8E0D2) : const Color(0xFF4A3B2D),
                  fontSize: 23,
                  height: 1.0,
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant, size: 20),
            ],
          ),
        ),
      ),
    );
  }'''
    text = replace_method(text, '  Widget _buildSurahCard(Surah surah) {', card)
    write_if_changed(path, text)


def patch_surah_detail() -> None:
    path = SCREENS / 'surah_detail_screen.dart'
    text = path.read_text(encoding='utf-8')
    text = ensure_naming(
        text,
        "import '../services/settings_service.dart';",
        '  final SettingsService _settings = SettingsService();',
        '    _settings.addListener(_onSettingsChanged);',
        '    _settings.removeListener(_onSettingsChanged);',
    )
    text = re.sub(
        r'(?<![A-Za-z0-9_])widget\.surah\.name(?![A-Za-z0-9_])',
        '_naming.displayName(widget.surah.number, widget.surah.name)',
        text,
    )
    write_if_changed(path, text)


def patch_settings() -> None:
    path = SCREENS / 'settings_screen.dart'
    text = path.read_text(encoding='utf-8')
    text = ensure_naming(
        text,
        "import '../services/settings_service.dart';",
        '  final SettingsService _settings = SettingsService();',
        '    _settings.addListener(_refresh);',
        '    _settings.removeListener(_refresh);',
    )
    text = text.replace(
        "subtitle: _settings.themeMode == ThemeMode.light ? 'Terang' : 'Gelap',",
        "subtitle: _settings.themeMode == ThemeMode.light ? 'Ivory' : 'Eigengrau',",
    )
    text = text.replace("title: const Text('Terang')", "title: const Text('Ivory')")
    text = text.replace("title: const Text('Gelap')", "title: const Text('Eigengrau')")

    write_if_changed(path, text)


patch_fonts()
patch_liquid_surfaces()
patch_surah_list()
patch_surah_detail()
patch_settings()
