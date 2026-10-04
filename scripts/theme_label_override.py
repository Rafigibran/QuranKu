from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PATH = ROOT / 'lib' / 'screens' / 'settings_screen.dart'


def main() -> None:
    text = PATH.read_text(encoding='utf-8')
    text = text.replace("subtitle: _settings.themeMode == ThemeMode.light ? 'Ivory' : 'Eigengrau',", "subtitle: _settings.themeMode == ThemeMode.light ? 'Terang' : 'Gelap',")
    text = text.replace("title: const Text('Ivory')", "title: const Text('Terang')")
    text = text.replace("title: const Text('Eigengrau')", "title: const Text('Gelap')")
    PATH.write_text(text, encoding='utf-8')
    print('Theme labels normalized to Terang / Gelap.')


if __name__ == '__main__':
    main()
