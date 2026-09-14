import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/surah.dart';
import '../services/api_service.dart';
import '../services/settings_service.dart';
import '../widgets/liquid_glass.dart';
import 'surah_detail_screen.dart';
import 'download_screen.dart';

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

  @override
  void initState() {
    super.initState();
    _settings.addListener(_onSettingsUpdate);
    _surahListFuture = _loadSurahs();
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

  Future<void> _openDownloadManager() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.18),
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

  Future<void> _refresh() async {
    try {
      final surahs = await ApiService().fetchSurahs(forceRefresh: true);
      if (!mounted) return;
      setState(() {
        _allSurahs = surahs;
        _filteredSurahs = surahs;
        _searchController.clear();
      });
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
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        titleSpacing: 20,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'QuranKu',
              style: GoogleFonts.spaceGrotesk(
                color: scheme.onSurface,
                fontWeight: FontWeight.w800,
                fontSize: 25,
                letterSpacing: -0.8,
              ),
            ),
            Text(
              'Baca dengan tenang, kapan saja.',
              style: GoogleFonts.spaceGrotesk(
                color: scheme.onSurface.withValues(alpha: 0.58),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          LiquidGlassIconButton(
            icon: Icons.download_outlined,
            tooltip: 'Kelola unduhan',
            semanticLabel: 'Kelola unduhan Al-Quran',
            onPressed: _openDownloadManager,
          ),
          const SizedBox(width: 16),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(82),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
            child: TextField(
              controller: _searchController,
              onChanged: _filterSurahs,
              textInputAction: TextInputAction.search,
              style: GoogleFonts.spaceGrotesk(
                color: scheme.onSurface,
                fontSize: 16,
                height: 1.2,
              ),
              decoration: InputDecoration(
                hintText: 'Cari nama atau nomor Surah',
                prefixIcon: Icon(Icons.search_rounded, color: scheme.primary, size: 24),
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
          ),
        ),
      ),
      body: FutureBuilder<List<Surah>>(
        future: _surahListFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && _allSurahs.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: scheme.primary),
                  const SizedBox(height: 14),
                  Text('Memuat Al-Quran…', style: Theme.of(context).textTheme.bodyLarge),
                ],
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: LiquidGlassCard(
                margin: const EdgeInsets.all(24),
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.cloud_off_rounded, size: 46, color: scheme.primary),
                    const SizedBox(height: 14),
                    Text(
                      'Al-Quran belum dapat dimuat.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Periksa koneksi internet, lalu coba lagi.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 18),
                    ElevatedButton.icon(
                      onPressed: () => setState(() => _surahListFuture = _loadSurahs()),
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Coba Lagi'),
                    ),
                  ],
                ),
              ),
            );
          }

          if (_filteredSurahs.isEmpty) {
            return RefreshIndicator(
              color: scheme.primary,
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(24, 48, 24, 140),
                children: [
                  LiquidGlassCard(
                    padding: const EdgeInsets.all(26),
                    child: Column(
                      children: [
                        Icon(Icons.search_off_rounded, size: 52, color: scheme.primary),
                        const SizedBox(height: 14),
                        Text(
                          'Surah tidak ditemukan',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Coba gunakan nama atau nomor Surah yang lain.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }

          return LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 760;
              final crossAxisCount = constraints.maxWidth >= 1180
                  ? 3
                  : (wide ? 2 : 1);

              return RefreshIndicator(
                color: scheme.primary,
                onRefresh: _refresh,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
                        child: Row(
                          children: [
                            LiquidGlassPill(
                              child: Text(
                                '${_filteredSurahs.length} Surah',
                                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: scheme.primary,
                                    ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Pilih Surah untuk mulai membaca',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: scheme.onSurface.withValues(alpha: 0.58),
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 130),
                      sliver: crossAxisCount == 1
                          ? SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (context, index) => Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: _buildSurahCard(_filteredSurahs[index]),
                                ),
                                childCount: _filteredSurahs.length,
                              ),
                            )
                          : SliverGrid(
                              delegate: SliverChildBuilderDelegate(
                                (context, index) => _buildSurahCard(_filteredSurahs[index]),
                                childCount: _filteredSurahs.length,
                              ),
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: crossAxisCount,
                                crossAxisSpacing: 14,
                                mainAxisSpacing: 14,
                                childAspectRatio: 1.8,
                              ),
                            ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildSurahCard(Surah surah) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return LiquidGlassCard(
      radius: 24,
      padding: const EdgeInsets.all(18),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => SurahDetailScreen(surah: surah)),
        );
      },
      child: Semantics(
        button: true,
        label: '${surah.name}, ${surah.totalAyahs} ayat, ${surah.type}',
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    scheme.primary.withValues(alpha: 0.18),
                    scheme.primary.withValues(alpha: 0.07),
                  ],
                ),
                border: Border.all(
                  color: scheme.primary.withValues(alpha: 0.22),
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                _settings.formatNumber(surah.number),
                style: GoogleFonts.spaceGrotesk(
                  color: scheme.primary,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    surah.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.spaceGrotesk(
                      color: scheme.onSurface,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${_settings.formatNumber(surah.totalAyahs)} Ayat • ${surah.type}',
                    style: GoogleFonts.spaceGrotesk(
                      color: scheme.onSurface.withValues(alpha: 0.56),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  surah.nameAr,
                  textAlign: TextAlign.right,
                  style: GoogleFonts.amiri(
                    color: isDark ? Colors.white.withValues(alpha: 0.86) : const Color(0xFF23322B),
                    fontSize: 25,
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: 8),
                Icon(
                  Icons.chevron_right_rounded,
                  color: scheme.onSurface.withValues(alpha: 0.40),
                  size: 22,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
