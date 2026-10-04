from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]


def patch_file(path: str, transform):
    file = ROOT / path
    text = file.read_text(encoding="utf-8")
    new_text = transform(text)
    if new_text != text:
        file.write_text(new_text, encoding="utf-8")
        print(f"Patched {path}")
    else:
        print(f"No changes needed: {path}")


def patch_theme(text: str) -> str:
    replacements = {
        "final background = isDark ? const Color(0xFF0C1C1B) : const Color(0xFFFFFBEE);":
            "final background = isDark ? const Color(0xFF0B100F) : const Color(0xFFF6F7F5);",
        "final surface = isDark ? const Color(0xFF122625) : Colors.white;":
            "final surface = isDark ? const Color(0xFF151B19) : Colors.white;",
        "final onSurface = isDark ? Colors.white : const Color(0xFF19302E);":
            "final onSurface = isDark ? const Color(0xFFF5F7F6) : const Color(0xFF17201E);",
        "final muted = isDark ? const Color(0xFFAFC8C5) : const Color(0xFF6B7F7C);":
            "final muted = isDark ? const Color(0xFFA9B7B3) : const Color(0xFF66736F);",
        "final outline = isDark ? const Color(0xFF24413F) : const Color(0xFFE3E6DA);":
            "final outline = isDark ? const Color(0xFF293633) : const Color(0xFFE0E5E2);",
        "borderRadius: BorderRadius.circular(24),":
            "borderRadius: BorderRadius.circular(18),",
        "borderRadius: BorderRadius.circular(18),\n          borderSide: BorderSide(color: outline),":
            "borderRadius: BorderRadius.circular(14),\n          borderSide: BorderSide(color: outline),",
        "borderRadius: BorderRadius.circular(18),\n          borderSide: BorderSide(color: accent, width: 1.6),":
            "borderRadius: BorderRadius.circular(14),\n          borderSide: BorderSide(color: accent, width: 1.5),",
        "borderRadius: BorderRadius.circular(17),":
            "borderRadius: BorderRadius.circular(14),",
    }
    for old, new in replacements.items():
        text = text.replace(old, new)
    return text


def patch_main_navigation(text: str) -> str:
    start = text.find("  Widget _buildBottomNavigation(BuildContext context) {")
    end = text.find("  Widget _navItem(", start)
    if start == -1 or end == -1:
        return text

    replacement = '''  Widget _buildBottomNavigation(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return NavigationBar(
      height: 76,
      elevation: 0,
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      indicatorColor: scheme.primary.withValues(alpha: 0.12),
      selectedIndex: _selectedIndex,
      onDestinationSelected: _onItemTapped,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home_rounded),
          label: 'Beranda',
        ),
        NavigationDestination(
          icon: Icon(Icons.access_time_outlined),
          selectedIcon: Icon(Icons.access_time_filled_rounded),
          label: 'Waktu Sholat',
        ),
        NavigationDestination(
          icon: Icon(Icons.menu_book_outlined),
          selectedIcon: Icon(Icons.menu_book_rounded),
          label: 'Murotal',
        ),
        NavigationDestination(
          icon: Icon(Icons.queue_music_outlined),
          selectedIcon: Icon(Icons.queue_music_rounded),
          label: 'Playlist',
        ),
        NavigationDestination(
          icon: Icon(Icons.tune_outlined),
          selectedIcon: Icon(Icons.tune_rounded),
          label: 'Pengaturan',
        ),
      ],
    );
  }

'''
    return text[:start] + replacement + text[end:]


def patch_surah_home(text: str) -> str:
    hero_start = text.find("  Widget _buildHeroCard(BuildContext context) {")
    resume_start = text.find("  Widget _buildResumeCard(BuildContext context) {", hero_start)
    search_start = text.find("  Widget _buildSearch(BuildContext context) {", resume_start)
    if hero_start != -1 and resume_start != -1 and search_start != -1:
        hero = '''  Widget _buildHeroCard(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      padding: const EdgeInsets.fromLTRB(20, 18, 18, 18),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.8)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Baca Al-Qur’an bersama Kami',
                  style: GoogleFonts.spaceGrotesk(
                    color: scheme.onSurface,
                    fontSize: 24,
                    height: 1.08,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.7,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Pilih Surah dan lanjutkan tilawah kapan saja.',
                  style: GoogleFonts.spaceGrotesk(
                    color: scheme.onSurface.withValues(alpha: 0.62),
                    fontSize: 13,
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(
              Icons.menu_book_rounded,
              color: scheme.primary,
              size: 34,
            ),
          ),
        ],
      ),
    );
  }

'''
        resume = '''  Widget _buildResumeCard(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final surah = _lastReadSurahData;
    final ayah = _lastReadAyah;
    if (surah == null || ayah == null) return const SizedBox.shrink();

    final progress = surah.totalAyahs <= 0
        ? 0.0
        : (ayah / surah.totalAyahs).clamp(0.0, 1.0).toDouble();

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.8)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _openSurah(surah, ayah: ayah),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.bookmark_rounded, color: scheme.primary, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Lanjutkan membaca',
                        style: GoogleFonts.spaceGrotesk(
                          color: scheme.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Icon(Icons.arrow_forward_rounded, color: scheme.onSurface.withValues(alpha: .45), size: 20),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '${surah.name} · Ayat $ayah',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.spaceGrotesk(
                    color: scheme.onSurface,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 4,
                    backgroundColor: scheme.primary.withValues(alpha: 0.08),
                    valueColor: AlwaysStoppedAnimation<Color>(scheme.primary),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

'''
        text = text[:hero_start] + hero + resume + text[search_start:]

    # Keep the search field prominent but quieter than the old outlined pill.
    text = text.replace(
        "hintText: 'Cari Surah atau nomor...',",
        "hintText: 'Cari Surah atau nomor',",
    )
    return text


def patch_prayer_label(text: str) -> str:
    return text.replace("const Text('Bulanan')", "const Text('Imsakiyah')").replace(
        "const Text('Monthly')", "const Text('Imsakiyah')"
    )


def patch_api(text: str) -> str:
    text = text.replace("static const String _detailCacheVersion = 'v5';", "static const String _detailCacheVersion = 'v6';")
    text = text.replace("final String cacheKey = 'cache_surah_${surahNumber}_${edition}_v4';", "final String cacheKey = 'cache_surah_${surahNumber}_${edition}_v5';")

    start = text.find("  Future<List<Ayah>> fetchTranslation(")
    end = text.find("  Future<List<Ayah>> fetchSurahDetails(", start)
    if start == -1 or end == -1:
        return text

    replacement = r'''  Future<List<Ayah>> fetchTranslation(
    int surahNumber,
    List<Ayah> arabicAyahs, {
    String edition = 'id-indonesian',
  }) async {
    final String cacheKey = 'cache_surah_${surahNumber}_${edition}_v5';
    final prefs = await SharedPreferences.getInstance();

    if (prefs.containsKey(cacheKey)) {
      final String? cachedData = prefs.getString(cacheKey);
      if (cachedData != null) {
        try {
          final List<dynamic> data = json.decode(cachedData);
          return data
              .map(
                (item) => Ayah(
                  number: item['number'],
                  arabic: item['arabic'],
                  translation: item['translation'] ?? '',
                ),
              )
              .toList(growable: false);
        } catch (e) {
          debugPrint('Translation cache error: $e');
        }
      }
    }

    try {
      final translationResponse = await http.get(
        Uri.parse('$baseUrl/surah/$surahNumber/$edition'),
      );

      if (translationResponse.statusCode != 200) return arabicAyahs;

      final Map<String, dynamic> transBody = json.decode(translationResponse.body);
      final List<dynamic> transList = transBody['data']['ayahs'];

      final Map<int, String> byAyahNumber = <int, String>{};
      final List<String> sequentialTexts = <String>[];
      bool hasVerseNumbers = false;

      for (final item in transList) {
        if (item is! Map) continue;
        final rawNumber = item['numberInSurah'] ?? item['number'];
        int? verseNumber;
        if (rawNumber is num) {
          verseNumber = rawNumber.toInt();
        } else if (rawNumber != null) {
          verseNumber = int.tryParse(rawNumber.toString());
        }
        final value = item['text']?.toString() ?? '';
        if (verseNumber != null && verseNumber > 0) {
          byAyahNumber[verseNumber] = value;
          hasVerseNumbers = true;
        }
        if (verseNumber == null || verseNumber > 0) {
          sequentialTexts.add(value);
        }
      }

      final List<Ayah> mergedAyahs = <Ayah>[];
      for (int i = 0; i < arabicAyahs.length; i++) {
        final ayah = arabicAyahs[i];
        final fallback = i < sequentialTexts.length ? sequentialTexts[i] : '';
        final translation = hasVerseNumbers
            ? (byAyahNumber[ayah.number] ?? fallback)
            : fallback;
        mergedAyahs.add(
          Ayah(
            number: ayah.number,
            arabic: ayah.arabic,
            translation: translation,
          ),
        );
      }

      await prefs.setString(cacheKey, json.encode(_encodeAyahs(mergedAyahs)));
      return mergedAyahs;
    } catch (e) {
      debugPrint('Translation request failed: $e');
      return arabicAyahs;
    }
  }

'''
    return text[:start] + replacement + text[end:]


patch_file('lib/main.dart', patch_theme)
patch_file('lib/screens/main_screen.dart', patch_main_navigation)
patch_file('lib/screens/surah_list_screen.dart', patch_surah_home)
patch_file('lib/screens/prayer_times_screen.dart', patch_prayer_label)
patch_file('lib/services/api_service.dart', patch_api)
