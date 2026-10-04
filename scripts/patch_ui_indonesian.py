from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def patch_file(path: str, transform):
    file = ROOT / path
    text = file.read_text(encoding='utf-8')
    new_text = transform(text)
    if new_text != text:
        file.write_text(new_text, encoding='utf-8')
        print(f'Patched {path}')
    else:
        print(f'No changes needed: {path}')


def localize_surah_list(text: str) -> str:
    replacements = {
        'Mulai membaca\\ndengan tenang': 'Baca Al-Qur’an\\nbersama Kami',
        'Pilih Surah dan lanjutkan tilawah kapan saja.': 'Pilih Surah dan lanjutkan tilawah bersama kami.',
    }
    for old, new in replacements.items():
        text = text.replace(old, new)
    return text


def localize_main_screen(text: str) -> str:
    return text.replace(
        "_navItem(context, 1, Icons.access_time_filled_rounded, 'Jadwal')",
        "_navItem(context, 1, Icons.access_time_filled_rounded, 'Waktu Sholat')",
    )


def localize_prayer_times(text: str) -> str:
    replacements = {
        "TIME.": "Waktu Sholat",
        "Prayer times made simple.": "Jadwal sholat, sederhana dan mudah.",
        "Change location": "Ubah lokasi",
        "Failed to load location data.": "Gagal memuat data lokasi.",
        "Choose location": "Pilih lokasi",
        "Prayer times will be refreshed for your selected city.": "Waktu sholat akan diperbarui untuk kota yang dipilih.",
        "Province": "Provinsi",
        "City / Regency": "Kota / Kabupaten",
        "Use this location": "Gunakan lokasi ini",
        "No schedule found for this date.": "Jadwal tidak ditemukan untuk tanggal ini.",
        "Failed to fetch data. Please check your connection.": "Gagal memuat data. Periksa koneksi internet Anda.",
        "Next prayer": "Waktu sholat berikutnya",
        "Select location": "Pilih lokasi",
        "NEXT PRAYER": "WAKTU SHOLAT BERIKUTNYA",
        "Location": "Lokasi",
        "PRAYER TIMES": "WAKTU SHOLAT",
        "Today’s schedule": "Jadwal hari ini",
        "Monthly": "Bulanan",
        "Prayer time": "Waktu sholat",
        "NEXT": "BERIKUTNYA",
        "Prayer times unavailable": "Waktu sholat tidak tersedia",
        "Something went wrong.": "Terjadi kesalahan.",
        "Try again": "Coba lagi",
    }
    for old, new in replacements.items():
        text = text.replace(old, new)

    for old, new in (
        ("MapEntry('Fajr', prayer.subuh)", "MapEntry('Subuh', prayer.subuh)"),
        ("MapEntry('Dhuhr', prayer.dzuhur)", "MapEntry('Dzuhur', prayer.dzuhur)"),
        ("MapEntry('Asr', prayer.ashar)", "MapEntry('Ashar', prayer.ashar)"),
        ("MapEntry('Isha', prayer.isya)", "MapEntry('Isya', prayer.isya)"),
        ("      'Fajr': Icons.wb_twilight_rounded,", "      'Subuh': Icons.wb_twilight_rounded,"),
        ("      'Dhuhr': Icons.light_mode_outlined,", "      'Dzuhur': Icons.light_mode_outlined,"),
        ("      'Asr': Icons.sunny_snowing,", "      'Ashar': Icons.sunny_snowing,"),
        ("      'Isha': Icons.nightlight_round,", "      'Isya': Icons.nightlight_round,"),
    ):
        text = text.replace(old, new)

    old_weekday = "Text(\n                DateFormat('EEEE').format(_selectedDate),"
    text = text.replace(old_weekday, "Text(\n                _weekdayName(),")

    old_short_date = "label: _settings.formatString(DateFormat('d MMM').format(_selectedDate)),"
    text = text.replace(old_short_date, "label: _formatShortDate(),")

    old_format_date = '''  String _formatDate(BuildContext context) {
    final day = _settings.formatString(DateFormat('d').format(_selectedDate));
    final monthYear = _settings.formatString(
      DateFormat('MMMM yyyy').format(_selectedDate),
    );
    return '$day $monthYear';
  }'''
    new_format_date = '''  String _weekdayName() {
    const names = <String>[
      'Senin',
      'Selasa',
      'Rabu',
      'Kamis',
      'Jumat',
      'Sabtu',
      'Minggu',
    ];
    return names[_selectedDate.weekday - 1];
  }

  String _formatShortDate() {
    const months = <String>[
      'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
    ];
    return _settings.formatString(
      '${_selectedDate.day} ${months[_selectedDate.month - 1]}',
    );
  }

  String _formatDate(BuildContext context) {
    const months = <String>[
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
    ];
    return _settings.formatString(
      '${_selectedDate.day} ${months[_selectedDate.month - 1]} ${_selectedDate.year}',
    );
  }'''
    if old_format_date in text:
        text = text.replace(old_format_date, new_format_date)

    return text


def patch_audio(text: str) -> str:
    text = text.replace(
        "if (newAyah >= 0 && _currentAyah != newAyah)",
        "if (newAyah > 0 && _currentAyah != newAyah)",
    )
    marker = "  Future<void> playAyah(Surah surah, int ayahNumber) async {\n"
    if marker in text and "await init();\n    final int opId" not in text:
        text = text.replace(marker, marker + "    await init();\n", 1)
    marker2 = "  Future<void> _loadAndPlaySurah(int number) async {\n"
    section = text[text.index(marker2):] if marker2 in text else ''
    if marker2 in text and "  Future<void> _loadAndPlaySurah(int number) async {\n    await init();\n" not in section:
        text = text.replace(marker2, marker2 + "    await init();\n", 1)
    return text


def patch_main(text: str) -> str:
    if "import 'services/audio_service.dart';" not in text:
        text = text.replace(
            "import 'services/settings_service.dart';",
            "import 'services/settings_service.dart';\nimport 'services/audio_service.dart';",
        )
    needle = "  await SettingsService().init();\n"
    if needle in text and "await AudioService().init();" not in text:
        text = text.replace(needle, needle + "  await AudioService().init();\n", 1)
    return text


def patch_full_player(text: str) -> str:
    if "import '../models/surah.dart';" not in text:
        text = text.replace(
            "import '../models/ayah.dart';",
            "import '../models/ayah.dart';\nimport '../models/surah.dart';",
        )

    start = text.find("  Future<void> _openCurrentAyah() async {")
    end = text.find("  String _repeatLabel() {", start)
    if start != -1 and end != -1:
        replacement = '''  Future<void> _openCurrentAyah() async {
    final surah = _audio.currentSurah;
    if (surah == null) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _CurrentAyahSheet(
        surah: surah,
        audio: _audio,
        api: _api,
        initialEdition: _settings.defaultTranslation,
      ),
    );
  }

'''
        text = text[:start] + replacement + text[end:]

    if "class _CurrentAyahSheet extends StatefulWidget" not in text:
        marker = "class _PlayerBackdrop extends StatelessWidget {"
        sheet = r'''class _CurrentAyahSheet extends StatefulWidget {
  const _CurrentAyahSheet({
    required this.surah,
    required this.audio,
    required this.api,
    required this.initialEdition,
  });

  final Surah surah;
  final as_audio.AudioService audio;
  final ApiService api;
  final String initialEdition;

  @override
  State<_CurrentAyahSheet> createState() => _CurrentAyahSheetState();
}

class _CurrentAyahSheetState extends State<_CurrentAyahSheet> {
  final SettingsService _settings = SettingsService();
  List<Ayah> _ayahs = const <Ayah>[];
  int? _loadedSurahNumber;
  String? _loadedEdition;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    widget.audio.addListener(_refresh);
    _settings.addListener(_refresh);
    _load(force: true);
  }

  @override
  void dispose() {
    widget.audio.removeListener(_refresh);
    _settings.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (!mounted) return;
    final currentSurah = widget.audio.currentSurah ?? widget.surah;
    final edition = _settings.defaultTranslation;
    if (_loadedSurahNumber != currentSurah.number || _loadedEdition != edition) {
      _load(force: true);
    }
    setState(() {});
  }

  Future<void> _load({bool force = false}) async {
    final currentSurah = widget.audio.currentSurah ?? widget.surah;
    final edition = _settings.defaultTranslation;
    if (!force && _loadedSurahNumber == currentSurah.number && _loadedEdition == edition) {
      return;
    }

    final cached = ApiService.getCachedSurahDetails(
      currentSurah.number,
      edition: edition,
    );
    if (cached != null && cached.isNotEmpty) {
      if (!mounted) return;
      setState(() {
        _ayahs = cached;
        _loadedSurahNumber = currentSurah.number;
        _loadedEdition = edition;
        _loading = false;
        _error = null;
      });
      return;
    }

    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final data = await widget.api.fetchSurahDetails(
        currentSurah.number,
        edition: edition,
      );
      if (!mounted) return;
      setState(() {
        _ayahs = data;
        _loadedSurahNumber = currentSurah.number;
        _loadedEdition = edition;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Ayat belum tersedia.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final currentSurah = widget.audio.currentSurah ?? widget.surah;
    final currentNumber = widget.audio.currentAyah;

    Ayah? currentAyah;
    for (final ayah in _ayahs) {
      if (ayah.number == currentNumber) {
        currentAyah = ayah;
        break;
      }
    }

    return _GlassSheet(
      title: '${currentSurah.name} • Ayat ${_settings.formatNumber(currentNumber)}',
      child: _loading && _ayahs.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(30),
                child: CircularProgressIndicator(color: scheme.primary),
              ),
            )
          : currentAyah == null
              ? Text(_error ?? 'Ayat belum tersedia.')
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      currentAyah.arabic,
                      textAlign: TextAlign.right,
                      style: GoogleFonts.amiri(
                        fontSize: 27,
                        height: 2.0,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      currentAyah.translation,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            height: 1.55,
                            color: scheme.onSurface.withValues(alpha: .72),
                          ),
                    ),
                  ],
                ),
    );
  }
}

'''
        text = text.replace(marker, sheet + marker, 1)

    return text


patch_file('lib/screens/surah_list_screen.dart', localize_surah_list)
patch_file('lib/screens/main_screen.dart', localize_main_screen)
patch_file('lib/screens/prayer_times_screen.dart', localize_prayer_times)
patch_file('lib/services/audio_service.dart', patch_audio)
patch_file('lib/main.dart', patch_main)
patch_file('lib/widgets/full_player_view.dart', patch_full_player)
