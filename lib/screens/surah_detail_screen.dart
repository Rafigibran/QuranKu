import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show rootBundle, Clipboard, ClipboardData;
import 'package:google_fonts/google_fonts.dart';

import '../models/ayah.dart';
import '../models/juz.dart';
import '../models/surah.dart';
import '../l10n/l10n.dart';
import '../services/api_service.dart';
import '../services/audio_service.dart' as quran_audio;
import '../services/khatam_service.dart';
import '../services/settings_service.dart';
import '../services/tafsir_service.dart';
import '../utils/tajwid.dart';
import '../widgets/liquid_glass.dart';

class SurahDetailScreen extends StatefulWidget {
  final Surah surah;
  final int? initialAyah;

  const SurahDetailScreen({super.key, required this.surah, this.initialAyah});

  @override
  State<SurahDetailScreen> createState() => _SurahDetailScreenState();
}

class _SurahDetailScreenState extends State<SurahDetailScreen> {
  final SettingsService _settings = SettingsService();
  final KhatamService _khatam = KhatamService();
  final quran_audio.AudioService _audio = quran_audio.AudioService();
  final ScrollController _scroll = ScrollController();
  final TextEditingController _ayahInput = TextEditingController();
  final TextEditingController _searchInput = TextEditingController();

  late Future<List<Ayah>> _future;
  late String _edition;
  List<String> _editions = ['id-indonesian', 'en-sahih'];
  String _searchQuery = '';
  int? _highlightedAyah;
  // Per-ayah GlobalKeys for accurate jump without magic numbers
  final Map<int, GlobalKey> _ayahKeys = {};
  bool _autoFollow = false;
  bool _showPeekFooter = false;
  bool _legendExpanded = false;
  double _readProgress = 0;
  List<Surah> _allSurahsCache = [];

  // showTransliteration accessed via _settings.showTransliteration directly

  @override
  void initState() {
    super.initState();
    _edition = _settings.defaultTranslation;
    _settings.addListener(_onSettingsChanged);
    _audio.addListener(_onAudioTick);
    _scroll.addListener(_onScroll);
    _future = _load();
    _loadEditions();
    _loadAllSurahs();
    if (_settings.showTajwid) {
      _loadTajweed();
      // Deterministic second trigger once ayahs finish loading:
      // if the first attempt raced init or failed silently, retry here.
      _future
          .then((_) {
            if (mounted && _settings.showTajwid && _tajweedTagged.isEmpty)
              _loadTajweed();
          })
          .catchError((_) {});
    }
    if (widget.initialAyah != null) {
      _future.then((_) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _jumpToAyahDirect(widget.initialAyah!),
        );
      });
    }
  }

  Future<void> _loadAllSurahs() async {
    try {
      _allSurahsCache = await ApiService().fetchSurahs();
      if (mounted) setState(() {});
    } catch (_) {}
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final max = _scroll.position.maxScrollExtent;
    final offset = _scroll.position.pixels;
    final progress = max <= 0 ? 0 : (offset / max).clamp(0.0, 1.0);
    if ((progress - _readProgress).abs() > 0.02) {
      setState(() => _readProgress = progress.toDouble());
    }
    final nearEnd = max - offset < 420;
    if (nearEnd != _showPeekFooter && _searchQuery.isEmpty) {
      setState(() => _showPeekFooter = nearEnd);
    }
    // Disable auto-follow on manual drag
    if (_autoFollow && _scroll.position.isScrollingNotifier.value) {
      // if user drags, keep follow but allow interrupt via notification else
    }
  }

  void _onAudioTick() {
    if (!_autoFollow ||
        !_audio.isPlaying ||
        _audio.currentSurah?.number != widget.surah.number)
      return;
    final ayah = _audio.currentAyah;
    final key = _ayahKeys[ayah];
    if (key?.currentContext != null) {
      final reduceMotion = MediaQuery.disableAnimationsOf(context);
      Scrollable.ensureVisible(
        key!.currentContext!,
        duration: reduceMotion
            ? Duration.zero
            : const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
        alignment: 0.15,
      );
      setState(() => _highlightedAyah = ayah);
      Future.delayed(const Duration(milliseconds: 1200), () {
        if (mounted && _highlightedAyah == ayah)
          setState(() => _highlightedAyah = null);
      });
    }
  }

  @override
  void dispose() {
    _settings.removeListener(_onSettingsChanged);
    _audio.removeListener(_onAudioTick);
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    _ayahInput.dispose();
    _searchInput.dispose();
    super.dispose();
  }

  void _onSettingsChanged() {
    if (!mounted) return;
    bool needReload = false;
    if (_edition != _settings.defaultTranslation) {
      _edition = _settings.defaultTranslation;
      needReload = true;
    }
    // Transliteration or font scale changes affect display, edition change needs reload
    setState(() {
      if (needReload) _future = _load();
    });
    if (_settings.showTajwid && _tajweedTagged.isEmpty) _loadTajweed();
  }

  Future<List<Ayah>> _load() async {
    final translit = _settings.showTransliteration
        ? _settings.transliterationEdition
        : null;
    return ApiService().fetchSurahDetails(
      widget.surah.number,
      edition: _edition,
      transliterationEdition: translit,
    );
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
    } catch (_) {}
  }

  String _editionName(String id) {
    if (id == 'id-indonesian') return context.l10n.settingsLanguageIndonesian;
    if (id == 'en-sahih') return 'English • Sahih International';
    return id
        .split('-')
        .where((e) => e.isNotEmpty)
        .map((e) => '${e[0].toUpperCase()}${e.substring(1)}')
        .join(' ');
  }

  void _jumpToAyah(String value) {
    final target = int.tryParse(value);
    if (target == null || target < 1 || target > widget.surah.totalAyahs) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.readerAyahRange(widget.surah.totalAyahs)),
        ),
      );
      return;
    }
    Navigator.pop(context);
    _jumpToAyahDirect(target);
  }

  void _jumpToAyahDirect(int target, {int attempts = 0}) {
    if (target < 1) return;
    final total = widget.surah.totalAyahs;
    if (total > 0 && target > total) return;
    Future.delayed(const Duration(milliseconds: 150), () {
      if (!mounted) return;
      final key = _ayahKeys[target];
      if (key?.currentContext != null) {
        Scrollable.ensureVisible(
          key!.currentContext!,
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeOutCubic,
          alignment: 0.05,
        );
        setState(() => _highlightedAyah = target);
        Future.delayed(const Duration(milliseconds: 1800), () {
          if (mounted) setState(() => _highlightedAyah = null);
        });
        _settings.setLastRead(widget.surah.number, target);
      } else if (attempts < 12 && _scroll.hasClients) {
        // Target ayat belum ter-layout (lazy slivers): lompat bertahap agar
        // item ter-materialisasi, lalu bidik ulang. Dibatasi 12x agar aman.
        final pos = _scroll.position;
        final max = pos.maxScrollExtent;
        final est = total <= 0 || max <= 0
            ? max
            : (target / total) * (max + 2000);
        _scroll
            .animateTo(
              est.clamp(0.0, max),
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
            )
            .then((_) {
              if (mounted) _jumpToAyahDirect(target, attempts: attempts + 1);
            });
      }
    });
  }

  /// Expandable Kemenag surah description (equran.id v2, cached).
  Widget _surahDescription(ColorScheme scheme) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: EdgeInsets.zero,
        leading: Icon(
          Icons.info_outline_rounded,
          size: 18,
          color: scheme.primary,
        ),
        title: Text(
          context.l10n.readerAboutSurah,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: scheme.primary,
          ),
        ),
        children: [
          FutureBuilder<String>(
            future: ApiService().fetchSurahDescription(widget.surah.number),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: LinearProgressIndicator(color: scheme.primary),
                );
              }
              final desc = snapshot.data ?? '';
              if (desc.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(context.l10n.readerDescriptionOffline),
                );
              }
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: SelectableText(
                  desc,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    height: 1.6,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  /// Per-ayah tafsir in a bottom sheet, using the edition picked in Settings.
  Future<void> _openTafsir(Ayah ayah) async {
    final scheme = Theme.of(context).colorScheme;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.94,
        expand: false,
        builder: (context, scrollController) => SafeArea(
          top: false,
          child: LiquidGlassCard(
            radius: 24,
            margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
            child: _TafsirSheet(
              surah: widget.surah,
              ayah: ayah,
              editionId: _settings.tafsirEditionId,
              scrollController: scrollController,
              indicatorColor: scheme.onSurface.withValues(alpha: .25),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _copyAyah(Ayah ayah) async {    final buf = StringBuffer();
    buf.writeln(
      '${widget.surah.name} — QS ${widget.surah.number}:${ayah.number}',
    );
    buf.writeln(ayah.arabic);
    if (ayah.transliteration.isNotEmpty) buf.writeln(ayah.transliteration);
    if (ayah.translation.isNotEmpty) buf.writeln(ayah.translation);
    await Clipboard.setData(ClipboardData(text: buf.toString()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.l10n.readerAyahCopied),
        behavior: SnackBarBehavior.floating,
      ),
    );
    _settings.setLastRead(widget.surah.number, ayah.number);
  }

  void _toggleBookmark(Ayah ayah) {
    _settings.toggleBookmark(widget.surah.number, ayah.number);
  }

  Future<void> _toggleRead(Ayah ayah) async {
    final wasRead = _settings.isRead(widget.surah.number, ayah.number);
    await _settings.toggleRead(widget.surah.number, ayah.number);
    if (!mounted) return;
    setState(() {});
    if (wasRead) return;
    // Newly marked as read: update last-read + feed active khatam target.
    _settings.setLastRead(widget.surah.number, ayah.number);
    if (!_khatam.hasActive) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.readerMarkedRead(widget.surah.number, ayah.number),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    try {
      await _khatam.init();
      await _khatam.logReading(
        toSurah: widget.surah.number,
        toAyah: ayah.number,
        surahs: _allSurahsCache.isNotEmpty ? _allSurahsCache : null,
      );
      if (!mounted) return;
      final done = !_khatam.hasActive;
      final l = context.l10n;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            done
                ? l.readerKhatamComplete
                : l.readerMarkedReadKhatam(
                    widget.surah.number,
                    ayah.number,
                  ),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      setState(() {});
    } catch (_) {
      // Behind khatam position or invalid: keep local checkmark only.
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.readerMarkedRead(widget.surah.number, ayah.number),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Surah? _getNextSurah() {
    if (_allSurahsCache.isEmpty) {
      if (widget.surah.number < 114) {
        // Fallback minimal
        return Surah(
          number: widget.surah.number + 1,
          name: 'Surah ${widget.surah.number + 1}',
          nameAr: '',
          type: '',
          totalAyahs: 0,
        );
      }
      return null;
    }
    final idx = _allSurahsCache.indexWhere(
      (s) => s.number == widget.surah.number,
    );
    if (idx >= 0 && idx + 1 < _allSurahsCache.length)
      return _allSurahsCache[idx + 1];
    return null;
  }

  Surah? _getPrevSurah() {
    if (_allSurahsCache.isEmpty) {
      if (widget.surah.number > 1)
        return Surah(
          number: widget.surah.number - 1,
          name: 'Surah ${widget.surah.number - 1}',
          nameAr: '',
          type: '',
          totalAyahs: 0,
        );
      return null;
    }
    final idx = _allSurahsCache.indexWhere(
      (s) => s.number == widget.surah.number,
    );
    if (idx > 0) return _allSurahsCache[idx - 1];
    return null;
  }

  void _goToSurah(Surah next) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => SurahDetailScreen(surah: next)),
    );
  }

  Future<void> _openSettings() async {
    final scheme = Theme.of(context).colorScheme;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setSheetState) => SafeArea(
            top: false,
            child: Container(
              decoration: BoxDecoration(
                color: scheme.surface.withValues(alpha: .98),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(30),
                ),
              ),
              padding: EdgeInsets.fromLTRB(
                20,
                12,
                20,
                MediaQuery.of(context).viewInsets.bottom + 22,
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 42,
                        height: 4,
                        decoration: BoxDecoration(
                          color: scheme.outline,
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            context.l10n.readerReadingDisplay,
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Text(
                      context.l10n.readerJumpToAyah,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: scheme.onSurface.withValues(alpha: .72),
                      ),
                    ),
                    const SizedBox(height: 8),
                    LiquidGlassCard(
                      radius: 18,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 2,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _ayahInput,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                hintText: '1 - ${widget.surah.totalAyahs}',
                                border: InputBorder.none,
                              ),
                              onSubmitted: (_) => _jumpToAyah(_ayahInput.text),
                            ),
                          ),
                          IconButton(
                            onPressed: () => _jumpToAyah(_ayahInput.text),
                            icon: Icon(
                              Icons.arrow_forward_rounded,
                              color: scheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    Text(
                      context.l10n.readerShown,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: scheme.onSurface.withValues(alpha: .72),
                      ),
                    ),
                    const SizedBox(height: 8),
                    LiquidGlassCard(
                      radius: 20,
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          SwitchListTile.adaptive(
                            title: Text(context.l10n.readerShowArabic),
                            subtitle: Text(
                              context.l10n.readerShowArabicSubtitle,
                            ),
                            value: _settings.showArabic,
                            onChanged: (v) {
                              _settings.setShowArabic(v);
                              setSheetState(() {});
                              setState(() {});
                            },
                          ),
                          Divider(
                            height: 1,
                            color: scheme.outline.withValues(alpha: .35),
                          ),
                          SwitchListTile.adaptive(
                            title: Text(context.l10n.readerShowLatin),
                            subtitle: Text(
                              _settings.transliterationName(
                                _settings.transliterationEdition,
                              ),
                            ),
                            value: _settings.showTransliteration,
                            onChanged: (v) {
                              _settings.setShowTransliteration(v);
                              setState(() {
                                _future = _load();
                              });
                              setSheetState(() {});
                            },
                          ),
                          Divider(
                            height: 1,
                            color: scheme.outline.withValues(alpha: .35),
                          ),
                          SwitchListTile.adaptive(
                            title: Text(context.l10n.readerShowTranslation),
                            subtitle: Text(
                              context.l10n.readerShowTranslationSubtitle,
                            ),
                            value: _settings.showTranslation,
                            onChanged: (v) {
                              _settings.setShowTranslation(v);
                              setSheetState(() {});
                              setState(() {});
                            },
                          ),
                          Divider(
                            height: 1,
                            color: scheme.outline.withValues(alpha: .35),
                          ),
                          SwitchListTile.adaptive(
                            title: Text(context.l10n.settingsTajwid),
                            subtitle: Text(context.l10n.readerTajwidVerified),
                            value: _settings.showTajwid,
                            onChanged: (v) {
                              _settings.setShowTajwid(v);
                              setSheetState(() {});
                              setState(() {});
                              if (v) _loadTajweed(force: true);
                            },
                          ),
                        ],
                      ),
                    ),
                    if (_settings.showTajwid)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: LiquidGlassCard(
                          radius: 14,
                          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                context.l10n.readerTajwidLegend,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: scheme.onSurface.withValues(
                                    alpha: .72,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                children: [
                                  _tajwidLegend(
                                    'Ghunnah',
                                    TajwidPalette.ghunnah,
                                  ),
                                  _tajwidLegend(
                                    'Qalqalah',
                                    TajwidPalette.qalqalah,
                                  ),
                                  _tajwidLegend('Mad', TajwidPalette.mad),
                                  _tajwidLegend('Ikhfa', TajwidPalette.ikhfa),
                                  _tajwidLegend('Idgham', TajwidPalette.idgham),
                                  _tajwidLegend('Iqlab', TajwidPalette.iqlab),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (_settings.showTransliteration) ...[
                      const SizedBox(height: 12),
                      LiquidGlassCard(
                        radius: 18,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 4,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                context.l10n.settingsLatinType,
                                style: Theme.of(context).textTheme.labelLarge,
                              ),
                            ),
                            DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _settings.transliterationEdition,
                                items: _settings
                                    .getTransliterationEditions()
                                    .map(
                                      (m) => DropdownMenuItem(
                                        value: m['code'],
                                        child: Text(
                                          m['name']!,
                                          style: const TextStyle(fontSize: 13),
                                        ),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (v) {
                                  if (v == null) return;
                                  _settings.setTransliterationEdition(v);
                                  setState(() {
                                    _future = _load();
                                  });
                                  setSheetState(() {});
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 22),
                    Text(
                      context.l10n.settingsFontSize,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: scheme.onSurface.withValues(alpha: .72),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _fontSlider(
                      context.l10n.readerFontArabic,
                      _settings.arabicFontScale,
                      0.85,
                      1.4,
                      (v) => _settings.setArabicFontScale(v),
                      setSheetState,
                    ),
                    _fontSlider(
                      'Latin',
                      _settings.transliterationFontScale,
                      0.85,
                      1.3,
                      (v) => _settings.setTransliterationFontScale(v),
                      setSheetState,
                    ),
                    _fontSlider(
                      context.l10n.readerShowTranslation,
                      _settings.translationFontScale,
                      0.85,
                      1.3,
                      (v) => _settings.setTranslationFontScale(v),
                      setSheetState,
                    ),
                    const SizedBox(height: 22),
                    Text(
                      context.l10n.readerShowTranslation,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: scheme.onSurface.withValues(alpha: .72),
                      ),
                    ),
                    const SizedBox(height: 8),
                    LiquidGlassCard(
                      radius: 20,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 2,
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _editions.contains(_edition)
                              ? _edition
                              : _editions.first,
                          isExpanded: true,
                          icon: Icon(
                            Icons.expand_more_rounded,
                            color: scheme.primary,
                          ),
                          items: _editions
                              .map(
                                (id) => DropdownMenuItem(
                                  value: id,
                                  child: Text(
                                    _editionName(id),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value == null) return;
                            _settings.setDefaultTranslation(value);
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
          ),
        );
      },
    );
  }

  Widget _fontSlider(
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged,
    StateSetter setSheetState,
  ) {
    final scheme = Theme.of(context).colorScheme;
    return LiquidGlassCard(
      radius: 18,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 86,
            child: Text(label, style: Theme.of(context).textTheme.labelLarge),
          ),
          Expanded(
            child: Slider(
              value: value,
              min: min,
              max: max,
              divisions: 6,
              label: '${(value * 100).round()}%',
              activeColor: scheme.primary,
              onChanged: (v) {
                onChanged(v);
                setSheetState(() {});
                setState(() {});
              },
            ),
          ),
          SizedBox(
            width: 44,
            child: Text(
              '${(value * 100).round()}%',
              textAlign: TextAlign.end,
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ),
        ],
      ),
    );
  }

  /// Floating tajwid legend: always visible while reading with colors on,
  /// collapsed to one pill; tap expands the 7 rules. No settings trip needed.
  Widget _tajwidLegendBar(ColorScheme scheme) {
    return Positioned(
      left: 16,
      right: 16,
      bottom: 16,
      child: LiquidGlassCard(
        radius: 18,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        onTap: () => setState(() => _legendExpanded = !_legendExpanded),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.palette_outlined,
                  size: 16,
                  color: scheme.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  context.l10n.readerTajwidLegend,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: scheme.onSurface,
                  ),
                ),
                const Spacer(),
                Icon(
                  _legendExpanded
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                  size: 20,
                  color: scheme.onSurfaceVariant,
                ),
              ],
            ),
            if (_legendExpanded) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _tajwidLegend('Ghunnah', TajwidPalette.ghunnah),
                  _tajwidLegend('Qalqalah', TajwidPalette.qalqalah),
                  _tajwidLegend('Mad', TajwidPalette.mad),
                  _tajwidLegend('Ikhfa', TajwidPalette.ikhfa),
                  _tajwidLegend('Idgham', TajwidPalette.idgham),
                  _tajwidLegend('Iqlab', TajwidPalette.iqlab),
                  _tajwidLegend('Hamzah', TajwidPalette.hamz),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _tajwidLegend(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withValues(alpha: .28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final nextSurah = _getNextSurah();
    final prevSurah = _getPrevSurah();
    return Scaffold(
      floatingActionButton: _audio.isPlaying
          ? FloatingActionButton.small(
              onPressed: () => setState(() => _autoFollow = !_autoFollow),
              backgroundColor: _autoFollow
                  ? scheme.primary
                  : scheme.surfaceContainerHighest,
              foregroundColor: _autoFollow
                  ? scheme.onPrimary
                  : scheme.onSurface,
              tooltip: _autoFollow
                  ? context.l10n.readerUnfollowMurotal
                  : context.l10n.readerFollowMurotal,
              child: Icon(
                _autoFollow
                    ? Icons.sync_rounded
                    : Icons.spatial_tracking_outlined,
                size: 18,
              ),
            )
          : null,
      body: SafeArea(
        bottom: false,
        child: FutureBuilder<List<Ayah>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(
                child: CircularProgressIndicator(color: scheme.primary),
              );
            }
            if (snapshot.hasError ||
                !snapshot.hasData ||
                snapshot.data!.isEmpty) {
              return _errorState();
            }
            final allAyahs = snapshot.data!;
            final ayahs = _searchQuery.isEmpty
                ? allAyahs
                : allAyahs.where((a) {
                    final q = _searchQuery.toLowerCase();
                    return a.arabic.contains(_searchQuery) ||
                        a.translation.toLowerCase().contains(q) ||
                        a.transliteration.toLowerCase().contains(q) ||
                        a.number.toString() == _searchQuery;
                  }).toList();
            // ensure keys exist
            for (final a in allAyahs) {
              _ayahKeys.putIfAbsent(a.number, () => GlobalKey());
            }
            return Stack(
              children: [
                CustomScrollView(
              controller: _scroll,
              slivers: [
                SliverAppBar(
                  pinned: true,
                  toolbarHeight: 66,
                  backgroundColor: scheme.surface,
                  scrolledUnderElevation: 0,
                  leading: const BackButton(),
                  title: Text(
                    widget.surah.name,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  centerTitle: true,
                  actions: [
                    if (prevSurah != null)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: LiquidGlassIconButton(
                          icon: Icons.chevron_left_rounded,
                          onPressed: () => _goToSurah(prevSurah),
                          tooltip: context.l10n.readerPrevSurah,
                        ),
                      ),
                    if (nextSurah != null)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: LiquidGlassIconButton(
                          icon: Icons.chevron_right_rounded,
                          onPressed: () => _goToSurah(nextSurah),
                          tooltip: context.l10n.readerNextSurah,
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: LiquidGlassIconButton(
                        icon: Icons.tune_rounded,
                        onPressed: _openSettings,
                        tooltip: context.l10n.readerReadingSettings,
                      ),
                    ),
                  ],
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
                    child: LiquidGlassCard(
                      radius: 28,
                      padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.surah.name,
                            style: Theme.of(context).textTheme.headlineMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -1,
                                ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            widget.surah.nameAr,
                            style: GoogleFonts.amiri(
                              fontSize: 24,
                              color: scheme.primary,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _InfoChip(label: widget.surah.type),
                              _InfoChip(
                                label:
                                    '${_settings.formatNumber(widget.surah.totalAyahs)} ayat',
                              ),
                              _InfoChip(label: _editionName(_edition)),
                              if (_settings.showTransliteration)
                                _InfoChip(
                                  label:
                                      _settings.transliterationEdition ==
                                          'id-transliteration'
                                      ? 'Indonesian'
                                      : 'Latin',
                                ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          _surahDescription(scheme),
                          if (_settings.lastSurah == widget.surah.number &&
                              _settings.lastAyah != null) ...[
                            const SizedBox(height: 12),
                            InkWell(
                              onTap: () =>
                                  _jumpToAyah(_settings.lastAyah.toString()),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: scheme.primary.withValues(alpha: .10),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: scheme.primary.withValues(
                                      alpha: .22,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.bookmark_rounded,
                                      size: 16,
                                      color: scheme.primary,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      context.l10n.readerContinueReading(
                                        widget.surah.number,
                                        _settings.lastAyah ?? 1,
                                      ),
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: scheme.primary,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Icon(
                                      Icons.arrow_forward_rounded,
                                      size: 14,
                                      color: scheme.primary,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                // Reading progress — purpose: orient user in long surahs (Al-Baqarah 286)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        value: _readProgress == 0
                            ? (ayahs.isEmpty ? 0 : 0.02)
                            : _readProgress,
                        minHeight: 3,
                        backgroundColor: scheme.surfaceContainerHighest
                            .withValues(alpha: .5),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          scheme.primary,
                        ),
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
                    child: LiquidGlassCard(
                      radius: 18,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 4,
                      ),
                      child: TextField(
                        controller: _searchInput,
                        decoration: InputDecoration(
                          hintText: context.l10n.readerSearchHint,
                          border: InputBorder.none,
                          prefixIcon: const Icon(Icons.search_rounded),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear_rounded),
                                  onPressed: () {
                                    setState(() {
                                      _searchQuery = '';
                                      _searchInput.clear();
                                    });
                                  },
                                )
                              : null,
                        ),
                        onChanged: (v) =>
                            setState(() => _searchQuery = v.trim()),
                      ),
                    ),
                  ),
                ),
                if (_settings.showTajwid &&
                    (_tajweedLoading ||
                        _tajweedError != null ||
                        _tajweedTagged.isEmpty))
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(99),
                        onTap: _tajweedError != null
                            ? () => _loadTajweed(force: true)
                            : null,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color:
                                (_tajweedError != null
                                        ? scheme.error
                                        : scheme.primary)
                                    .withValues(alpha: .08),
                            borderRadius: BorderRadius.circular(99),
                            border: Border.all(
                              color:
                                  (_tajweedError != null
                                          ? scheme.error
                                          : scheme.primary)
                                      .withValues(alpha: .22),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (_tajweedLoading)
                                SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: scheme.primary,
                                  ),
                                )
                              else
                                Icon(
                                  _tajweedError != null
                                      ? Icons.refresh_rounded
                                      : Icons.palette_outlined,
                                  size: 14,
                                  color: _tajweedError != null
                                      ? scheme.error
                                      : scheme.primary,
                                ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  _tajweedLoading
                                      ? context.l10n.readerTajwidLoading
                                      : _tajweedError != null
                                      ? context.l10n.readerTajwidFailed
                                      : context.l10n.readerTajwidPreparing,
                                  style: Theme.of(context).textTheme.labelMedium
                                      ?.copyWith(
                                        color: _tajweedError != null
                                            ? scheme.error
                                            : scheme.primary,
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                if (_searchQuery.isEmpty &&
                    widget.surah.number != 1 &&
                    widget.surah.number != 9)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 2, 20, 12),
                      child: LiquidGlassCard(
                        radius: 20,
                        padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
                        child: Column(
                          children: [
                            SelectableText(
                              'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.amiri(
                                fontSize: 26 * _settings.arabicFontScale,
                                height: 2.0,
                                color: scheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                if (_searchQuery.isEmpty && widget.surah.number == 9)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 2, 20, 12),
                      child: LiquidGlassCard(
                        radius: 20,
                        padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
                        child: Column(
                          children: [
                            SelectableText(
                              'أَعُوذُ بِاللَّهِ مِنَ الشَّيْطَانِ الرَّجِيمِ',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.amiri(
                                fontSize: 24 * _settings.arabicFontScale,
                                height: 2.0,
                                color: scheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              context.l10n.readerBasmalahHint,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.labelMedium
                                  ?.copyWith(color: scheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                if (ayahs.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(28),
                      child: LiquidGlassCard(
                        radius: 20,
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          children: [
                            Icon(
                              Icons.search_off_rounded,
                              color: scheme.outline,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                context.l10n.readerNoAyahMatch(_searchQuery),
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    sliver: SliverList.separated(
                      itemCount: ayahs.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) => _ayahCard(ayahs[index]),
                    ),
                  ),
                // Peek footer — next surah CTA, appears when near end (R-31 purpose: continuity, not decoration)
                if (_searchQuery.isEmpty && nextSurah != null)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
                      child: LiquidGlassCard(
                        radius: 24,
                        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: scheme.primary.withValues(
                                      alpha: .12,
                                    ),
                                    border: Border.all(
                                      color: scheme.primary.withValues(
                                        alpha: .20,
                                      ),
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.auto_stories_rounded,
                                    color: scheme.primary,
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        context.l10n.readerSurahFinished(
                                          widget.surah.name,
                                        ),
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelLarge
                                            ?.copyWith(
                                              fontWeight: FontWeight.w800,
                                              color: scheme.onSurface
                                                  .withValues(alpha: .72),
                                            ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${context.l10n.readerContinueTo} ${nextSurah.name}'
                                        '${nextSurah.nameAr.isNotEmpty ? ' • ${nextSurah.nameAr}' : ''}'
                                        '${nextSurah.totalAyahs > 0 ? ' • ${_settings.formatString(context.l10n.commonAyahCount(nextSurah.totalAyahs))}' : ''}'
                                        ' →',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w600,
                                              color: scheme.primary,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: () => _goToSurah(nextSurah),
                                icon: const Icon(
                                  Icons.arrow_forward_rounded,
                                  size: 18,
                                ),
                                label: Text(
                                  context.l10n.readerOpenSurah(nextSurah.name),
                                ),
                                style: FilledButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Center(
                              child: Text(
                                context.l10n.readerSwipeHint,
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(color: scheme.onSurfaceVariant),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  const SliverToBoxAdapter(child: SizedBox(height: 120)),
              ],
            ),
            if (_settings.showTajwid) _tajwidLegendBar(scheme),
          ],
        );
      },
        ),
      ),
    );
  }

  Widget _ayahCard(Ayah ayah) {
    final scheme = Theme.of(context).colorScheme;
    final isHighlighted = _highlightedAyah == ayah.number;
    final isBookmarked = _settings.isBookmarked(
      widget.surah.number,
      ayah.number,
    );
    final isRead = _settings.isRead(widget.surah.number, ayah.number);
    return RepaintBoundary(
      child: Container(
        key: _ayahKeys[ayah.number],
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: isHighlighted
                ? Border.all(color: scheme.primary, width: 1.6)
                : null,
            boxShadow: isHighlighted
                ? [
                    BoxShadow(
                      color: scheme.primary.withValues(alpha: .18),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          child: LiquidGlassCard(
            radius: 24,
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: scheme.primary.withValues(alpha: .10),
                        border: Border.all(
                          color: scheme.primary.withValues(alpha: .25),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          _settings.formatNumber(ayah.number),
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: scheme.primary,
                              ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.primary.withValues(alpha: .08),
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(
                          color: scheme.primary.withValues(alpha: .18),
                        ),
                      ),
                      child: Text(
                        context.l10n.readerJuz(
                          _settings.formatNumber(
                            JuzInfo.juzOf(widget.surah.number, ayah.number),
                          ),
                        ),
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: scheme.primary,
                            ),
                      ),
                    ),
                    const Spacer(),
                    // Read checkmark + bookmark + copy — 44px tap targets per antislop-layoutmobile
                    IconButton(
                      onPressed: () => _toggleRead(ayah),
                      icon: Icon(
                        isRead
                            ? Icons.check_circle_rounded
                            : Icons.check_circle_outline_rounded,
                        color: isRead ? scheme.primary : scheme.outline,
                      ),
                      tooltip: isRead
                          ? context.l10n.readerUnmarkRead
                          : context.l10n.readerMarkRead,
                      style: IconButton.styleFrom(
                        minimumSize: const Size(44, 44),
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        _toggleBookmark(ayah);
                        setState(() {});
                      },
                      icon: Icon(
                        isBookmarked
                            ? Icons.bookmark_rounded
                            : Icons.bookmark_border_rounded,
                        color: isBookmarked ? scheme.primary : scheme.outline,
                      ),
                      tooltip: isBookmarked
                          ? context.l10n.readerRemoveBookmark
                          : context.l10n.readerBookmark,
                      style: IconButton.styleFrom(
                        minimumSize: const Size(44, 44),
                      ),
                    ),
                    IconButton(
                      onPressed: () => _copyAyah(ayah),
                      icon: Icon(Icons.copy_rounded, color: scheme.outline),
                      tooltip: context.l10n.readerCopyAyah,
                      style: IconButton.styleFrom(
                        minimumSize: const Size(44, 44),
                      ),
                    ),
                    IconButton(
                      onPressed: () => _openTafsir(ayah),
                      icon: Icon(
                        Icons.menu_book_outlined,
                        color: scheme.outline,
                      ),
                      tooltip: context.l10n.readerTafsir,
                      style: IconButton.styleFrom(
                        minimumSize: const Size(44, 44),
                      ),
                    ),
                  ],
                ),
                if (_settings.showArabic) ...[
                  const SizedBox(height: 14),
                  RepaintBoundary(
                    child: _settings.showTajwid
                        ? _buildTajwidText(ayah, scheme)
                        : SelectableText(
                            ayah.arabic,
                            textAlign: TextAlign.right,
                            style: GoogleFonts.amiri(
                              fontSize: 28 * _settings.arabicFontScale,
                              height: 2.0,
                              color: scheme.onSurface,
                            ),
                          ),
                  ),
                ],
                if (_settings.showTransliteration &&
                    ayah.transliteration.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                    decoration: BoxDecoration(
                      // Asian uses left accent + softer background, like Mushaf Standard Indonesia
                      color: _settings.transliterationEdition == 'id-transliteration'
                          ? scheme.surfaceContainerHighest.withValues(
                              alpha: .38,
                            )
                          : scheme.secondaryContainer.withValues(alpha: .42),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: scheme.outline.withValues(alpha: .18),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left accent bar for Asian style — purpose: visual anchor for Latin as in Muslim Pro
                        if (_settings.transliterationEdition == 'id-transliteration')
                          Container(
                            width: 3,
                            height: 18,
                            margin: const EdgeInsets.only(right: 10, top: 2),
                            decoration: BoxDecoration(
                              color: scheme.primary,
                              borderRadius: BorderRadius.circular(99),
                            ),
                          ),
                        Expanded(
                          child: SelectableText(
                            ayah.transliteration,
                            style: _settings.transliterationEdition == 'id-transliteration'
                                // Muslim Pro Asian: clean sans, normal weight, slightly larger, no italic, 1.7 line height for readability (SKB 1987)
                                ? GoogleFonts.inter(
                                    fontSize:
                                        14.2 *
                                        _settings.transliterationFontScale,
                                    height: 1.72,
                                    fontWeight: FontWeight.w500,
                                    letterSpacing: 0.15,
                                    color: scheme.onSurface.withValues(
                                      alpha: .78,
                                    ),
                                  )
                                : TextStyle(
                                    fontSize:
                                        13.5 *
                                        _settings.transliterationFontScale,
                                    height: 1.6,
                                    fontStyle: FontStyle.italic,
                                    color: scheme.onSurface.withValues(
                                      alpha: .72,
                                    ),
                                    letterSpacing: 0.1,
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (_settings.showTranslation &&
                    ayah.translation.isNotEmpty) ...[
                  const SizedBox(height: 13),
                  Container(
                    padding: const EdgeInsets.only(top: 12),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(
                          color: scheme.outline.withValues(alpha: .30),
                        ),
                      ),
                    ),
                    child: SelectableText(
                      ayah.translation,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        height: 1.55,
                        color: scheme.onSurface.withValues(alpha: .72),
                        fontSize:
                            (Theme.of(context).textTheme.bodyLarge?.fontSize ??
                                16) *
                            _settings.translationFontScale,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Verified Tajwid cache: verseNumber -> tagged uthmani string from quran.com.
  // Empty means not yet loaded or unavailable; UI falls back to plain text
  // to guarantee zero false coloring.
  final Map<int, String> _tajweedTagged = {};
  bool _tajweedLoading = false;
  String? _tajweedError;

  Future<void> _loadTajweed({bool force = false}) async {
    if (!_settings.showTajwid) return;
    if (_tajweedLoading && !force) return;
    _tajweedLoading = true;
    if (mounted) {
      setState(() => _tajweedError = null);
    }
    try {
      final tagged = await ApiService().fetchTajweedChapter(
        widget.surah.number,
      );
      if (!mounted) return;
      setState(() {
        _tajweedTagged.clear();
        _tajweedTagged.addAll(tagged);
      });
    } catch (e) {
      // Stay plain on failure. No guessing. Surface retry affordance.
      if (!mounted) return;
      setState(() => _tajweedError = '$e'.replaceFirst('Exception: ', ''));
    } finally {
      _tajweedLoading = false;
      if (mounted) setState(() {});
    }
  }

  Widget _buildTajwidText(Ayah ayah, ColorScheme scheme) {
    final tagged = _tajweedTagged[ayah.number];
    if (tagged == null || tagged.isEmpty) {
      return SelectableText(
        ayah.arabic,
        textAlign: TextAlign.right,
        style: GoogleFonts.amiri(
          fontSize: 28 * _settings.arabicFontScale,
          height: 2.0,
          color: scheme.onSurface,
        ),
      );
    }
    final tokens = parseTajweedTagged(tagged);
    return SelectableText.rich(
      TextSpan(
        children: tokens.map((t) {
          final color = tajwidColor(t.rule);
          final isColored = t.rule != null && color != Colors.transparent;
          return TextSpan(
            text: t.text,
            style: GoogleFonts.amiri(
              fontSize: 28 * _settings.arabicFontScale,
              height: 2.0,
              color: isColored ? color : scheme.onSurface,
              fontWeight: isColored ? FontWeight.w700 : FontWeight.w400,
            ),
          );
        }).toList(),
      ),
      textAlign: TextAlign.right,
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
              Text(
                context.l10n.readerLoadFailed,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                context.l10n.readerLoadFailedHint,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurface.withValues(alpha: .72),
                ),
              ),
              const SizedBox(height: 8),
              if (_settings.showTajwid)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    context.l10n.readerTajwidOffHint,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurface.withValues(alpha: .72),
                    ),
                  ),
                ),
              const SizedBox(height: 6),
              FilledButton.icon(
                onPressed: () => setState(() {
                  _future = _load();
                }),
                icon: const Icon(Icons.refresh_rounded),
                label: Text(context.l10n.actionRetry),
              ),
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
  Widget build(BuildContext context) => LiquidGlassPill(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    child: Text(
      label,
      style: Theme.of(
        context,
      ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
    ),
  );
}

/// Outcome of loading one ayah's tafsir.
class _TafsirResult {
  const _TafsirResult({required this.editionName, this.text, this.failed = false});

  final String editionName;

  /// Null when the selected edition has no tafsir for this ayah.
  final String? text;

  /// True when the request itself failed (offline), as opposed to the edition
  /// legitimately having no content here.
  final bool failed;
}

/// Tafsir sheet body. Owns its own future so the offline state can offer a
/// retry without tearing down the bottom sheet.
class _TafsirSheet extends StatefulWidget {
  const _TafsirSheet({
    required this.surah,
    required this.ayah,
    required this.editionId,
    required this.scrollController,
    required this.indicatorColor,
  });

  final Surah surah;
  final Ayah ayah;
  final String editionId;
  final ScrollController scrollController;
  final Color indicatorColor;

  @override
  State<_TafsirSheet> createState() => _TafsirSheetState();
}

class _TafsirSheetState extends State<_TafsirSheet> {
  final TafsirService _tafsir = TafsirService();
  late Future<_TafsirResult> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_TafsirResult> _load() async {
    final editionName = await _tafsir.editionName(widget.editionId);
    try {
      final text = await _tafsir.ayahTafsir(
        editionId: widget.editionId,
        surah: widget.surah.number,
        ayah: widget.ayah.number,
      );
      return _TafsirResult(editionName: editionName, text: text);
    } catch (e) {
      debugPrint('Tafsir load failed (${widget.editionId}): $e');
      return _TafsirResult(editionName: editionName, failed: true);
    }
  }

  void _retry() => setState(() => _future = _load());

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    return FutureBuilder<_TafsirResult>(
      future: _future,
      builder: (context, snapshot) {
        final result = snapshot.data;
        final loading = snapshot.connectionState == ConnectionState.waiting;
        return ListView(
          controller: widget.scrollController,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: widget.indicatorColor,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              l.readerTafsirTitle(widget.surah.number, widget.ayah.number),
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              result?.editionName ?? '',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.onSurface.withValues(alpha: .72),
              ),
            ),
            const SizedBox(height: 14),
            if (loading)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(30),
                  child: CircularProgressIndicator(color: scheme.primary),
                ),
              )
            else if (result == null || result.failed)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l.readerTafsirOffline),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: _retry,
                    child: Text(l.readerTafsirRetry),
                  ),
                ],
              )
            else if (result.text == null)
              Text(l.readerTafsirUnavailable)
            else
              SelectableText(
                result.text!,
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(height: 1.6),
              ),
          ],
        );
      },
    );
  }
}
