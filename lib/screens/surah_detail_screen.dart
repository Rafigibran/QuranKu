import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:google_fonts/google_fonts.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../models/ayah.dart';
import '../models/surah.dart';
import '../services/api_service.dart';
import '../services/settings_service.dart';
import '../widgets/liquid_glass.dart';

class SurahDetailScreen extends StatefulWidget {
  final Surah surah;

  const SurahDetailScreen({super.key, required this.surah});

  @override
  State<SurahDetailScreen> createState() => _SurahDetailScreenState();
}

class _SurahDetailScreenState extends State<SurahDetailScreen> {
  final SettingsService _settings = SettingsService();
  final ItemScrollController _scroll = ItemScrollController();
  final TextEditingController _ayahInput = TextEditingController();

  late Future<List<Ayah>> _future;
  bool _showArabic = true;
  bool _showTranslation = true;
  late String _edition;
  List<String> _editions = ['id-indonesian', 'en-sahih'];

  @override
  void initState() {
    super.initState();
    _edition = _settings.defaultTranslation;
    _settings.addListener(_onSettingsChanged);
    _future = _load();
    _loadEditions();
  }

  @override
  void dispose() {
    _settings.removeListener(_onSettingsChanged);
    _ayahInput.dispose();
    super.dispose();
  }

  void _onSettingsChanged() {
    if (_edition != _settings.defaultTranslation && mounted) {
      setState(() {
        _edition = _settings.defaultTranslation;
        _future = _load();
      });
    }
  }

  Future<List<Ayah>> _load() async {
    return ApiService().fetchSurahDetails(widget.surah.number, edition: _edition);
  }

  Future<void> _loadEditions() async {
    try {
      final raw = await rootBundle.loadString('assets/editions.json');
      final data = json.decode(raw) as Map<String, dynamic>;
      final all = (data['editions'] as List<dynamic>).cast<String>();
      final values = <String>['id-indonesian', 'en-sahih', ...all];
      values.removeWhere((value) => value == 'arabic');
      _editions = values.toSet().toList();
      if (mounted) setState(() {});
    } catch (_) {
      // Keep the two reliable defaults.
    }
  }

  String _editionName(String id) {
    if (id == 'id-indonesian') return 'Bahasa Indonesia';
    if (id == 'en-sahih') return 'English • Sahih International';
    return id
        .split('-')
        .where((e) => e.isNotEmpty)
        .map((e) => '${e[0].toUpperCase()}${e.substring(1)}')
        .join(' ');
  }

  void _jumpToAyah(String value) {
    final target = int.tryParse(value);
    if (target == null || target < 1 || target > widget.surah.totalAyahs) return;
    _scroll.jumpTo(index: target);
    Navigator.pop(context);
  }

  Future<void> _openSettings() async {
    final scheme = Theme.of(context).colorScheme;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              top: false,
              child: Container(
                decoration: BoxDecoration(
                  color: scheme.surface.withValues(alpha: .98),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                ),
                padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).viewInsets.bottom + 22),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(child: Container(width: 42, height: 4, decoration: BoxDecoration(color: scheme.outline, borderRadius: BorderRadius.circular(99)))),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(child: Text('Tampilan bacaan', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800))),
                          IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Text('Loncat ke ayat', style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800, color: scheme.onSurface.withValues(alpha: .60))),
                      const SizedBox(height: 8),
                      LiquidGlassCard(
                        radius: 18,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                        child: Row(
                          children: [
                            Expanded(child: TextField(controller: _ayahInput, keyboardType: TextInputType.number, decoration: InputDecoration(hintText: '1 - ${widget.surah.totalAyahs}', border: InputBorder.none), onSubmitted: (_) => _jumpToAyah(_ayahInput.text))),
                            IconButton(onPressed: () => _jumpToAyah(_ayahInput.text), icon: Icon(Icons.arrow_forward_rounded, color: scheme.primary)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 22),
                      Text('Yang ditampilkan', style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800, color: scheme.onSurface.withValues(alpha: .60))),
                      const SizedBox(height: 8),
                      LiquidGlassCard(
                        radius: 20,
                        padding: EdgeInsets.zero,
                        child: Column(
                          children: [
                            SwitchListTile.adaptive(title: const Text('Teks Arab'), subtitle: const Text('Tampilkan tulisan Arab yang lebih besar'), value: _showArabic, onChanged: (value) { setState(() => _showArabic = value); setSheetState(() {}); }),
                            Divider(height: 1, color: scheme.outline.withValues(alpha: .35)),
                            SwitchListTile.adaptive(title: const Text('Terjemahan'), subtitle: const Text('Tampilkan terjemahan di bawah ayat'), value: _showTranslation, onChanged: (value) { setState(() => _showTranslation = value); setSheetState(() {}); }),
                          ],
                        ),
                      ),
                      const SizedBox(height: 22),
                      Text('Terjemahan', style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800, color: scheme.onSurface.withValues(alpha: .60))),
                      const SizedBox(height: 8),
                      LiquidGlassCard(
                        radius: 20,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _editions.contains(_edition) ? _edition : _editions.first,
                            isExpanded: true,
                            icon: Icon(Icons.expand_more_rounded, color: scheme.primary),
                            items: _editions.map((id) => DropdownMenuItem(value: id, child: Text(_editionName(id), overflow: TextOverflow.ellipsis))).toList(),
                            onChanged: (value) {
                              if (value == null) return;
                              setState(() {
                                _edition = value;
                                _future = _load();
                              });
                              setSheetState(() {});
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: FutureBuilder<List<Ayah>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator(color: scheme.primary));
            }
            if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
              return _errorState();
            }

            final ayahs = snapshot.data!;
            return CustomScrollView(
              slivers: [
                SliverAppBar(
                  pinned: true,
                  toolbarHeight: 66,
                  backgroundColor: Colors.transparent,
                  scrolledUnderElevation: 0,
                  leading: const BackButton(),
                  title: Text(widget.surah.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                  centerTitle: true,
                  actions: [Padding(padding: const EdgeInsets.only(right: 10), child: LiquidGlassIconButton(icon: Icons.tune_rounded, onPressed: _openSettings, tooltip: 'Pengaturan bacaan'))],
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
                    child: LiquidGlassCard(
                      radius: 28,
                      padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.surah.name, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -1)),
                          const SizedBox(height: 3),
                          Text(widget.surah.nameAr, style: GoogleFonts.amiri(fontSize: 24, color: scheme.primary)),
                          const SizedBox(height: 10),
                          Wrap(spacing: 8, runSpacing: 8, children: [
                            _InfoChip(label: widget.surah.type),
                            _InfoChip(label: '${_settings.formatNumber(widget.surah.totalAyahs)} ayat'),
                            _InfoChip(label: _editionName(_edition)),
                          ]),
                        ],
                      ),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
                  sliver: SliverList.separated(
                    itemCount: ayahs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) => _ayahCard(ayahs[index]),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _ayahCard(Ayah ayah) {
    final scheme = Theme.of(context).colorScheme;
    return LiquidGlassCard(
      radius: 24,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(width: 38, height: 38, decoration: BoxDecoration(shape: BoxShape.circle, color: scheme.primary.withValues(alpha: .10), border: Border.all(color: scheme.primary.withValues(alpha: .25))), child: Center(child: Text(_settings.formatNumber(ayah.number), style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800, color: scheme.primary)))),
              const Spacer(),
              Icon(Icons.volume_up_outlined, size: 20, color: scheme.onSurface.withValues(alpha: .42)),
            ],
          ),
          if (_showArabic) ...[
            const SizedBox(height: 14),
            Text(ayah.arabic, textAlign: TextAlign.right, style: GoogleFonts.amiri(fontSize: 28, height: 2.0, color: scheme.onSurface)),
          ],
          if (_showTranslation && ayah.translation.isNotEmpty) ...[
            const SizedBox(height: 13),
            Container(
              padding: const EdgeInsets.only(top: 12),
              decoration: BoxDecoration(border: Border(top: BorderSide(color: scheme.outline.withValues(alpha: .30)))),
              child: Text(ayah.translation, style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.55, color: scheme.onSurface.withValues(alpha: .70))),
            ),
          ],
        ],
      ),
    );
  }

  Widget _errorState() {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: LiquidGlassCard(
          radius: 24,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.wifi_off_rounded, color: scheme.primary, size: 42),
              const SizedBox(height: 14),
              Text('Ayat belum dapat dimuat', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text('Periksa koneksi internet lalu coba lagi.', textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onSurface.withValues(alpha: .62))),
              const SizedBox(height: 18),
              FilledButton.icon(onPressed: () => setState(() => _future = _load()), icon: const Icon(Icons.refresh_rounded), label: const Text('Coba lagi')),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return LiquidGlassPill(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      child: Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700)),
    );
  }
}
