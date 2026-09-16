from pathlib import Path
import base64

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / 'assets'
ASSETS.mkdir(parents=True, exist_ok=True)

RAIN_MP3_B64 = '''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'''

rain_path = ASSETS / 'rain_loop.mp3'
if not rain_path.exists() or rain_path.stat().st_size < 1000:
    try:
        # Handle potential missing padding in embedded base64
        b64 = RAIN_MP3_B64.strip()
        b64 += "=" * (-len(b64) % 4)
        rain_path.write_bytes(base64.b64decode(b64))
    except Exception as e:
        print(f"Base64 rain asset decode failed ({e}), trying ffmpeg fallback...")
        import subprocess, shutil
        if shutil.which("ffmpeg"):
            subprocess.run([
                "ffmpeg", "-hide_banner", "-loglevel", "error", "-y",
                "-f", "lavfi", "-i", "anoisesrc=color=pink:duration=30:amplitude=0.18",
                "-af", "highpass=f=120,lowpass=f=8000,volume=0.65",
                "-c:a", "libmp3lame", "-b:a", "96k", str(rain_path)
            ], check=False)
        if not rain_path.exists() or rain_path.stat().st_size < 1000:
            print("Warning: rain_loop.mp3 not generated; background audio will be disabled at runtime")

pubspec = ROOT / 'pubspec.yaml'
text = pubspec.read_text(encoding='utf-8')
if '    - assets/rain_loop.mp3' not in text:
    marker = '    - assets/splash.png\n'
    if marker not in text:
        raise SystemExit('Could not find Flutter asset list marker in pubspec.yaml')
    text = text.replace(marker, marker + '    - assets/rain_loop.mp3\n', 1)
    pubspec.write_text(text, encoding='utf-8')

# Add main-player volume control without rewriting the large audio service file.
audio = ROOT / 'lib/services/audio_service.dart'
a = audio.read_text(encoding='utf-8')
if 'double _volume = 1.0;' not in a:
    a = a.replace('  bool _isBuffering = false;\n', '  bool _isBuffering = false;\n  double _volume = 1.0;\n', 1)
if 'double get volume => _volume;' not in a:
    a = a.replace('  bool get isBuffering => _isBuffering;\n', '  bool get isBuffering => _isBuffering;\n  double get volume => _volume;\n', 1)
if 'await _player.setVolume(_volume);' not in a:
    a = a.replace("    await Directory(_localPath!).create(recursive: true);\n", "    await Directory(_localPath!).create(recursive: true);\n    await _player.setVolume(_volume);\n", 1)
if 'Future<void> setVolume(double value)' not in a:
    marker = '  Future<void> pause() async {\n'
    method = "  Future<void> setVolume(double value) async {\n    _volume = value.clamp(0.0, 1.0);\n    await _player.setVolume(_volume);\n    notifyListeners();\n  }\n\n"
    if marker not in a:
        raise SystemExit('Could not find pause() marker in audio_service.dart')
    a = a.replace(marker, method + marker, 1)
audio.write_text(a, encoding='utf-8')

print('Background audio patch applied.')
