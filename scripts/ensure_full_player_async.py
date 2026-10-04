from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PATH = ROOT / 'lib' / 'widgets' / 'full_player_view.dart'


def main() -> None:
    text = PATH.read_text(encoding='utf-8')
    if "import 'dart:async';" not in text:
        text = "import 'dart:async';\n" + text
        PATH.write_text(text, encoding='utf-8')
        print('Added dart:async import for background audio controls.')
    else:
        print('dart:async import already present.')


if __name__ == '__main__':
    main()
