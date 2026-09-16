import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/equran_service.dart';
import '../widgets/liquid_glass.dart';
import 'package:quranku/l10n/app_localizations.dart';
import 'package:quranku/l10n/l10n.dart';

/// Info Kajian Sunnah (equran.id v2, agregasi Telegram). Thumbnails never
/// render empty: network image with progress + designed fallback.
class KajianScreen extends StatefulWidget {
  const KajianScreen({super.key});

  @override
  State<KajianScreen> createState() => _KajianScreenState();
}

class _KajianScreenState extends State<KajianScreen> {
  final List<KajianInfo> _items = [];
  final ScrollController _scroll = ScrollController();
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';
  String _kota = 'Semua';
  String _dateMode = 'semua';
  String _sortMode = 'terdekat';
  bool _loading = true;
  bool _loadingMore = false;
  bool _offline = false;
  int _page = 0;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _refresh();
  }

  @override
  void dispose() {
    _scroll.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients || _loading || _loadingMore || !_hasMore) return;
    if (_scroll.position.pixels >=
        _scroll.position.maxScrollExtent - 600) {
      _loadMore();
    }
  }

  String get _cacheKey =>
      'kajian_cache_${_kota}_${_query.isEmpty ? 'all' : 'q'}';

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _offline = false;
      _page = 0;
      _hasMore = true;
    });
    // Serve 6h cache instantly, then refresh from network.
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      if (raw != null) {
        final cached = json.decode(raw) as Map<String, dynamic>;
        final savedAt = (cached['at'] as num? ?? 0).toInt();
        final isFresh =
            DateTime.now().millisecondsSinceEpoch - savedAt < 6 * 3600 * 1000;
        final list = (cached['items'] as List? ?? []);
        if (list.isNotEmpty && mounted) {
          setState(() {
            _items
              ..clear()
              ..addAll(
                list.map((e) => KajianInfo.parse(e as Map<String, dynamic>)),
              );
            _loading = false;
          });
          if (isFresh) return;
        }
      }
    } catch (_) {}
    await _loadPage(reset: true);
  }

  Future<void> _loadMore() async {
    if (!_hasMore) return;
    setState(() => _loadingMore = true);
    await _loadPage();
    if (mounted) setState(() => _loadingMore = false);
  }

  Future<void> _loadPage({bool reset = false}) async {
    try {
      final res = await EquranService.fetchKajian(
        page: reset ? 1 : _page + 1,
        kota: _kota == 'Semua' ? null : _kota,
      );
      if (!mounted) return;
      setState(() {
        if (reset) _items.clear();
        _items.addAll(res.items);
        _page = res.page;
        _hasMore = res.hasMore;
        _loading = false;
        _offline = false;
      });
      if (reset && _query.isEmpty && res.items.isNotEmpty) {
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(
            _cacheKey,
            json.encode({
              'at': DateTime.now().millisecondsSinceEpoch,
              'items': res.items
                  .take(24)
                  .map(
                    (e) => {
                      'id': e.id,
                      'tema': e.tema,
                      'pemateri': e.pemateri,
                      'tanggal': e.tanggal,
                      'eventDate': e.eventDate,
                      'hari': e.hari,
                      'waktu': e.waktu,
                      'lokasi': e.lokasi,
                      'kota': e.kota,
                      'alamat': e.alamat,
                      'penyelenggara': e.penyelenggara,
                      'image': {'url': e.imageUrl},
                      'sourceUrl': e.sourceUrl,
                      'postedAt': e.postedAt,
                    },
                  )
                  .toList(),
            }),
          );
        } catch (_) {}
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _offline = _items.isEmpty;
      });
    }
  }

  List<String> get _cities {
    final set = <String>{};
    for (final e in _items) {
      if (e.kota.isNotEmpty) set.add(e.kota);
    }
    return ['Semua', ...set.toList()..sort()];
  }

  List<KajianInfo> get _visible {
    final q = _query.toLowerCase();
    var list = _items;
    if (q.isNotEmpty) {
      list = list.where((e) {
        return e.tema.toLowerCase().contains(q) ||
            e.pemateri.toLowerCase().contains(q) ||
            e.lokasi.toLowerCase().contains(q) ||
            e.kota.toLowerCase().contains(q);
      }).toList();
    }
    list = KajianFilter.byDate(list, _dateMode);
    return KajianFilter.sort(list, _sortMode);
  }

  bool get _hasActiveFilters =>
      _kota != 'Semua' || _dateMode != 'semua' || _sortMode != 'terdekat';

  int get _activeFilterCount =>
      (_kota != 'Semua' ? 1 : 0) +
      (_dateMode != 'semua' ? 1 : 0) +
      (_sortMode != 'terdekat' ? 1 : 0);

  Future<void> _resetFilters() async {
    setState(() {
      _dateMode = 'semua';
      _sortMode = 'terdekat';
    });
    await _setKota('Semua');
  }

  Future<void> _setKota(String kota) async {
    if (_kota == kota) return;
    setState(() => _kota = kota);
    await _refresh();
  }

  static const _dateOptions = [
    'semua',
    'hariIni',
    'tujuhHari',
    'tigaPuluhHari',
  ];

  static const _sortOptions = ['terdekat', 'terbaru'];

  Future<void> _openFilterSheet() async {
    var kota = _kota;
    var dateMode = _dateMode;
    var sortMode = _sortMode;
    var kotaQuery = '';
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          final l10n = AppLocalizations.of(ctx)!;
          final scheme = Theme.of(ctx).colorScheme;
          final cities = _cities
              .where(
                (c) =>
                    kotaQuery.isEmpty ||
                    c.toLowerCase().contains(kotaQuery.toLowerCase()),
              )
              .toList();
          return SafeArea(
            child: Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(ctx).size.height * 0.85,
              ),
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: scheme.outline.withValues(alpha: .35),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Text(
                        l10n.kajianFilter,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () {
                          setSheet(() {
                            kota = 'Semua';
                            dateMode = 'semua';
                            sortMode = 'terdekat';
                            kotaQuery = '';
                          });
                        },
                        child: Text(l10n.kajianReset),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Urutkan',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final o in _sortOptions)
                        ChoiceChip(
                          label: Text(
                            o == 'terdekat'
                                ? l10n.kajianSortNearest
                                : l10n.kajianSortNewest,
                          ),
                          selected: sortMode == o,
                          onSelected: (_) => setSheet(() => sortMode = o),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    context.l10n.kajianTime,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      for (final o in _dateOptions)
                        ChoiceChip(
                          label: Text(
                            switch (o) {
                              'semua' => l10n.kajianAllTime,
                              'hariIni' => l10n.kajianToday,
                              'tujuhHari' => l10n.kajianNext7Days,
                              _ => l10n.kajianNext30Days,
                            },
                          ),
                          selected: dateMode == o,
                          onSelected: (_) => setSheet(() => dateMode = o),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n.kajianCity,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  TextField(
                    decoration: InputDecoration(
                      hintText: l10n.kajianSearchCity,
                      prefixIcon: Icon(Icons.search_rounded, size: 20),
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                      ),
                    ),
                    onChanged: (v) => setSheet(() => kotaQuery = v.trim()),
                  ),
                  const SizedBox(height: 8),
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: cities.length,
                      itemBuilder: (_, i) => RadioListTile<String>(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        value: cities[i],
                        groupValue: kota,
                        title: Text(cities[i]),
                        onChanged: (v) =>
                            setSheet(() => kota = v ?? 'Semua'),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(l10n.kajianApply),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    if (!mounted) return;
    final kotaChanged = kota != _kota;
    setState(() {
      _dateMode = dateMode;
      _sortMode = sortMode;
    });
    if (kotaChanged) await _setKota(kota);
  }

  Future<void> _openDetail(KajianInfo k) async {
    final scheme = Theme.of(context).colorScheme;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => SafeArea(
          top: false,
          child: LiquidGlassCard(
            radius: 24,
            margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            padding: EdgeInsets.zero,
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 22),
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: scheme.onSurface.withValues(alpha: .25),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: _thumbnail(k, fit: BoxFit.cover),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  k.tema,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                if (k.pemateri.isNotEmpty)
                  Text(
                    k.pemateri,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: scheme.primary,
                    ),
                  ),
                const SizedBox(height: 10),
                _detailRow(
                  scheme,
                  Icons.calendar_month_rounded,
                  [k.tanggal, k.waktu].where((s) => s.isNotEmpty).join(' • '),
                ),
                if (k.lokasi.isNotEmpty)
                  _detailRow(scheme, Icons.location_on_outlined, k.lokasi),
                if (k.penyelenggara.isNotEmpty)
                  _detailRow(
                    scheme,
                    Icons.groups_outlined,
                    k.penyelenggara,
                  ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: k.sourceUrl.isEmpty
                        ? null
                        : () => _openTelegram(k.sourceUrl),
                    icon: const Icon(Icons.send_rounded, size: 18),
                    label: Text(AppLocalizations.of(context)!.kajianOpenTelegram),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _detailRow(ColorScheme scheme, IconData icon, String text) {
    if (text.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: scheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openTelegram(String url) async {
    try {
      final uri = Uri.parse(url);
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  /// Thumbnail with progress + designed fallback (never empty).
  Widget _thumbnail(KajianInfo k, {BoxFit fit = BoxFit.cover}) {
    final scheme = Theme.of(context).colorScheme;
    if (!k.hasImage) return _thumbFallback(k);
    return Image.network(
      k.imageUrl,
      fit: fit,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        final v = progress.expectedTotalBytes == null
            ? null
            : progress.cumulativeBytesLoaded /
                  (progress.expectedTotalBytes ?? 1);
        return Container(
          color: scheme.surfaceContainerHighest,
          child: Center(
            child: SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                value: v,
                strokeWidth: 3,
                color: scheme.primary,
              ),
            ),
          ),
        );
      },
      errorBuilder: (_, _, _) => _thumbFallback(k),
    );
  }

  /// Designed fallback: deep-green gradient + mosque glyph + tema initial.
  Widget _thumbFallback(KajianInfo k) {
    final scheme = Theme.of(context).colorScheme;
    final initial = k.tema.trim().isEmpty
        ? 'K'
        : k.tema.trim()[0].toUpperCase();
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [scheme.primary, scheme.primary.withValues(alpha: .65)],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Icon(
            Icons.mosque_rounded,
            size: 64,
            color: scheme.onPrimary.withValues(alpha: .28),
          ),
          Center(
            child: Text(
              initial,
              style: TextStyle(
                fontSize: 44,
                fontWeight: FontWeight.w800,
                color: scheme.onPrimary,
              ),
            ),
          ),
          Positioned(
            right: 10,
            bottom: 8,
            child: Text(
              'EQURAN.ID',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: scheme.onPrimary.withValues(alpha: .75),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final items = _visible;
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        titleSpacing: 20,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.of(context)!.kajianTitle,
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 25),
            ),
            Text(
              AppLocalizations.of(context)!.kajianSubtitle,
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                tooltip: AppLocalizations.of(context)!.kajianFilter,
                onPressed: _openFilterSheet,
                icon: const Icon(Icons.tune_rounded),
              ),
              if (_activeFilterCount > 0)
                Positioned(
                  right: 10,
                  top: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.primary,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      '${_activeFilterCount}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: scheme.onPrimary,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _query = v.trim()),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: context.l10n.kajianSearchHint,
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: scheme.primary,
                  size: 24,
                ),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Bersihkan',
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _query = '');
                        },
                        icon: const Icon(Icons.close_rounded),
                      ),
              ),
            ),
          ),
        ),
      ),
      body: _loading && _items.isEmpty
          ? ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 130),
              itemCount: 4,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (_, _) => LiquidGlassCard(
                radius: 20,
                padding: EdgeInsets.zero,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AspectRatio(
                      aspectRatio: 16 / 9,
                      child: Container(
                        color: scheme.surfaceContainerHighest,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      height: 16,
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      margin: const EdgeInsets.fromLTRB(16, 0, 80, 16),
                      height: 12,
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : _offline
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: LiquidGlassCard(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.wifi_off_rounded,
                        size: 46,
                        color: scheme.primary,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        context.l10n.kajianNoConnection,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        context.l10n.kajianOfflineHint,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 14),
                      FilledButton(
                        onPressed: _refresh,
                        child: Text(context.l10n.actionRetry),
                      ),
                    ],
                  ),
                ),
              ),
            )
          : RefreshIndicator(
              color: scheme.primary,
              onRefresh: _refresh,
              child: CustomScrollView(
                controller: _scroll,
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _loading
                                  ? 'Memuat…'
                                  : '${items.length} kajian${_kota == 'Semua' ? '' : ' • $_kota'}',
                              style: Theme.of(context).textTheme.labelLarge
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                          ),
                          if (_hasActiveFilters)
                            TextButton(
                              onPressed: _resetFilters,
                              child: Text(AppLocalizations.of(context)!.kajianReset),
                            ),
                        ],
                      ),
                    ),
                  ),
                  if (_hasActiveFilters)
                    SliverToBoxAdapter(
                      child: SizedBox(
                        height: 40,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
                          children: [
                            if (_kota != 'Semua')
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: Chip(
                                  label: Text(_kota),
                                  deleteIcon: const Icon(Icons.close, size: 16),
                                  onDeleted: () => _setKota('Semua'),
                                ),
                              ),
                            if (_dateMode != 'semua')
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: Chip(
                                  label: Text(
                                    (_dateMode == 'semua' ? AppLocalizations.of(context)!.kajianAllTime : _dateMode == 'hariIni' ? AppLocalizations.of(context)!.kajianToday : _dateMode == 'tujuhHari' ? AppLocalizations.of(context)!.kajianNext7Days : AppLocalizations.of(context)!.kajianNext30Days),
                                  ),
                                  deleteIcon: const Icon(Icons.close, size: 16),
                                  onDeleted: () => setState(
                                    () => _dateMode = 'semua',
                                  ),
                                ),
                              ),
                            if (_sortMode != 'terdekat')
                              Chip(
                                label: Text(
                                  (_sortMode == 'terdekat' ? AppLocalizations.of(context)!.kajianSortNearest : AppLocalizations.of(context)!.kajianSortNewest),
                                ),
                                deleteIcon: const Icon(Icons.close, size: 16),
                                onDeleted: () => setState(
                                  () => _sortMode = 'terdekat',
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  if (items.isEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(28),
                        child: LiquidGlassCard(
                          padding: const EdgeInsets.all(24),
                          child: Center(
                            child: Text(AppLocalizations.of(context)!.kajianNoResults),
                          ),
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 130),
                      sliver: SliverList.separated(
                        itemCount: items.length + (_hasMore ? 1 : 0),
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: 12),
                        itemBuilder: (_, i) {
                          if (i >= items.length) {
                            return Center(
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: _loadingMore
                                    ? CircularProgressIndicator(
                                        color: scheme.primary,
                                      )
                                    : const SizedBox.shrink(),
                              ),
                            );
                          }
                          return _kajianCard(items[i]);
                        },
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _kajianCard(KajianInfo k) {
    final scheme = Theme.of(context).colorScheme;
    return LiquidGlassCard(
      radius: 20,
      padding: EdgeInsets.zero,
      onTap: () => _openDetail(k),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: _thumbnail(k),
                ),
              ),
              if (k.tanggal.isNotEmpty)
                Positioned(
                  left: 12,
                  bottom: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.surface.withValues(alpha: .92),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      k.tanggal,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: scheme.primary,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text(
              k.tema.isNotEmpty ? k.tema : context.l10n.kajianFallbackTopic,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          if (k.pemateri.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: Text(
                k.pemateri,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: scheme.primary,
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                Icon(
                  Icons.location_on_outlined,
                  size: 14,
                  color: scheme.onSurface.withValues(alpha: .72),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    [
                      if (k.lokasi.isNotEmpty) k.lokasi,
                      if (k.kota.isNotEmpty) k.kota,
                      if (k.waktu.isNotEmpty) k.waktu,
                    ].join(' • '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurface.withValues(alpha: .72),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
