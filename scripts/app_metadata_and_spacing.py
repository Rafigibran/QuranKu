from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]


def read_app_version() -> str:
    pubspec = (ROOT / 'pubspec.yaml').read_text(encoding='utf-8')
    match = re.search(r'^version:\s*([^+\s]+)', pubspec, re.MULTILINE)
    if not match:
        raise RuntimeError('Could not determine the application version from pubspec.yaml')
    return match.group(1)


def patch_about(version: str) -> None:
    path = ROOT / 'lib' / 'screens' / 'about_screen.dart'
    text = path.read_text(encoding='utf-8')
    updated, count = re.subn(
        r'final String _appVersion\s*=\s*"[^"]*";',
        f'final String _appVersion = "{version}";',
        text,
        count=1,
    )
    if count != 1:
        raise RuntimeError('AboutScreen _appVersion declaration not found')
    if updated != text:
        path.write_text(updated, encoding='utf-8')
        print(f'About menu version set to v{version}.')


def patch_search_spacing() -> None:
    path = ROOT / 'lib' / 'screens' / 'surah_list_screen.dart'
    text = path.read_text(encoding='utf-8')
    start = text.find('  Widget _buildSearch(BuildContext context) {')
    if start == -1:
        raise RuntimeError('Surah search builder not found')
    end = text.find('\n  Widget _buildSectionHeader(', start)
    if end == -1:
        raise RuntimeError('Surah section header boundary not found')

    method = text[start:end]
    updated = method.replace(
        'padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),',
        'padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),',
        1,
    )
    if updated == method:
        if 'padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),' in method:
            print('Surah search spacing already balanced.')
            return
        raise RuntimeError('Surah search padding declaration not found')

    path.write_text(text[:start] + updated + text[end:], encoding='utf-8')
    print('Added 14px breathing room above the Surah search field.')


def main() -> None:
    version = read_app_version()
    patch_about(version)
    patch_search_spacing()


if __name__ == '__main__':
    main()
