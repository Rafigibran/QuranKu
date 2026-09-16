import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/juz.dart';
import '../models/surah.dart';
import '../services/api_service.dart';
import '../services/quran_search_service.dart';
import '../services/equran_service.dart';
import '../services/settings_service.dart';
import '../widgets/liquid_glass.dart';
import '../widgets/feature_grid.dart';
import '../services/khatam_service.dart';
import '../l10n/app_localizations.dart';
import '../l10n/l10n.dart';
import 'bookmarks_screen.dart';
import 'surah_detail_screen.dart';
import 'download_screen.dart';
import 'settings_screen.dart';
import 'khatam_screen.dart';

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
  final KhatamService _khatam = KhatamService();
  bool _showJuz = false;

  /// Expanded Juz card (single) + scroll keys for the quick-jump strip.
  int? _expandedJuz;
  final Map<int, GlobalKey> _juzKeys = {
    for (var j = 1; j <= 30; j++) j: GlobalKey(),
  };

  final GlobalKey _quranIndexAnchor = GlobalKey();

  Map<int, int> get _juzTotals => {
    for (final s in _allSurahs) s.number: s.totalAyahs,
  };

  /// Juz posisi terakhir dibaca (null bila belum ada).
  int? get _currentJuz {
    final lastSurah = _settings.lastSurah;
    if (lastSurah == null) return null;
    return JuzInfo.juzOf(lastSurah, _settings.lastAyah ?? 1);
  }

  /// Single unified search: local exact matches render instantly, AI
  /// semantic results follow underneath when the query looks like a
  /// meaning question (see [QuranSearchService.shouldUseAi]).
  Timer? _searchDebounce;
  int _searchGen = 0;
  List<SearchHit> _ayatHits = [];
  bool _ayatSearching = false;
  List<VectorHit> _vectorHits = [];
  bool _aiWanted = false;
  bool _aiLoading = false;
  bool _aiOffline = false;
  List<String> _recentSearches = [];

  int _cachedSurahCount = 0;

  @override
  void initState() {
    super.initState();
    _settings.addListener(_onSettingsUpdate);
    _khatam.addListener(_onSettingsUpdate);
    _khatam.init();
    _surahListFuture = _loadSurahs();
    _loadOfflineStatus();
    _loadRecentSearches();
  }

  Future<void> _loadOfflineStatus() async {
    try {
      final details = await _settings.getSurahStorageDetails();
      if (!mounted) return;
      setState(() => _cachedSurahCount = details.length);
    } catch (_) {}
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
    _khatam.removeListener(_onSettingsUpdate);
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSettingsUpdate() {
    if (mounted) setState(() {});
  }

  /// Single search entry: local first (jump + titles + cached full-text),
  /// AI semantic follow-up when the query looks like a meaning question.
  void _onSearchChanged(String query) {
    _searchDebounce?.cancel();
    final q = query.trim();
    if (q.isEmpty) {
      setState(() {
        _ayatHits = [];
        _vectorHits = [];
        _ayatSearching = false;
        _aiWanted = false;
        _aiLoading = false;
        _aiOffline = false;
      });
      return;
    }
    setState(() {
      _ayatSearching = true;
      _aiLoading = false;
      _aiOffline = false;
      _vectorHits = [];
    });
    _searchDebounce = Timer(
      const Duration(milliseconds: 280),
      () => _runUnifiedSearch(q, ++_searchGen),
    );
  }

  Future<void> _runUnifiedSearch(String q, int gen) async {
    final hits = await QuranSearchService.search(
      allSurahs: _allSurahs,
      raw: q,
    );
    if (!mounted || gen != _searchGen) return;
    final wantAi = QuranSearchService.shouldUseAi(
      q,
      localHitCount: hits.length,
    );
    setState(() {
      _ayatHits = hits;
      _ayatSearching = false;
      _aiWanted = wantAi;
      _aiLoading = wantAi;
      _aiOffline = false;
    });
    if (hits.isNotEmpty) {
      _recentSearches = await QuranSearchService.saveRecent(q, _recentSearches);
      if (mounted && gen == _searchGen) setState(() {});
    }
    if (!wantAi) return;
    List<VectorHit> ai = const [];
    var offline = false;
    try {
      ai = await EquranService.vectorSearch(query: q, limit: 10);
    } catch (_) {
      offline = true;
    }
    if (!mounted || gen != _searchGen) return;
    setState(() {
      _vectorHits = ai;
      _aiLoading = false;
      _aiOffline = offline;
    });
  }

  Future<void> _loadRecentSearches() async {
    _recentSearches = await QuranSearchService.loadRecent();
    if (mounted) setState(() {});
  }

  void _clearSearch() {
    _searchDebounce?.cancel();
    _searchController.clear();
    setState(() {
      _ayatHits = [];
      _vectorHits = [];
      _ayatSearching = false;
      _aiWanted = false;
      _aiLoading = false;
      _aiOffline = false;
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
        builder: (context, scrollController) =>
            DownloadScreen(scrollController: scrollController),
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
        _ayatHits = [];
        _vectorHits = [];
        _ayatSearching = false;
        _aiWanted = false;
        _aiLoading = false;
        _aiOffline = false;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.homeReloadFailed('$e'))));
    }
  }

  /// Single merged search panel: local exact matches on top, AI semantic
  /// follow-up underneath when the query looks like a meaning question.
  Widget _searchPanel(ColorScheme scheme) {
    final query = _searchController.text.trim();
    if (_ayatSearching && _ayatHits.isEmpty) {
      return Center(
        child: CircularProgressIndicator(color: scheme.primary),
      );
    }
    final aiSettled = _aiWanted && !_aiLoading;
    if (_ayatHits.isEmpty &&
        (!_aiWanted || (aiSettled && _vectorHits.isEmpty && !_aiOffline))) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(24, 48, 24, 140),
        children: [
          LiquidGlassCard(
            padding: const EdgeInsets.all(26),
            child: Column(
              children: [
                Icon(
                  Icons.search_off_rounded,
                  size: 52,
                  color: scheme.primary,
                ),
                const SizedBox(height: 14),
                Text(
                  context.l10n.homeEmptySearchTitle(query),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  context.l10n.homeEmptySearchSubtitle,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      );
    }
    return RefreshIndicator(
      color: scheme.primary,
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        children: [
          for (final hit in _ayatHits)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _ayatHitCard(hit),
            ),
          if (_aiWanted) _aiSection(scheme),
          const SizedBox(height: 118),
        ],
      ),
    );
  }

  /// AI semantic follow-up section inside the merged results.
  Widget _aiSection(ColorScheme scheme) {
    final header = Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 10),
      child: Row(
        children: [
          Icon(
            Icons.auto_awesome_rounded,
            size: 16,
            color: scheme.tertiary,
          ),
          const SizedBox(width: 6),
          Text(
            context.l10n.homeAiSemanticResults,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: scheme.tertiary,
            ),
          ),
          const SizedBox(width: 8),
          if (_aiLoading)
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
        ],
      ),
    );
    if (_aiLoading) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header,
          LiquidGlassCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                LinearProgressIndicator(color: scheme.tertiary),
                const SizedBox(height: 12),
                Text(
                  context.l10n.homeAiUnderstanding,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurface.withValues(alpha: .72),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }
    if (_aiOffline) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header,
          LiquidGlassCard(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Row(
              children: [
                Icon(
                  Icons.wifi_off_rounded,
                  size: 20,
                  color: scheme.onSurface.withValues(alpha: .72),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    context.l10n.homeAiNeedsInternet,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }
    if (_vectorHits.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header,
        for (final hit in _vectorHits)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _vectorHitCard(hit),
          ),
      ],
    );
  }

  Widget _vectorHitCard(VectorHit hit) {
    final scheme = Theme.of(context).colorScheme;
    return LiquidGlassCard(
      radius: 20,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      onTap: () => _openVectorHit(hit),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(
                    color: scheme.primary.withValues(alpha: .18),
                  ),
                ),
                child: Text(
                  hit.title,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    color: scheme.primary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: scheme.tertiary.withValues(alpha: .14),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.auto_awesome_rounded,
                      size: 12,
                      color: scheme.tertiary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${(hit.skor * 100).round()}%',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: scheme.tertiary,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Icon(
                Icons.chevron_right_rounded,
                color: scheme.onSurface.withValues(alpha: .72),
              ),
            ],
          ),
          if (hit.snippet.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              hit.snippet,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _openVectorHit(VectorHit hit) async {
    final surahNumber = hit.surahNumber;
    if (surahNumber == null) return;
    final surah = _allSurahs.firstWhere(
      (s) => s.number == surahNumber,
      orElse: () => Surah(
        number: surahNumber,
        name: '${hit.data['nama_surat'] ?? 'Surah $surahNumber'}',
        nameAr: '${hit.data['nama_surat_arab'] ?? ''}',
        type: '',
        totalAyahs: 0,
      ),
    );
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SurahDetailScreen(
          surah: surah,
          initialAyah: hit.ayahNumber,
        ),
      ),
    );
    if (hit.ayahNumber != null) {
      await _settings.setLastRead(surahNumber, hit.ayahNumber!);
    }
  }

  /// Second AppBar row: recent searches when idle, live status when busy.
  Widget _recentsRow(ColorScheme scheme) {
    final l = AppLocalizations.of(context)!;
    if (_recentSearches.isEmpty) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Text(
          l.homeRecentEmpty,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: scheme.onSurface.withValues(alpha: .72),
          ),
        ),
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(right: 4),
            itemCount: _recentSearches.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (_, i) => ActionChip(
              label: Text(
                _recentSearches[i],
                style: const TextStyle(fontSize: 12),
              ),
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              onPressed: () {
                _searchController.text = _recentSearches[i];
                _onSearchChanged(_recentSearches[i]);
              },
            ),
          ),
        ),
        const SizedBox(width: 12),
        TextButton(
          onPressed: () async {
            await QuranSearchService.clearRecent();
            if (mounted) setState(() => _recentSearches = []);
          },
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            minimumSize: const Size(64, 36),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(AppLocalizations.of(context)!.actionClear),
        ),
      ],
    );
  }

  Widget _searchStatusRow(ColorScheme scheme) {
    final l = AppLocalizations.of(context)!;
    final String text;
    final IconData icon;
    if (_ayatSearching) {
      text = l.homeSearchSearching;
      icon = Icons.search_rounded;
    } else if (_aiLoading) {
      text = l.homeSearchAiLoading;
      icon = Icons.auto_awesome_rounded;
    } else if (_aiWanted && _aiOffline) {
      text = l.homeSearchAiOffline;
      icon = Icons.wifi_off_rounded;
    } else if (_aiWanted) {
      text = l.homeSearchLocal;
      icon = Icons.auto_awesome_rounded;
    } else {
      text = l.homeSearchInstant;
      icon = Icons.bolt_rounded;
    }
    return Align(
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: scheme.tertiary),
          const SizedBox(width: 6),
          Text(
            text,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: scheme.onSurface.withValues(alpha: .72),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _ayatHitCard(SearchHit hit) {
    final scheme = Theme.of(context).colorScheme;
    return LiquidGlassCard(
      radius: 20,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      onTap: () => _openHit(hit),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(
                    color: scheme.primary.withValues(alpha: .18),
                  ),
                ),
                child: Text(
                  hit.isSurah
                      ? hit.surah.name
                      : 'QS ${hit.surah.number}:${hit.ayah!.number}',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    color: scheme.primary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  hit.isSurah
                      ? hit.surah.nameAr
                      : hit.surah.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurface.withValues(alpha: .72),
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: scheme.onSurface.withValues(alpha: .72),
              ),
            ],
          ),
          if (!hit.isSurah) ...[
            const SizedBox(height: 8),
            Text(
              hit.snippet,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _openHit(SearchHit hit) async {
    if (hit.isSurah) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SurahDetailScreen(surah: hit.surah),
        ),
      );
    } else {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SurahDetailScreen(
            surah: hit.surah,
            initialAyah: hit.ayah!.number,
          ),
        ),
      );
      await _settings.setLastRead(hit.surah.number, hit.ayah!.number);
    }
  }

  Widget _resumeBead(ColorScheme scheme) {
    final lastSurah = _settings.lastSurah;
    if (lastSurah == null) return const SizedBox.shrink();
    Surah? target;
    for (final s in _allSurahs) {
      if (s.number == lastSurah) {
        target = s;
        break;
      }
    }
    final lastAyah = _settings.lastAyah;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      child: LiquidGlassCard(
        radius: 20,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: scheme.primary,
              ),
              alignment: Alignment.center,
              child: Text(
                _settings.formatNumber(lastSurah),
                style: TextStyle(
                  color: scheme.onPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    target != null ? target.name : 'Surah $lastSurah',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: scheme.onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    lastAyah != null
                        ? 'Terakhir: ayat ${_settings.formatNumber(lastAyah)}'
                        : context.l10n.homeLastReadEmpty,
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: target == null
                  ? null
                  : () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SurahDetailScreen(
                          surah: target!,
                          initialAyah: lastAyah,
                        ),
                      ),
                    ),
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 44),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
              ),
              child: Text(context.l10n.actionContinue),
            ),
          ],
        ),
      ),
    );
  }

  Widget _khatamBanner(ColorScheme scheme) {
    final t = _khatam.target;
    final hasTarget = t != null;
    // Distilled: inline tonal row, not a competing card. One focal card per screen = resume only.
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Material(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const KhatamScreen()),
          ).then((_) => _loadOfflineStatus()),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: scheme.primary.withValues(alpha: .12),
                  ),
                  child: Icon(
                    hasTarget
                        ? Icons.track_changes_rounded
                        : Icons.flag_outlined,
                    size: 18,
                    color: scheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hasTarget
                            ? '${(t.progress * 100).toStringAsFixed(0)}% • ${t.pagesDone}/${t.totalPages} halaman'
                            : (_khatam.completedCount > 0
                                ? context.l10n.khatamStartNext
                                : context.l10n.khatamTargetTitle),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurface,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      if (hasTarget) ...[
                        ThreadProgress(value: t.progress),
                        const SizedBox(height: 4),
                        Text(
                          'QS ${t.curSurah}:${t.curAyah} • reset 00.00',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ] else
                        Text(
                          context.l10n.khatamDailyHint,
                          style: TextStyle(
                            fontSize: 12,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right_rounded,
                  color: scheme.onSurfaceVariant,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _homeDashboard(ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const HomeFeatureStrip(),
          const SizedBox(height: 12),
          _bookmarkQuickAccess(scheme),
        ],
      ),
    );
  }

  Widget _bookmarkQuickAccess(ColorScheme scheme) {
    final ayatCount = _settings.bookmarks.length;
    final doaCount = _settings.savedDuas.length;
    final asmaulCount = _settings.savedAsmaul.length;
    final total = ayatCount + doaCount + asmaulCount;
    final hasAny = total > 0;
    return LiquidGlassCard(
      radius: 16,
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BookmarksScreen())),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(shape: BoxShape.circle, color: scheme.primary.withValues(alpha: .12)),
            child: Icon(Icons.bookmark_rounded, color: scheme.primary, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(context.l10n.bookmarksTitle, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                const SizedBox(height: 2),
                Text(
                  hasAny
                      ? context.l10n.bookmarksSubtitle(asmaulCount, ayatCount, doaCount)
                      : context.l10n.homeNoBookmarks,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: scheme.onSurface.withValues(alpha: .72)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: hasAny ? scheme.primary : scheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(99)),
            child: Text(
              hasAny ? '$total' : 'Buka',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: hasAny ? scheme.onPrimary : scheme.onSurfaceVariant),
            ),
          ),
          const SizedBox(width: 6),
          Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        titleSpacing: 20,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.of(context)!.homeTitle,
              style: TextStyle(
                color: scheme.onSurface,
                fontWeight: FontWeight.w800,
                fontSize: 25,
                letterSpacing: -0.8,
              ),
            ),
            Text(
              AppLocalizations.of(context)!.homeSubtitle,
              style: TextStyle(
                color: scheme.onSurface.withValues(alpha: 0.72),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          LiquidGlassIconButton(
            icon: Icons.settings_rounded,
            tooltip: 'Pengaturan',
            semanticLabel: context.l10n.homeOpenSettings,
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
          const SizedBox(width: 16),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(72),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              textInputAction: TextInputAction.search,
              style: TextStyle(
                color: scheme.onSurface,
                fontSize: 16,
                height: 1.2,
              ),
              decoration: InputDecoration(
                filled: true,
                fillColor: scheme.surfaceContainerHighest,
                hintText: AppLocalizations.of(context)!.homeSearchHint,
                hintStyle: TextStyle(
                  color: scheme.onSurfaceVariant.withValues(alpha: .72),
                  fontSize: 14,
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: scheme.primary,
                  size: 22,
                ),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: context.l10n.homeSearchClear,
                        onPressed: _clearSearch,
                        icon: const Icon(Icons.close_rounded, size: 20),
                      ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: scheme.outlineVariant),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: scheme.outlineVariant),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: scheme.primary, width: 1.4),
                ),
              ),
            ),
          ),
        ),
      ),
      body: FutureBuilder<List<Surah>>(
        future: _surahListFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              _allSurahs.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: scheme.primary),
                  const SizedBox(height: 14),
                  Text(
                    context.l10n.homeLoadingQuran,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
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
                    Icon(
                      Icons.cloud_off_rounded,
                      size: 46,
                      color: scheme.primary,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      context.l10n.homeLoadFailedTitle,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      context.l10n.homeLoadFailedSubtitle,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 18),
                    ElevatedButton.icon(
                      onPressed: () =>
                          setState(() => _surahListFuture = _loadSurahs()),
                      icon: const Icon(Icons.refresh_rounded),
                      label: Text(context.l10n.actionRetry),
                    ),
                  ],
                ),
              ),
            );
          }

          if (_searchController.text.trim().isNotEmpty) {
            return _searchPanel(scheme);
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
                        Icon(
                          Icons.search_off_rounded,
                          size: 52,
                          color: scheme.primary,
                        ),
                        const SizedBox(height: 14),
                        Text(
                          context.l10n.murotalSearchNoResults,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          context.l10n.homeSearchOtherSurah,
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
                    if (_searchController.text.isNotEmpty || _recentSearches.isNotEmpty)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                          child: SizedBox(height: 40, child: _searchController.text.isEmpty ? _recentsRow(scheme) : _searchStatusRow(scheme)),
                        ),
                      ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Al-Qur\'an',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleLarge
                                            ?.copyWith(height: 1.1),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        '${_settings.formatString(context.l10n.commonSurahCount(_filteredSurahs.length))} • ${_showJuz ? context.l10n.homeJuzRange : context.l10n.homeMushafOrder}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: scheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                SegmentedButton<bool>(
                                  segments: const [
                                    ButtonSegment<bool>(
                                      value: false,
                                      label: Text('Surah'),
                                      icon: Icon(Icons.menu_book_rounded,
                                          size: 16),
                                    ),
                                    ButtonSegment<bool>(
                                      value: true,
                                      label: Text('Juz'),
                                      icon:
                                          Icon(Icons.view_module_rounded, size: 16),
                                    ),
                                  ],
                                  selected: {_showJuz},
                                  onSelectionChanged: (s) =>
                                      setState(() => _showJuz = s.first),
                                  showSelectedIcon: false,
                                  style: ButtonStyle(
                                    visualDensity: VisualDensity.compact,
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_searchController.text.isEmpty &&
                        _cachedSurahCount < 114)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                          child: Material(
                            color: scheme.surfaceContainerHighest
                                .withValues(alpha: .65),
                            borderRadius: BorderRadius.circular(14),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: _openDownloadManager,
                              child: Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(12, 10, 12, 10),
                                child: Row(
                                  children: [
                                    Icon(Icons.offline_pin_rounded,
                                        size: 18, color: scheme.primary),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _cachedSurahCount == 0
                                                ? context.l10n.homeOfflineEmpty
                                                : 'Offline ${_settings.formatNumber(_cachedSurahCount)}/114',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color: scheme.onSurface,
                                            ),
                                          ),
                                          Text(
                                            context.l10n.homeOfflineHint,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: scheme.onSurfaceVariant,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      _cachedSurahCount == 0
                                          ? 'Unduh'
                                          : 'Lengkapi',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        color: scheme.primary,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Icon(Icons.chevron_right_rounded,
                                        size: 18,
                                        color: scheme.primary),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (_searchController.text.isEmpty &&
                        _settings.lastSurah != null)
                      SliverToBoxAdapter(child: _resumeBead(scheme)),
                    if (_searchController.text.isEmpty)
                      SliverToBoxAdapter(child: _khatamBanner(scheme)),
                    if (_searchController.text.isEmpty)
                      SliverToBoxAdapter(child: _homeDashboard(scheme)),
                    SliverToBoxAdapter(key: _quranIndexAnchor, child: const SizedBox(height: 8)),
                    if (_showJuz && _searchController.text.isEmpty)
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 130),
                        sliver: SliverList(
                          delegate: SliverChildListDelegate([
                            _juzJumpStrip(scheme),
                            const SizedBox(height: 10),
                            for (final juz in JuzInfo.all)
                              Padding(
                                key: _juzKeys[juz.number],
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _buildJuzCard(juz),
                              ),
                          ]),
                        ),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 130),
                        sliver: crossAxisCount == 1
                            ? SliverList(
                                delegate: SliverChildBuilderDelegate(
                                  (context, index) => Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: _buildSurahCard(
                                      _filteredSurahs[index],
                                    ),
                                  ),
                                  childCount: _filteredSurahs.length,
                                ),
                              )
                            : SliverGrid(
                                delegate: SliverChildBuilderDelegate(
                                  (context, index) =>
                                      _buildSurahCard(_filteredSurahs[index]),
                                  childCount: _filteredSurahs.length,
                                ),
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
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

  String _juzRangeLabel(Surah surah) {
    final range = JuzInfo.juzRangeOfSurah(surah.number, surah.totalAyahs);
    if (range.length == 1) return 'Juz ${_settings.formatNumber(range.first)}';
    return 'Juz ${_settings.formatNumber(range.first)}-${_settings.formatNumber(range.last)}';
  }

  String _surahName(int number) {
    for (final s in _allSurahs) {
      if (s.number == number) return s.name;
    }
    return 'Surah $number';
  }

  /// Quick-jump strip 1-30: tap scrolls to the card and expands it.
  Widget _juzJumpStrip(ColorScheme scheme) {
    final current = _currentJuz;
    return LiquidGlassCard(
      radius: 18,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                context.l10n.homeJumpToJuz,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              if (current != null)
                GestureDetector(
                  onTap: () => _jumpToJuz(current),
                  child: Text(
                    context.l10n.homeCurrentJuz(_settings.formatNumber(current)),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: scheme.primary,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var j = 1; j <= 30; j++)
                GestureDetector(
                  onTap: () => _jumpToJuz(j),
                  child: Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: j == current
                          ? scheme.primary
                          : scheme.primary.withValues(alpha: .10),
                      border: Border.all(
                        color: scheme.primary.withValues(
                          alpha: j == current ? 1 : .25,
                        ),
                      ),
                    ),
                    child: Text(
                      _settings.formatNumber(j),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: j == current
                            ? scheme.onPrimary
                            : scheme.primary,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  void _jumpToJuz(int number) {
    setState(() => _expandedJuz = number);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final key = _juzKeys[number];
      if (key?.currentContext != null) {
        Scrollable.ensureVisible(
          key!.currentContext!,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
          alignment: 0.05,
        );
      }
    });
  }

  Widget _buildJuzCard(JuzInfo juz) {
    final scheme = Theme.of(context).colorScheme;
    final totals = _juzTotals;
    final segments = juz.segments(totals);
    final total = juz.ayahCount(totals);
    final read = juz.readCount(totals, _settings.isRead);
    final progress = total == 0 ? 0.0 : (read / total).clamp(0.0, 1.0);
    final pct = (progress * 100).round();
    final isCurrent = _currentJuz == juz.number;
    final expanded = _expandedJuz == juz.number;
    final startName = _surahName(juz.startSurah);
    final endName = _surahName(juz.endSurah);
    final f = _settings.formatNumber;
    final range = juz.startSurah == juz.endSurah
        ? '$startName ${f(juz.startAyah)}–${f(juz.endAyah)}'
        : '$startName ${f(juz.startAyah)} → $endName ${f(juz.endAyah)}';
    return LiquidGlassCard(
      radius: 22,
      padding: const EdgeInsets.all(18),
      onTap: () => setState(
        () => _expandedJuz = expanded ? null : juz.number,
      ),
      child: Semantics(
        button: true,
        expanded: expanded,
        label:
            isCurrent
                ? context.l10n.homeJuzSummaryCurrent('${juz.number}', range, pct)
                : context.l10n.homeJuzSummary('${juz.number}', range, pct),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: scheme.primary.withValues(alpha: 0.12),
                    border: Border.all(
                      color: scheme.primary.withValues(alpha: 0.22),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    f(juz.number),
                    style: TextStyle(
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
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Juz ${f(juz.number)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: scheme.onSurface,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ),
                          if (isCurrent)
                            Container(
                              margin: const EdgeInsets.only(left: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: scheme.tertiary.withValues(alpha: .14),
                                borderRadius: BorderRadius.circular(99),
                              ),
                              child: Text(
                                context.l10n.homeCurrentPosition,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: scheme.tertiary,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        range,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: scheme.onSurfaceVariant,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                AnimatedRotation(
                  turns: expanded ? 0.25 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    color: scheme.onSurfaceVariant,
                    size: 22,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: ThreadProgress(value: progress)),
                const SizedBox(width: 10),
                Text(
                  total == 0 ? '…' : '$pct% • $read/$total',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: scheme.primary,
                  ),
                ),
              ],
            ),
            if (expanded) ...[
              const SizedBox(height: 8),
              for (final seg in segments)
                _juzSegmentRow(scheme, seg.$1, seg.$2, seg.$3),
            ],
          ],
        ),
      ),
    );
  }

  /// One surah segment inside an expanded Juz card; tap jumps to it.
  Widget _juzSegmentRow(ColorScheme scheme, int surah, int from, int to) {
    final f = _settings.formatNumber;
    Surah? target;
    for (final s in _allSurahs) {
      if (s.number == surah) {
        target = s;
        break;
      }
    }
    target ??= Surah(
      number: surah,
      name: _surahName(surah),
      nameAr: '',
      type: '',
      totalAyahs: 0,
    );
    final t = target;
    final done = juzSegmentDone(surah, from, to);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SurahDetailScreen(surah: t, initialAyah: from),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            BeadDot(filled: done, size: 10),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '${_surahName(surah)} ${f(from)}–${f(to)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface,
                ),
              ),
            ),
            Icon(
              Icons.arrow_forward_rounded,
              size: 16,
              color: scheme.primary,
            ),
          ],
        ),
      ),
    );
  }

  /// True when every ayah of the segment is marked read.
  bool juzSegmentDone(int surah, int from, int to) {
    for (var a = from; a <= to; a++) {
      if (!_settings.isRead(surah, a)) return false;
    }
    return true;
  }

  Widget _buildSurahCard(Surah surah) {
    final scheme = Theme.of(context).colorScheme;

    return LiquidGlassCard(
      radius: 22,
      padding: const EdgeInsets.all(18),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SurahDetailScreen(surah: surah),
          ),
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
                color: scheme.primary.withValues(alpha: 0.12),
                border: Border.all(
                  color: scheme.primary.withValues(alpha: 0.22),
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                _settings.formatNumber(surah.number),
                style: TextStyle(
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
                    style: TextStyle(
                      color: scheme.onSurface,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${_settings.formatNumber(surah.totalAyahs)} Ayat • ${surah.type} • ${_juzRangeLabel(surah)}',
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
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
                    color: scheme.onSurface,
                    fontSize: 25,
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: 8),
                Icon(
                  Icons.chevron_right_rounded,
                  color: scheme.onSurfaceVariant,
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
