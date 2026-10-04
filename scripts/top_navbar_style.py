from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]


def replace_method(text: str, signature: str, replacement: str) -> str:
    start = text.find(signature)
    if start < 0:
        return text
    brace = text.find('{', start)
    if brace < 0:
        raise RuntimeError(f'No body found for {signature}')
    depth = 0
    in_string = None
    escape = False
    i = brace
    while i < len(text):
        ch = text[i]
        if in_string:
            if escape:
                escape = False
            elif ch == '\\':
                escape = True
            elif ch == in_string:
                in_string = None
        else:
            if ch in ('"', "'", '`'):
                in_string = ch
            elif ch == '{':
                depth += 1
            elif ch == '}':
                depth -= 1
                if depth == 0:
                    return text[:start] + replacement + text[i + 1:]
        i += 1
    raise RuntimeError(f'Unbalanced method: {signature}')


def patch_main_theme() -> None:
    path = ROOT / 'lib' / 'main.dart'
    text = path.read_text()
    pattern = re.compile(r'appBarTheme: AppBarTheme\(.*?\n      \),\n      inputDecorationTheme:', re.S)
    replacement = '''appBarTheme: AppBarTheme(\n        backgroundColor: surface,\n        foregroundColor: onSurface,\n        surfaceTintColor: Colors.transparent,\n        elevation: 0,\n        scrolledUnderElevation: 0,\n        toolbarHeight: 74,\n        titleSpacing: 20,\n        centerTitle: false,\n        shape: Border(\n          bottom: BorderSide(\n            color: outline.withValues(alpha: .65),\n            width: .7,\n          ),\n        ),\n        titleTextStyle: GoogleFonts.spaceGrotesk(\n          color: onSurface,\n          fontSize: 23,\n          fontWeight: FontWeight.w800,\n          letterSpacing: -0.8,\n        ),\n        iconTheme: const IconThemeData(color: Colors.white, size: 22),\n      ),\n      inputDecorationTheme:'''
    text, count = pattern.subn(replacement, text, count=1)
    if count != 1:
        raise RuntimeError('Could not normalize global AppBarTheme')
    path.write_text(text)
    print('Updated global AppBarTheme')


def patch_playlist() -> None:
    path = ROOT / 'lib' / 'screens' / 'playlist_screen.dart'
    text = path.read_text()
    pattern = re.compile(r'appBar: AppBar\(.*?\n      body:', re.S)
    replacement = '''appBar: AppBar(\n        backgroundColor: colors.surface,\n        foregroundColor: colors.onSurface,\n        surfaceTintColor: Colors.transparent,\n        elevation: 0,\n        scrolledUnderElevation: 0,\n        toolbarHeight: 74,\n        titleSpacing: 20,\n        title: Column(\n          crossAxisAlignment: CrossAxisAlignment.start,\n          children: [\n            Text(\n              'PLAYLIST',\n              style: GoogleFonts.spaceGrotesk(\n                fontSize: 23,\n                fontWeight: FontWeight.w800,\n                letterSpacing: -0.8,\n                color: colors.onSurface,\n              ),\n            ),\n            Text(\n              'Kelola koleksi Surah favoritmu',\n              style: GoogleFonts.spaceGrotesk(\n                color: colors.onSurface.withValues(alpha: 0.55),\n                fontSize: 12,\n                fontWeight: FontWeight.w500,\n              ),\n            ),\n          ],\n        ),\n        actions: [\n          Padding(\n            padding: const EdgeInsets.only(right: 14),\n            child: Container(\n              width: 46,\n              height: 46,\n              decoration: BoxDecoration(\n                color: colors.surfaceContainerHighest,\n                borderRadius: BorderRadius.circular(17),\n                border: Border.all(color: colors.outline.withValues(alpha: 0.55)),\n              ),\n              child: IconButton(\n                onPressed: _createPlaylist,\n                icon: Icon(Icons.add_rounded, color: colors.onSurface),\n                tooltip: 'Playlist baru',\n              ),\n            ),\n          ),\n        ],\n        bottom: PreferredSize(\n          preferredSize: const Size.fromHeight(1),\n          child: Divider(\n            height: 1,\n            thickness: .7,\n            color: colors.outline.withValues(alpha: .65),\n          ),\n        ),\n      ),\n      body:'''
    text, count = pattern.subn(replacement, text, count=1)
    if count != 1:
        raise RuntimeError('Could not normalize Playlist AppBar')
    path.write_text(text)
    print('Updated Playlist top bar')


def patch_settings() -> None:
    path = ROOT / 'lib' / 'screens' / 'settings_screen.dart'
    text = path.read_text()
    pattern = re.compile(r'appBar: AppBar\(.*?\n      body:', re.S)
    replacement = '''appBar: AppBar(\n        backgroundColor: scheme.surface,\n        foregroundColor: scheme.onSurface,\n        surfaceTintColor: Colors.transparent,\n        elevation: 0,\n        scrolledUnderElevation: 0,\n        toolbarHeight: 74,\n        titleSpacing: 20,\n        title: Column(\n          crossAxisAlignment: CrossAxisAlignment.start,\n          children: [\n            Text(\n              'PENGATURAN',\n              style: GoogleFonts.spaceGrotesk(\n                color: scheme.onSurface,\n                fontSize: 23,\n                fontWeight: FontWeight.w800,\n                letterSpacing: -0.8,\n              ),\n            ),\n            Text(\n              'Sesuaikan QuranKu agar nyaman digunakan.',\n              style: GoogleFonts.spaceGrotesk(\n                color: scheme.onSurface.withValues(alpha: 0.55),\n                fontSize: 12,\n                fontWeight: FontWeight.w500,\n              ),\n            ),\n          ],\n        ),\n        bottom: PreferredSize(\n          preferredSize: const Size.fromHeight(1),\n          child: Divider(\n            height: 1,\n            thickness: .7,\n            color: scheme.outline.withValues(alpha: .65),\n          ),\n        ),\n      ),\n      body:'''
    text, count = pattern.subn(replacement, text, count=1)
    if count != 1:
        raise RuntimeError('Could not normalize Settings AppBar')
    path.write_text(text)
    print('Updated Settings top bar')


def patch_surah_list() -> None:
    path = ROOT / 'lib' / 'screens' / 'surah_list_screen.dart'
    text = path.read_text()

    old_hero = """              SliverToBoxAdapter(child: _buildTopBar(context)),\n              SliverToBoxAdapter(child: _buildHeroCard(context)),\n              SliverToBoxAdapter(child: _buildResumeCard(context)),\n"""
    new_hero = """              SliverToBoxAdapter(child: _buildTopBar(context)),\n              SliverToBoxAdapter(child: _buildResumeCard(context)),\n"""
    if old_hero in text:
        text = text.replace(old_hero, new_hero, 1)
        print('Removed home hero card')

    hero_pattern = re.compile(r"  Widget _buildHeroCard\(BuildContext context\) \{.*?\n  Widget _buildResumeCard\(", re.S)
    text, removed = hero_pattern.subn("  Widget _buildResumeCard(", text, count=1)
    if removed:
        print('Removed unused hero card method')

    replacement = '''Widget _buildTopBar(BuildContext context) {\n    final scheme = Theme.of(context).colorScheme;\n\n    return Container(\n      width: double.infinity,\n      decoration: BoxDecoration(\n        color: scheme.surface,\n        border: Border(\n          bottom: BorderSide(\n            color: scheme.outline.withValues(alpha: 0.65),\n            width: 0.7,\n          ),\n        ),\n      ),\n      padding: const EdgeInsets.fromLTRB(20, 12, 14, 10),\n      child: SizedBox(\n        height: 52,\n        child: Row(\n          children: [\n            Expanded(\n              child: Column(\n                crossAxisAlignment: CrossAxisAlignment.start,\n                mainAxisAlignment: MainAxisAlignment.center,\n                children: [\n                  Text(\n                    'QuranKu',\n                    style: GoogleFonts.spaceGrotesk(\n                      fontSize: 23,\n                      fontWeight: FontWeight.w800,\n                      letterSpacing: -0.8,\n                      color: scheme.onSurface,\n                    ),\n                  ),\n                  const SizedBox(height: 2),\n                  Text(\n                    'Baca Al-Qur’an dengan tenang',\n                    style: GoogleFonts.spaceGrotesk(\n                      fontSize: 12,\n                      fontWeight: FontWeight.w500,\n                      color: scheme.onSurface.withValues(alpha: 0.55),\n                    ),\n                  ),\n                ],\n              ),\n            ),\n            _roundAction(\n              context,\n              Icons.download_outlined,\n              'Kelola unduhan',\n              _openDownloadManager,\n            ),\n          ],\n        ),\n      ),\n    );\n  }\n\n'''
    updated = replace_method(text, 'Widget _buildTopBar(BuildContext context)', replacement.rstrip())
    if updated == text:
        raise RuntimeError('Could not normalize Surah list top bar')
    path.write_text(updated)
    print('Updated Surah list top bar')


def patch_murotal() -> None:
    path = ROOT / 'lib' / 'screens' / 'murotal_screen.dart'
    text = path.read_text()
    old = """                  backgroundColor: Colors.transparent,\n                  automaticallyImplyLeading: false,"""
    new = """                  backgroundColor: scheme.surface,\n                  surfaceTintColor: Colors.transparent,\n                  automaticallyImplyLeading: false,"""
    if old in text:
        text = text.replace(old, new, 1)
    path.write_text(text)
    print('Aligned Murotal top bar surface')


if __name__ == '__main__':
    patch_main_theme()
    patch_playlist()
    patch_settings()
    patch_surah_list()
    patch_murotal()
    print('Top navbar design unified across primary screens.')
