import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'ayah_search_screen.dart';
import 'bookmark_screen.dart';
import 'juz_screen.dart';
import 'hijri_screen.dart';
import 'qibla_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/surah.dart';
import '../services/api_service.dart';
import '../services/settings_service.dart';
import 'download_screen.dart';
import 'surah_detail_screen.dart';

class SurahListScreen extends StatefulWidget {
  const SurahListScreen({super.key});

  @override
  State<SurahListScreen> createState() => _SurahListScreenState();
}

class _SurahListScreenState extends State<SurahListScreen> {
  late Future<List<Surah>> _surahListFuture;
  List<Surah> _allSurahs = <Surah>[];
  List<Surah> _filteredSurahs = <Surah>[];
  final TextEditingController _searchController = TextEditingController();
  final SettingsService _settings = SettingsService();

  int? _lastReadSurah;
  int? _lastReadAyah;

  @override
  void initState() {
    super.initState();
    _settings.addListener(_onSettingsUpdate);
    _surahListFuture = _loadSurahs();
    _loadLastReading();
  }

  Future<List<Surah>> _loadSurahs() async {
    final surahs = await ApiService().fetchSurahs();
    if (!mounted) return surahs;
    setState(() {
      _allSurahs = surahs;
      _filteredSurahs = surahs;
    });
    return surahs;
  }

  Future<void> _loadLastReading() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _lastReadSurah = prefs.getInt('last_reading_surah');
      _lastReadAyah = prefs.getInt('last_reading_ayah');
    });
  }

  @override
  void dispose() {
    _settings.removeListener(_onSettingsUpdate);
    _searchController.dispose();
    super.dispose();
  }

  void _onSettingsUpdate() {
    if (mounted) setState(() {});
  }

  void _filterSurahs(String query) {
    final normalized = query.trim().toLowerCase();
    setState(() {
      if (normalized.isEmpty) {
        _filteredSurahs = _allSurahs;
        return;
      }
      _filteredSurahs = _allSurahs.where((surah) {
        return surah.name.toLowerCase().contains(normalized) ||
            surah.nameAr.contains(query.trim()) ||
            surah.number.toString() == query.trim();
      }).toList();
    });
  }

  Surah? get _lastReadSurahData {
    if (_lastReadSurah == null || _allSurahs.isEmpty) return null;
    for (final surah in _allSurahs) {
      if (surah.number == _lastReadSurah) return surah;
    }
    return null;
  }

  Future<void> _openDownloadManager() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.22),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.72,
        minChildSize: 0.50,
        maxChildSize: 0.94,
        expand: false,
        builder: (context, scrollController) => DownloadScreen(
          scrollController: scrollController,
        ),
      ),
    );
  }

  Future<void> _openSurah(Surah surah, {int? ayah}) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SurahDetailScreen(
          surah: surah,
          initialAyah: ayah,
        ),
      ),
    );
    await _loadLastReading();
  }

  Future<void> _refresh() async {
    try {
      final surahs = await ApiService().fetchSurahs(forceRefresh: true);
      if (!mounted) return;
      setState(() {
        _allSurahs = surahs;
        _filteredSurahs = surahs;
        _searchController.clear();
      });
      await _loadLastReading();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memuat ulang: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: scheme.primary,
          onRefresh: _refresh,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _buildTopBar(context)),
              SliverToBoxAdapter(child: _buildResumeCard(context)),
              SliverToBoxAdapter(child: _buildSearch(context)),
              SliverToBoxAdapter(child: _buildSectionHeader(context)),
              _buildSurahSliver(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Container(
      width: double.infinity,
      color: const Color(0xFF25364B),
      padding: const EdgeInsets.fromLTRB(20, 12, 14, 12),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Al-Qur’an',
                    style: GoogleFonts.spaceGrotesk(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Baca Al-Qur’an dengan nyaman',
                    style: GoogleFonts.spaceGrotesk(
                      color: Colors.white.withValues(alpha: .68),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _roundAction(
                  context,
                  Icons.manage_search_rounded,
                  'Cari ayat',
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AyahSearchScreen()),
                  ),
                ),
                const SizedBox(width: 7),
                _roundAction(
                  context,
                  Icons.bookmarks_outlined,
                  'Bookmark & riwayat',
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const BookmarkScreen()),
                  ),
                ),
                const SizedBox(width: 7),
                _roundAction(
                  context,
                  Icons.download_outlined,
                  'Kelola unduhan',
                  _openDownloadManager,
                ),
                const SizedBox(width: 4),
                PopupMenuButton<String>(
                  tooltip: 'Alat QuranKu',
                  onSelected: (value) {
                    final pages = <String, Widget>{
                      'juz': const JuzScreen(),
                      'hijri': const HijriScreen(),
                      'qibla': const QiblaScreen(),
                    };
                    final page = pages[value];
                    if (page != null) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => page),
                      );
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'juz', child: Text('Daftar Juz')),
                    PopupMenuItem(value: 'hijri', child: Text('Kalender Hijriah')),
                    PopupMenuItem(value: 'qibla', child: Text('Arah kiblat')),
                  ],
                  icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _roundAction(
    BuildContext context,
    IconData icon,
    String tooltip,
    VoidCallback onTap,
  ) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(17),
        onTap: onTap,
        child: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(17),
            border: Border.all(color: scheme.outline.withValues(alpha: 0.72)),
          ),
          child: Icon(icon, color: scheme.onSurface, size: 21),
        ),
      ),
    );
  }

  Widget _buildResumeCard(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final surah = _lastReadSurahData;
    final ayah = _lastReadAyah;
    if (surah == null || ayah == null) return const SizedBox.shrink();

    final progress = surah.totalAyahs <= 0
        ? 0.0
        : (ayah / surah.totalAyahs).clamp(0.0, 1.0).toDouble();

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 2, 20, 15),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(23),
          onTap: () => _openSurah(surah, ayah: ayah),
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 15, 15, 14),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(23),
              border: Border.all(color: scheme.primary.withValues(alpha: 0.24)),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(Icons.bookmark_rounded, color: scheme.primary, size: 23),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Lanjutkan membaca',
                        style: GoogleFonts.spaceGrotesk(
                          color: scheme.primary,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${surah.name} • Ayat $ayah',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.spaceGrotesk(
                          color: scheme.onSurface,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 5,
                          backgroundColor: scheme.primary.withValues(alpha: 0.10),
                          valueColor: AlwaysStoppedAnimation<Color>(scheme.primary),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Icon(Icons.arrow_forward_rounded, color: scheme.primary),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearch(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: TextField(
        controller: _searchController,
        onChanged: _filterSurahs,
        textInputAction: TextInputAction.search,
        style: GoogleFonts.spaceGrotesk(
          color: scheme.onSurface,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          hintText: 'Cari Surah atau nomor...',
          prefixIcon: Icon(Icons.search_rounded, color: scheme.primary, size: 23),
          suffixIcon: _searchController.text.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Bersihkan pencarian',
                  onPressed: () {
                    _searchController.clear();
                    _filterSurahs('');
                  },
                  icon: const Icon(Icons.close_rounded),
                ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 9),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Daftar Surah',
              style: GoogleFonts.spaceGrotesk(
                color: scheme.onSurface,
                fontSize: 19,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
              ),
            ),
          ),
          Text(
            '${_filteredSurahs.length} Surah',
            style: GoogleFonts.spaceGrotesk(
              color: scheme.primary,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSurahSliver(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return FutureBuilder<List<Surah>>(
      future: _surahListFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && _allSurahs.isEmpty) {
          return SliverFillRemaining(
            hasScrollBody: false,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: scheme.primary),
                const SizedBox(height: 14),
                Text(
                  'Memuat Al-Qur’an…',
                  style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          );
        }

        if (snapshot.hasError) {
          return SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Container(
                margin: const EdgeInsets.all(20),
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: scheme.outline),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.cloud_off_rounded, size: 44, color: scheme.primary),
                    const SizedBox(height: 12),
                    Text(
                      'Al-Qur’an belum dapat dimuat.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Periksa koneksi internet lalu coba lagi.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.spaceGrotesk(
                        color: scheme.onSurface.withValues(alpha: 0.62),
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () => setState(() => _surahListFuture = _loadSurahs()),
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Coba Lagi'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        if (_filteredSurahs.isEmpty) {
          return SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.fromLTRB(20, 8, 20, 120),
              padding: const EdgeInsets.all(26),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: scheme.outline),
              ),
              child: Column(
                children: [
                  Icon(Icons.search_off_rounded, size: 48, color: scheme.primary),
                  const SizedBox(height: 12),
                  Text(
                    'Surah tidak ditemukan',
                    style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Coba gunakan nama atau nomor Surah lainnya.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.spaceGrotesk(
                      color: scheme.onSurface.withValues(alpha: 0.60),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 128),
          sliver: SliverLayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.crossAxisExtent;
              final columns = width >= 900 ? 3 : (width >= 620 ? 2 : 1);

              if (columns == 1) {
                return SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => Padding(
                      padding: const EdgeInsets.only(bottom: 11),
                      child: _buildSurahCard(_filteredSurahs[index]),
                    ),
                    childCount: _filteredSurahs.length,
                  ),
                );
              }

              return SliverGrid(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _buildSurahCard(_filteredSurahs[index]),
                  childCount: _filteredSurahs.length,
                ),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  childAspectRatio: 1.95,
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildSurahCard(Surah surah) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isLastRead = _lastReadSurah == surah.number;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openSurah(surah),
        child: Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isLastRead
                  ? scheme.primary.withValues(alpha: .40)
                  : scheme.outline.withValues(alpha: .75),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? .12 : .05),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: scheme.surface,
                  border: Border.all(
                    color: scheme.primary.withValues(alpha: .38),
                    width: 1.5,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  _settings.formatNumber(surah.number),
                  style: GoogleFonts.ebGaramond(
                    color: scheme.primary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      surah.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.ebGaramond(
                        color: scheme.onSurface,
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_settings.formatNumber(surah.totalAyahs)} Ayat • ${surah.type}',
                      style: GoogleFonts.ebGaramond(
                        color: scheme.onSurfaceVariant,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                surah.nameAr,
                textAlign: TextAlign.right,
                style: GoogleFonts.amiri(
                  color: scheme.onSurface,
                  fontSize: 24,
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                color: scheme.onSurfaceVariant,
                size: 23,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
