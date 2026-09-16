import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:quranku/l10n/app_localizations.dart';
import '../data/asmaul_husna.dart';
import '../data/daily_duas.dart';
import '../models/surah.dart';
import '../services/api_service.dart';
import '../services/dua_source.dart';
import '../services/settings_service.dart';
import '../widgets/liquid_glass.dart';
import 'surah_detail_screen.dart';

class BookmarksScreen extends StatefulWidget {
  const BookmarksScreen({super.key});

  @override
  State<BookmarksScreen> createState() => _BookmarksScreenState();
}

class _BookmarksScreenState extends State<BookmarksScreen>
    with SingleTickerProviderStateMixin {
  final SettingsService _settings = SettingsService();
  final DuaSource _duaSource = DuaSource();
  late TabController _tab;
  Map<int, String> _surahNames = {};
  List<DailyDua> _remoteDuas = [];

  /// Language the loaded remote dua set belongs to.
  String _duaLanguage = '';
  bool _duasLoading = false;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    _settings.addListener(_refresh);
    _loadSurahNames();
  }

  /// The remote dua set is language-specific, so reload it when it changes.
  /// Also runs right after [initState] for the first load.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final language = duaLanguageCode(
      Localizations.localeOf(context).languageCode,
    );
    if (language == _duaLanguage) return;
    _duaLanguage = language;
    _remoteDuas = [];
    _loadRemoteDuas(language);
  }

  @override
  void dispose() {
    _settings.removeListener(_refresh);
    _tab.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _loadSurahNames() async {
    try {
      final surahs = await ApiService().fetchSurahs();
      if (!mounted) return;
      setState(() => _surahNames = {for (var s in surahs) s.number: s.name});
    } catch (_) {}
  }

  Future<void> _loadRemoteDuas(String language) async {
    // Plain assignment, not setState: this is kicked off from
    // didChangeDependencies, where a build is already scheduled.
    _duasLoading = true;
    try {
      final list = await _duaSource.loadRemote(language);
      if (!mounted) return;
      setState(() => _remoteDuas = list);
    } catch (e) {
      debugPrint('BookmarksScreen: dua load failed: $e');
    } finally {
      if (mounted) setState(() => _duasLoading = false);
    }
  }

  List<String> get _sortedAyatKeys {
    final raw = _settings.bookmarks.toList();
    raw.sort((a, b) {
      final pa = a.split('_');
      final pb = b.split('_');
      final sa = int.tryParse(pa[0]) ?? 0;
      final sb = int.tryParse(pb[0]) ?? 0;
      if (sa != sb) return sa.compareTo(sb);
      final aa = int.tryParse(pa[1]) ?? 0;
      final ab = int.tryParse(pb[1]) ?? 0;
      return aa.compareTo(ab);
    });
    return raw;
  }

  List<DailyDua> get _savedDuas {
    final all = [...dailyDuas, ..._remoteDuas];
    return all.where((d) => _settings.isDuaSaved(d.id)).toList();
  }

  List<AsmaulHusna> get _savedAsmaul {
    return asmaulHusna.where((a) => _settings.isAsmaulSaved(a.number)).toList();
  }

  /// Saved ids that no loaded source can resolve — an upstream dua that has
  /// since been removed, for instance.
  List<String> get _missingDuaIds {
    final known = {
      ...dailyDuas.map((e) => e.id),
      ..._remoteDuas.map((e) => e.id),
    };
    return _settings.savedDuas.where((id) => !known.contains(id)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final ayatCount = _settings.bookmarks.length;
    final doaCount = _settings.savedDuas.length;
    final asmaulCount = _settings.savedAsmaul.length;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.bookmarksTitle, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
            Text(
              l.bookmarksSubtitle(asmaulCount, ayatCount, doaCount),
              style: TextStyle(color: scheme.onSurface.withValues(alpha: .72), fontSize: 12),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tab,
          labelColor: scheme.primary,
          unselectedLabelColor: scheme.onSurfaceVariant,
          indicatorColor: scheme.primary,
          tabs: [
            Tab(text: l.bookmarksTabAyah(ayatCount)),
            Tab(text: l.bookmarksTabDoa(doaCount)),
            Tab(text: l.bookmarksTabAsmaul(asmaulCount)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _ayatTab(scheme),
          _doaTab(scheme),
          _asmaulTab(scheme),
        ],
      ),
    );
  }

  Widget _ayatTab(ColorScheme scheme) {
    final l = AppLocalizations.of(context)!;
    final keys = _sortedAyatKeys;
    if (keys.isEmpty) return _emptyState(scheme, Icons.bookmark_border_rounded, l.bookmarksEmptyAyah, l.bookmarksEmptyAyahHint);
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      itemCount: keys.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final key = keys[i];
        final parts = key.split('_');
        final surahNum = int.tryParse(parts[0]) ?? 0;
        final ayahNum = int.tryParse(parts[1]) ?? 0;
        final surahName = _surahNames[surahNum] ?? 'Surah $surahNum';
        return LiquidGlassCard(
          radius: 16,
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          onTap: () async {
            Surah target = Surah(number: surahNum, name: surahName, nameAr: '', type: '', totalAyahs: 0);
            try {
              final surahs = await ApiService().fetchSurahs();
              target = surahs.firstWhere((s) => s.number == surahNum, orElse: () => target);
            } catch (_) {}
            if (!mounted) return;
            Navigator.push(context, MaterialPageRoute(builder: (_) => SurahDetailScreen(surah: target, initialAyah: ayahNum)));
          },
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(shape: BoxShape.circle, color: scheme.primary.withValues(alpha: .12), border: Border.all(color: scheme.primary.withValues(alpha: .22))),
                alignment: Alignment.center,
                child: Text('$surahNum:${_settings.formatNumber(ayahNum)}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: scheme.primary)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(surahName, style: TextStyle(fontWeight: FontWeight.w800, color: scheme.onSurface)),
                    Text('QS $surahNum:$ayahNum', style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                  ],
                ),
              ),
              IconButton(
                tooltip: AppLocalizations.of(context)!.commonDelete,
                onPressed: () => _settings.toggleBookmark(surahNum, ayahNum),
                icon: Icon(Icons.bookmark_rounded, color: scheme.primary, size: 20),
                style: IconButton.styleFrom(minimumSize: const Size(44, 44)),
              ),
              Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
            ],
          ),
        );
      },
    );
  }

  Widget _doaTab(ColorScheme scheme) {
    final l = AppLocalizations.of(context)!;
    final saved = _savedDuas;
    // While the remote set is still arriving, an unresolved id is not yet
    // evidence that the dua is gone.
    final missing = _duasLoading ? const <String>[] : _missingDuaIds;
    if (saved.isEmpty && missing.isEmpty) {
      if (_duasLoading) {
        return _emptyState(
          scheme,
          Icons.menu_book_outlined,
          l.duasLoading,
          null,
        );
      }
      return _emptyState(
        scheme,
        Icons.menu_book_outlined,
        l.bookmarksEmptyDoa,
        l.bookmarksEmptyDoaHint,
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      children: [
        for (final d in saved) ...[
          _doaCard(scheme, d),
          const SizedBox(height: 10),
        ],
        for (final id in missing) ...[
          LiquidGlassCard(
            radius: 16,
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    l.bookmarksDuaMissing,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurface.withValues(alpha: .72),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: l.commonDelete,
                  onPressed: () => _settings.toggleDuaSaved(id),
                  icon: Icon(
                    Icons.bookmark_rounded,
                    color: scheme.primary,
                    size: 20,
                  ),
                  style: IconButton.styleFrom(
                    minimumSize: const Size(44, 44),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  Widget _doaCard(ColorScheme scheme, DailyDua d) {
    final l = AppLocalizations.of(context)!;
    final text = d.textFor(
      Localizations.localeOf(context).languageCode,
    );
    return LiquidGlassCard(
      radius: 16,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: scheme.primary.withValues(alpha: .12), borderRadius: BorderRadius.circular(99)),
                  child: Text(
                    text.category,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: scheme.primary),
                  ),
                ),
              ),
              const Spacer(),
              IconButton(
                tooltip: l.commonDelete,
                onPressed: () => _settings.toggleDuaSaved(d.id),
                icon: Icon(Icons.bookmark_rounded, color: scheme.primary, size: 20),
                style: IconButton.styleFrom(minimumSize: const Size(44, 44)),
              ),
            ],
          ),
          Text(text.title, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: scheme.onSurface)),
          const SizedBox(height: 6),
          Text(d.arabic, textAlign: TextAlign.right, style: GoogleFonts.amiri(fontSize: 18, height: 1.8, color: scheme.onSurface)),
          const SizedBox(height: 4),
          Text(text.translation, style: TextStyle(fontSize: 12, color: scheme.onSurface.withValues(alpha: .72))),
        ],
      ),
    );
  }

  Widget _asmaulTab(ColorScheme scheme) {
    final l = AppLocalizations.of(context)!;
    final list = _savedAsmaul;
    if (list.isEmpty) return _emptyState(scheme, Icons.auto_awesome_outlined, l.bookmarksEmptyAsmaul, l.bookmarksEmptyAsmaulHint);
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 0.92),
      itemCount: list.length,
      itemBuilder: (_, i) {
        final a = list[i];
        return LiquidGlassCard(
          radius: 16,
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
          child: Stack(
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('${a.number}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: scheme.primary)),
                  const SizedBox(height: 4),
                  Text(a.arabic, textAlign: TextAlign.center, style: GoogleFonts.amiri(fontSize: 20, height: 1.6, color: scheme.onSurface)),
                  Text(a.latin, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                  Text(asmaulMeaning(a.number, Localizations.localeOf(context).languageCode), textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: scheme.onSurface.withValues(alpha: .72))),
                ],
              ),
              Positioned(
                top: 0,
                right: 0,
                child: GestureDetector(
                  onTap: () => _settings.toggleAsmaulSaved(a.number),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(shape: BoxShape.circle, color: scheme.primary.withValues(alpha: .12)),
                    child: Icon(Icons.bookmark_rounded, size: 16, color: scheme.primary),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _emptyState(ColorScheme scheme, IconData icon, String title, String? subtitle) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: LiquidGlassCard(
          radius: 20,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 46, color: scheme.primary),
              const SizedBox(height: 12),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16), textAlign: TextAlign.center),
              if (subtitle != null) ...[
                const SizedBox(height: 6),
                Text(subtitle, style: TextStyle(fontSize: 12, color: scheme.onSurface.withValues(alpha: .72)), textAlign: TextAlign.center),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
