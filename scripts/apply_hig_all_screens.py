from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
SCREENS = ROOT / 'lib' / 'screens'


def patch_file(path: Path, transform) -> None:
    text = path.read_text(encoding='utf-8')
    original = text

    # Keep screen content on the app background instead of transparent
    # scaffolds that can create inconsistent layering between pages.
    text = re.sub(
        r"(Scaffold\(\s*)backgroundColor:\s*Colors\.transparent,",
        r"\1backgroundColor: Theme.of(context).scaffoldBackgroundColor,",
        text,
    )

    # Avoid square/industrial-looking controls. Use the shared visual rhythm
    # already established by the Material 3 theme.
    text = text.replace('BorderRadius.circular(0)', 'BorderRadius.circular(16)')

    # Consistent Indonesian microcopy for screens that still contain English UI.
    replacements = {
        "'MANAGE STORAGE'": "'Penyimpanan'",
        "'Manage Storage'": "'Penyimpanan'",
        "'QURAN DOWNLOADS'": "'Unduhan Al-Qur’an'",
        "'PAUSED'": "'DIJEDA'",
        "'DOWNLOADING'": "'MENGUNDUH'",
        "'Download translations and tafsir for offline reading.'": "'Unduh terjemahan dan tafsir untuk membaca tanpa koneksi internet.'",
        "'Select edition to add'": "'Pilih terjemahan yang ingin disimpan'",
        "'Pause'": "'Jeda'",
        "'Resume'": "'Lanjutkan'",
        "'Stop'": "'Berhenti'",
        "'No audio files downloaded'": "'Belum ada audio yang diunduh'",
        "'Total Audio Storage'": "'Total penyimpanan audio'",
        "'Total Data Storage'": "'Total penyimpanan data'",
        "'No data available'": "'Belum ada data tersimpan'",
        "'Delete Audio?'": "'Hapus audio?'",
        "'Delete Data?'": "'Hapus data?'",
        "'Delete Translation?'": "'Hapus terjemahan?'",
        "'Delete'": "'Hapus'",
        "'Cancel'": "'Batal'",
    }
    for old, new in replacements.items():
        text = text.replace(old, new)

    if text != original:
        path.write_text(text, encoding='utf-8')
        print(f'Patched {path.relative_to(ROOT)}')


for dart_file in sorted(SCREENS.glob('*.dart')):
    patch_file(dart_file, lambda text: text)

# Flutter exposes FontWeight constants at fixed increments. The previous
# HIG theme introduced w650, which does not exist and stops dart analyze.
main_file = ROOT / 'lib' / 'main.dart'
patch_file(
    main_file,
    lambda text: text.replace('FontWeight.w650', 'FontWeight.w600'),
)
