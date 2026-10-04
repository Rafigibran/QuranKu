from __future__ import annotations

import io
import zipfile
from pathlib import Path
from urllib.request import Request, urlopen

ROOT = Path(__file__).resolve().parents[1]
ASSET = ROOT / 'assets' / 'rain_loop.mp3'
SOURCE_URL = 'https://opengameart.org/sites/default/files/Rain%20MP3.zip'


def main() -> None:
    request = Request(
        SOURCE_URL,
        headers={'User-Agent': 'QuranKu-Build/1.0'},
    )
    with urlopen(request, timeout=45) as response:
        archive = response.read()

    with zipfile.ZipFile(io.BytesIO(archive)) as zf:
        mp3s = [name for name in zf.namelist() if name.lower().endswith('.mp3')]
        if not mp3s:
            raise RuntimeError('Rain MP3 archive does not contain an MP3 file')

        # Use the first loopable recording shipped in the CC0 package.
        selected = sorted(mp3s)[0]
        data = zf.read(selected)

    if len(data) < 50_000:
        raise RuntimeError(f'Rain asset is unexpectedly small: {len(data)} bytes')

    ASSET.write_bytes(data)
    print(f'Bundled rain ambience: {selected} -> {ASSET} ({len(data)} bytes)')


if __name__ == '__main__':
    main()
