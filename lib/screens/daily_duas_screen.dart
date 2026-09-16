import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../data/daily_duas.dart';
import '../l10n/l10n.dart';
import '../services/dua_source.dart';
import '../services/settings_service.dart';
import '../widgets/liquid_glass.dart';

/// Sentinel filter key for the "saved" chip. Category labels are localized, so
/// they cannot be used as stable filter keys on their own.
const String _savedCategoryKey = '__saved__';

class DailyDuasScreen extends StatefulWidget {
  const DailyDuasScreen({super.key});
  @override
  State<DailyDuasScreen> createState() => _DailyDuasScreenState();
}

class _DailyDuasScreenState extends State<DailyDuasScreen> {
  String _query = '';
  String _category = '';
  final _searchCtrl = TextEditingController();
  final _settings = SettingsService();
  final _duaSource = DuaSource();

  /// Language the currently loaded remote set belongs to.
  String _languageCode = '';

  /// Guard against a stale load landing after a language switch.
  int _loadGeneration = 0;

  List<DailyDua> _remote = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _settings.addListener(_refresh);
  }

  /// Also runs right after [initState], so the first load happens here rather
  /// than in initState — and again whenever the UI language changes.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final language = duaLanguageCode(Localizations.localeOf(context).languageCode);
    if (language == _languageCode) return;
    _languageCode = language;
    // Category labels are localized, so the active filter no longer applies.
    _category = '';
    _remote = [];
    _loadRemote(language);
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  /// Bundled duas are always present; the remote set depends on the language:
  /// equran.id for Indonesian, Hisn al-Muslim for English.
  Future<void> _loadRemote(String language) async {
    final generation = ++_loadGeneration;
    // Plain assignment, not setState: this runs from didChangeDependencies,
    // where a build is already scheduled.
    _loading = true;
    try {
      final all = await _duaSource.loadRemote(
        language,
        onBatch: (batch) {
          if (!mounted || generation != _loadGeneration) return;
          setState(() => _remote = [..._remote, ...batch]);
        },
      );
      if (!mounted || generation != _loadGeneration) return;
      // Re-apply the ordered result once every batch has landed.
      setState(() => _remote = all);
    } catch (e) {
      debugPrint('DailyDuasScreen: dua load failed: $e');
    } finally {
      if (mounted && generation == _loadGeneration) {
        setState(() => _loading = false);
      }
    }
  }

  List<DailyDua> get _all => [...dailyDuas, ..._remote];

  @override
  void dispose() {
    _settings.removeListener(_refresh);
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final cats = <({String key, String label})>[
      (key: '', label: l.commonFilterAll),
      (key: _savedCategoryKey, label: l.commonFilterSaved),
      for (final c in {for (final d in _all) d.textFor(_languageCode).category})
        (key: c, label: c),
    ];
    final q = _query.toLowerCase();
    final items = _all.where((d) {
      final text = d.textFor(_languageCode);
      if (_category == _savedCategoryKey && !_settings.isDuaSaved(d.id)) {
        return false;
      }
      if (_category.isNotEmpty &&
          _category != _savedCategoryKey &&
          text.category != _category) {
        return false;
      }
      if (q.isEmpty) return true;
      return text.title.toLowerCase().contains(q) ||
          d.arabic.contains(_query) ||
          d.latin.toLowerCase().contains(q) ||
          text.translation.toLowerCase().contains(q);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l.duasTitle,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
            ),
            Text(
              l.duasSubtitle,
              style: TextStyle(
                color: scheme.onSurface.withValues(alpha: .72),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: LiquidGlassCard(
              radius: 18,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              child: TextField(
                controller: _searchCtrl,
                textInputAction: TextInputAction.search,
                onChanged: (v) => setState(() => _query = v.trim()),
                decoration: InputDecoration(
                  hintText: l.duasSearchHint,
                  border: InputBorder.none,
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _query.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded),
                          onPressed: () => setState(() {
                            _query = '';
                            _searchCtrl.clear();
                          }),
                        )
                      : null,
                ),
              ),
            ),
          ),
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: cats.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final c = cats[i];
                final sel = _category == c.key;
                return ChoiceChip(
                  label: Text(c.label),
                  selected: sel,
                  onSelected: (_) => setState(() => _category = c.key),
                  selectedColor: scheme.primary.withValues(alpha: .18),
                  labelStyle: TextStyle(
                    fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                    color: sel
                        ? scheme.primary
                        : scheme.onSurface.withValues(alpha: .72),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: items.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(28),
                      child: LiquidGlassCard(
                        radius: 20,
                        padding: const EdgeInsets.all(20),
                        child: _loading
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(l.duasLoading),
                                ],
                              )
                            : Text(l.commonNoResults),
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 24),
                    itemCount: items.length,
                    itemBuilder: (_, i) => _duaCard(items[i]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _duaCard(DailyDua d) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final text = d.textFor(_languageCode);
    final saved = _settings.isDuaSaved(d.id);
    return RepaintBoundary(
      child: SurfaceRow(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Flexible(
                  child: Text(
                    text.category.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const Spacer(),
                IconButton(
                  tooltip: saved ? l.commonDelete : l.commonSave,
                  onPressed: () => _settings.toggleDuaSaved(d.id),
                  icon: Icon(
                    saved
                        ? Icons.bookmark_rounded
                        : Icons.bookmark_border_rounded,
                    size: 20,
                    color: saved ? scheme.primary : scheme.outline,
                  ),
                  style: IconButton.styleFrom(minimumSize: const Size(44, 44)),
                ),
                IconButton(
                  tooltip: l.commonCopy,
                  onPressed: () async {
                    await Clipboard.setData(
                      ClipboardData(
                        text:
                            '${text.title}\n${d.arabic}\n${d.latin}\n${text.translation}\n(${text.source})',
                      ),
                    );
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(l.commonCopied),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  icon: const Icon(Icons.copy_rounded, size: 20),
                  style: IconButton.styleFrom(minimumSize: const Size(44, 44)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              text.title,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
            ),
            const SizedBox(height: 10),
            SelectableText(
              d.arabic,
              textAlign: TextAlign.right,
              style: GoogleFonts.amiri(
                fontSize: 24,
                height: 1.9,
                color: scheme.onSurface,
              ),
            ),
            if (d.latin.isNotEmpty) ...[
              const SizedBox(height: 8),
              SelectableText(
                d.latin,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  height: 1.6,
                  fontStyle: FontStyle.italic,
                  color: scheme.onSurface.withValues(alpha: .72),
                ),
              ),
            ],
            const SizedBox(height: 6),
            SelectableText(
              text.translation,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                height: 1.55,
                color: scheme.onSurface.withValues(alpha: .72),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              text.source,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: scheme.primary.withValues(alpha: .80),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
