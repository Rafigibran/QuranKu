from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
path = ROOT / 'lib' / 'screens' / 'surah_list_screen.dart'
text = path.read_text(encoding='utf-8')

start = text.find('Widget _buildResumeCard(BuildContext context)')
if start < 0:
    raise SystemExit('Resume card method not found; aborting to avoid an unsafe patch.')

end = text.find('\n  Widget ', start + 10)
if end < 0:
    end = len(text)

segment = text[start:end]
match = re.search(
    r'margin:\s*const\s+EdgeInsets\.fromLTRB\(20,\s*([0-9.]+),\s*20,\s*([0-9.]+)\),',
    segment,
)
if not match:
    raise SystemExit('Resume card margin not found; aborting to avoid an unsafe patch.')

replacement = 'margin: const EdgeInsets.fromLTRB(20, 15, 20, 15),'
segment = segment[:match.start()] + replacement + segment[match.end():]
path.write_text(text[:start] + segment + text[end:], encoding='utf-8')
print('Updated Lanjutkan membaca spacing: top=15, bottom=15.')
