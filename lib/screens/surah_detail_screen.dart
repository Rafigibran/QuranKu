import 'dart:async';

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData, rootBundle;
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/ayah.dart';
import '../models/surah.dart';
import '../services/api_service.dart';
import '../services/settings_service.dart';
import '../services/bookmark_service.dart';

class SurahDetailScreen extends StatefulWidget {
  final Surah surah;
  final int? initialAyah;

  const SurahDetailScreen({
    super.key,
    required this.surah,
    this.initialAyah,
  });

  @override
  State<SurahDetailScreen> createState() => _SurahDetailScreenState();
}

class _SurahDetailScreenState extends State<SurahDetailScreen> {
  final SettingsService _settings = SettingsService();
  final BookmarkService _bookmarks = BookmarkService();
  final ScrollController _scroll = ScrollController();
  final TextEditingController _ayahInput = TextEditingController();

  late String _edition;
  late Future<List<Ayah>> _future;
  List<Ayah>? _ayahs;
  bool _showArabic = true;
  bool _showTranslation = true;
  bool _showTajwid = true;
  bool _showWordByWord = false;
  bool _restored = false;
  int? _lastReadAyah;
  int? _bookmarkedAyah;
  Future<void> _bookmarkWriteQueue = Future<void>.value();
  List<String> _editions = const ['id-indonesian', 'en-sahih'];

  @override
  void initState() {
    super.initState();
    _edition = _settings.defaultTranslation;
    _settings.addListener(_onSettingsChanged);
    _bookmarks.addListener(_onBookmarksChanged);
    _bookmarks.init().then((_) { if (mounted) _loadBookmark(); });

    final cached = ApiService.getCachedSurahDetails(
      widget.surah.number,
      edition: _edition,
    );
    if (cached != null && cached.isNotEmpty) {
      _ayahs = cached;
      _future = Future<List<Ayah>>.value(cached);
    } else {
      _future = _load();
    }

    _loadEditions();
    _loadLastRead();
    _loadBookmark();
  }

  @override
  void dispose() {
    _settings.removeListener(_onSettingsChanged);
    _bookmarks.removeListener(_onBookmarksChanged);
    _scroll.dispose();
    _ayahInput.dispose();
    super.dispose();
  }

  void _onBookmarksChanged() {
    if (mounted) setState(() {});
  }

  void _onSettingsChanged() {
    if (!mounted) return;
    if (_edition == _settings.defaultTranslation) {
      setState(() {});
      return;
    }
    setState(() {
      _edition = _settings.defaultTranslation;
      final cached = ApiService.getCachedSurahDetails(
        widget.surah.number,
        edition: _edition,
      );
      _ayahs = cached;
      _restored = false;
      _future = cached != null && cached.isNotEmpty
          ? Future<List<Ayah>>.value(cached)
          : _load();
    });
  }

  Future<List<Ayah>> _load() async {
    final data = await ApiService().fetchSurahDetails(
      widget.surah.number,
      edition: _edition,
    );
    if (mounted) {
      setState(() {
        _ayahs = data;
      });
      _restoreReadingWhenReady();
    }
    return data;
  }

  Future<void> _loadLastRead() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    if (prefs.getInt('last_reading_surah') != widget.surah.number) return;
    setState(() {
      _lastReadAyah = prefs.getInt('last_reading_ayah');
    });
    _restoreReadingWhenReady();
  }
  Future<void> _loadBookmark() async {
    await _bookmarks.init();
    if (!mounted) return;

    var items = _bookmarks.items
        .where((item) => item.surahNumber == widget.surah.number)
        .toList();
    if (items.isNotEmpty) {
      items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      setState(() => _bookmarkedAyah = items.first.ayahNumber);
      return;
    }

    // Migrate the old single-bookmark slot when it still exists.
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getInt('bookmark_surah') != widget.surah.number) return;
    final bookmark = prefs.getInt('bookmark_ayah');
    if (bookmark == null || bookmark < 1) return;
    await _bookmarks.toggle(widget.surah.number, bookmark);
    await prefs.remove('bookmark_surah');
    await prefs.remove('bookmark_ayah');
    if (mounted) setState(() => _bookmarkedAyah = bookmark);
  }

  Future<void> _toggleBookmark(int ayah) async {
    if (ayah < 1 || ayah > widget.surah.totalAyahs) return;
    await _bookmarks.toggle(widget.surah.number, ayah);
    if (!mounted) return;
    setState(() => _bookmarkedAyah = ayah);
  }

  Future<void> _loadEditions() async {
    try {
      final raw = await rootBundle.loadString('assets/editions.json');
      final data = json.decode(raw) as Map<String, dynamic>;
      final all = (data['editions'] as List<dynamic>).cast<String>();
      final values = <String>['id-indonesian', 'en-sahih', ...all]
          .where((value) => value != 'arabic')
          .toSet()
          .toList();
      if (mounted) setState(() => _editions = values);
    } catch (_) {}
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

  Future<void> _saveAyahAsLastRead(int ayah) async {
    if (ayah < 1 || ayah > widget.surah.totalAyahs) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('last_reading_surah', widget.surah.number);
    await prefs.setInt('last_reading_ayah', ayah);
    await prefs.setInt('last_reading_updated_at', DateTime.now().millisecondsSinceEpoch);
    await _bookmarks.recordLastRead(widget.surah.number, ayah);
    if (!mounted) return;
    setState(() {
      _lastReadAyah = ayah;
    });
  }

  void _restoreReadingWhenReady() {
    if (_restored || !mounted || !_scroll.hasClients) return;
    final target = widget.initialAyah ?? _lastReadAyah;
    if (target == null || target < 1) {
      _restored = true;
      return;
    }

    _restored = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      final estimatedOffset = ((target - 1) * 250.0)
          .clamp(0.0, _scroll.position.maxScrollExtent)
          .toDouble();
      _scroll.animateTo(
        estimatedOffset,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    });
  }

  String _copyAyahText(Ayah ayah) {
    final buffer = StringBuffer()
      ..writeln('${widget.surah.name} • Ayat ${ayah.number}')
      ..writeln()
      ..writeln(ayah.arabic);
    if (ayah.translation.trim().isNotEmpty) {
      buffer
        ..writeln()
        ..writeln(ayah.translation);
    }
    return buffer.toString().trim();
  }

  Future<void> _copyAyah(Ayah ayah) async {
    await Clipboard.setData(ClipboardData(text: _copyAyahText(ayah)));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Ayat disalin ke clipboard')),
    );
  }

  void _jumpToAyah(String value) {
    final target = int.tryParse(value);
    if (target == null || target < 1 || target > widget.surah.totalAyahs) return;
    Navigator.pop(context);
    _restored = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      final offset = ((target - 1) * 250.0)
          .clamp(0.0, _scroll.position.maxScrollExtent)
          .toDouble();
      _scroll.animateTo(
        offset,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
      );
    });
  }

  Future<void> _openSettings() async {
    final scheme = Theme.of(context).colorScheme;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          top: false,
          child: Container(
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
              border: Border(top: BorderSide(color: scheme.outline)),
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
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: scheme.outline,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Tampilan bacaan',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                              ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Loncat ke ayat',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: scheme.onSurface.withValues(alpha: .58),
                        ),
                  ),
                  const SizedBox(height: 8),
                  _surfaceField(
                    context,
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
                          icon: Icon(Icons.arrow_forward_rounded, color: scheme.primary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  const SizedBox(height: 20),
                  Text(
                    'Mushaf',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: scheme.onSurface.withValues(alpha: .58),
                        ),
                  ),
                  const SizedBox(height: 8),
                  _surfaceField(
                    context,
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _settings.scriptStyle,
                        isExpanded: true,
                        icon: Icon(Icons.expand_more_rounded, color: scheme.primary),
                        items: const [
                          DropdownMenuItem(value: 'uthmani', child: Text('Utsmani')),
                          DropdownMenuItem(value: 'indopak', child: Text('IndoPak')),
                        ],
                        onChanged: (value) async {
                          if (value == null) return;
                          await _settings.setScriptStyle(value);
                          setSheetState(() {});
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Transliterasi latin'),
                    subtitle: const Text('Tampilkan pelafalan latin jika tersedia.'),
                    value: _settings.showTransliteration,
                    onChanged: (value) async {
                      await _settings.setShowTransliteration(value);
                      setSheetState(() {});
                    },
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Yang ditampilkan',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: scheme.onSurface.withValues(alpha: .58),
                        ),
                  ),
                  const SizedBox(height: 8),
                  _surfaceGroup(
                    context,
                    children: [
                      SwitchListTile.adaptive(
                        title: const Text('Teks Arab'),
                        subtitle: const Text('Tampilkan tulisan Arab'),
                        value: _showArabic,
                        onChanged: (value) {
                          setState(() => _showArabic = value);
                          setSheetState(() {});
                        },
                      ),
                      Divider(height: 1, color: scheme.outline.withValues(alpha: .38)),
                      SwitchListTile.adaptive(
                        title: const Text('Terjemahan'),
                        subtitle: const Text('Tampilkan terjemahan ayat'),
                        value: _showTranslation,
                        onChanged: (value) {
                          setState(() => _showTranslation = value);
                          setSheetState(() {});
                        },
                      ),
                      Divider(height: 1, color: scheme.outline.withValues(alpha: .38)),
                      SwitchListTile.adaptive(
                        title: const Text('Warna Tajwid'),
                        subtitle: const Text('Gunakan warna hukum bacaan bila tersedia'),
                        value: _showTajwid,
                        onChanged: (value) {
                          setState(() => _showTajwid = value);
                          setSheetState(() {});
                        },
                      ),
                      Divider(height: 1, color: scheme.outline.withValues(alpha: .38)),
                      SwitchListTile.adaptive(
                        title: const Text('Terjemahan per kata'),
                        subtitle: Text('Mengikuti bahasa terjemahan: ${_editionName(_edition)}'),
                        value: _showWordByWord,
                        onChanged: (value) {
                          setState(() => _showWordByWord = value);
                          setSheetState(() {});
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Bahasa terjemahan',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: scheme.onSurface.withValues(alpha: .58),
                        ),
                  ),
                  const SizedBox(height: 8),
                  _surfaceField(
                    context,
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _editions.contains(_edition) ? _edition : _editions.first,
                        isExpanded: true,
                        icon: Icon(Icons.expand_more_rounded, color: scheme.primary),
                        items: _editions
                            .map(
                              (id) => DropdownMenuItem(
                                value: id,
                                child: Text(_editionName(id), overflow: TextOverflow.ellipsis),
                              ),
                            )
                            .toList(),
                        onChanged: (value) async {
                          if (value == null || value == _edition) return;
                          setState(() {
                            _edition = value;
                            final cached = ApiService.getCachedSurahDetails(
                              widget.surah.number,
                              edition: _edition,
                            );
                            _ayahs = cached;
                            _future = cached != null && cached.isNotEmpty
                                ? Future<List<Ayah>>.value(cached)
                                : _load();
                            _restored = false;
                          });
                          setSheetState(() {});
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _surfaceField(BuildContext context, {required Widget child}) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outline),
      ),
      child: child,
    );
  }

  Widget _surfaceGroup(BuildContext context, {required List<Widget> children}) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outline),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final cached = _ayahs;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        bottom: false,
        child: (cached != null && cached.isNotEmpty)
            ? _buildReader(cached)
            : FutureBuilder<List<Ayah>>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return _buildReaderSkeleton();
                  }
                  if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
                    return _errorState();
                  }
                  _ayahs = snapshot.data!;
                  _restoreReadingWhenReady();
                  return _buildReader(snapshot.data!);
                },
              ),
      ),
    );
  }

  Widget _buildReader(List<Ayah> ayahs) {
    final scheme = Theme.of(context).colorScheme;
    _restoreReadingWhenReady();

    return CustomScrollView(
      controller: _scroll,
      slivers: [
        SliverAppBar(
          pinned: true,
          toolbarHeight: 66,
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          surfaceTintColor: Colors.transparent,
          scrolledUnderElevation: 0,
          leading: const BackButton(),
          title: Text(
            widget.surah.name,
            style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w800),
          ),
          centerTitle: true,
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Material(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: _openSettings,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: scheme.outline),
                    ),
                    child: Icon(Icons.tune_rounded, color: scheme.onSurface, size: 21),
                  ),
                ),
              ),
            ),
          ],
        ),
        SliverToBoxAdapter(child: _buildHeaderCard(context, ayahs)),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 130),
          sliver: SliverList.separated(
            itemCount: ayahs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) => KeyedSubtree(
              key: _ayahKeys[index],
              child: _ayahCard(ayahs[index]),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderCard(BuildContext context, List<Ayah> ayahs) {
    final scheme = Theme.of(context).colorScheme;
    final hasSaved = _lastReadAyah != null;

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 6, 20, 18),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(27),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.primary,
            Color.lerp(scheme.primary, scheme.secondary, 0.45)!,
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.surah.name,
                  style: GoogleFonts.spaceGrotesk(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.8,
                  ),
                ),
              ),
              Text(
                widget.surah.nameAr,
                style: GoogleFonts.notoNaskhArabic(fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.94),
                  fontSize: 27,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${widget.surah.type} • ${widget.surah.totalAyahs} ayat',
            style: GoogleFonts.spaceGrotesk(
              color: Colors.white.withValues(alpha: 0.78),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              _headerChip(_editionName(_edition)),
              _headerChip(_showWordByWord ? 'Per kata aktif' : 'Per kata tersedia'),
              if (ayahs.isNotEmpty && ayahs.first.tajwidText != null)
                _headerChip('Tajwid aktif'),
            ],
          ),
          if (hasSaved) ...[
            const SizedBox(height: 16),
            Material(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => _jumpToAyah('${_lastReadAyah!}'),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  child: Row(
                    children: [
                      const Icon(Icons.bookmark_rounded, color: Colors.white, size: 19),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Lanjutkan dari ayat ${_lastReadAyah!}',
                          style: GoogleFonts.spaceGrotesk(
                            color: Colors.white,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _headerChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: GoogleFonts.spaceGrotesk(
          color: Colors.white,
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _ayahCard(Ayah ayah) {
    final scheme = Theme.of(context).colorScheme;
    final isSaved = _bookmarks.isBookmarked(widget.surah.number, ayah.number);
    final useIndopak = _settings.scriptStyle == 'indopak' && (ayah.indopak?.trim().isNotEmpty ?? false);
    final arabicText = useIndopak ? ayah.indopak! : ayah.arabic;

    return Container(
      padding: const EdgeInsets.fromLTRB(17, 14, 17, 17),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isSaved
              ? scheme.primary.withValues(alpha: 0.38)
              : scheme.outline.withValues(alpha: 0.84),
          width: isSaved ? 1.35 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 39,
                height: 39,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: .10),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: scheme.primary.withValues(alpha: .22)),
                ),
                child: Center(
                  child: Text(
                    _settings.formatNumber(ayah.number),
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: scheme.primary,
                        ),
                  ),
                ),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Salin ayat',
                onPressed: () => _copyAyah(ayah),
                icon: const Icon(Icons.copy_rounded),
              ),
              IconButton(
                tooltip: isSaved ? 'Hapus bookmark ayat' : 'Simpan bookmark ayat',
                onPressed: () => _toggleBookmark(ayah.number),
                icon: Icon(
                  isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                  color: isSaved ? scheme.primary : scheme.onSurface.withValues(alpha: .45),
                ),
              ),
            ],
          ),
          if (_showArabic) ...[
            const SizedBox(height: 8),
            if (_showTajwid && !useIndopak && ayah.tajwidText != null && ayah.tajwidText!.trim().isNotEmpty)
              _buildTajwid(ayah.tajwidText!, scheme)
            else
              Text(
                arabicText,
                textAlign: TextAlign.right,
                style: GoogleFonts.notoNaskhArabic(fontWeight: FontWeight.w600,
                  fontSize: 29,
                  height: 2.0,
                  color: scheme.onSurface,
                ),
              ),
            if (_settings.showTransliteration && (ayah.transliteration?.trim().isNotEmpty ?? false)) ...[
              const SizedBox(height: 10),
              Text(
                ayah.transliteration!,
                textAlign: TextAlign.left,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      height: 1.35,
                      color: scheme.onSurface.withValues(alpha: .62),
                      fontStyle: FontStyle.italic,
                    ),
              ),
            ],
            if (_showWordByWord && ayah.words.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildWordByWord(ayah.words, scheme),
            ],
          ],
          if (_showTranslation && ayah.translation.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.only(top: 13),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: scheme.outline.withValues(alpha: .45)),
                ),
              ),
              child: Text(
                ayah.translation,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      height: 1.55,
                      color: scheme.onSurface.withValues(alpha: .74),
                      fontWeight: FontWeight.w500,
                    ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTajwid(String markup, ColorScheme scheme) {
    final spans = <InlineSpan>[];
    final regex = RegExp(
      r"""<(?:tajweed|rule|span)\b[^>]*\bclass\s*=\s*["']?([^"'>\s]+)["']?[^>]*>(.*?)</(?:tajweed|rule|span)>""",
      dotAll: true,
      caseSensitive: false,
    );

    var cursor = 0;
    for (final match in regex.allMatches(markup)) {
      if (match.start > cursor) {
        spans.add(
          TextSpan(
            text: _stripTags(markup.substring(cursor, match.start)),
          ),
        );
      }

      final className = match.group(1) ?? '';
      final text = _stripTags(match.group(2) ?? '');
      spans.add(
        TextSpan(
          text: text,
          style: TextStyle(color: _tajwidColor(className, scheme)),
        ),
      );
      cursor = match.end;
    }

    if (cursor < markup.length) {
      spans.add(
        TextSpan(text: _stripTags(markup.substring(cursor))),
      );
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: RichText(
        textAlign: TextAlign.right,
        text: TextSpan(
          style: GoogleFonts.notoNaskhArabic(
            fontSize: 30,
            height: 2.0,
            fontWeight: FontWeight.w600,
            color: scheme.onSurface,
          ),
          children: spans,
        ),
      ),
    );
  }

  Color _tajwidColor(String className, ColorScheme scheme) {
    final c = className
        .toLowerCase()
        .replaceAll('-', '_')
        .replaceAll(' ', '_');

    if (c == 'ham_wasl' || c == 'hamzat_wasl') {
      return const Color(0xFF9CFC4A);
    }
    if (c == 'slnt' ||
        c == 'silent' ||
        c == 'end') {
      return const Color(0xFFAAAAAA);
    }
    if (c == 'laam_shamsiyah' || c == 'lam_shamsiyyah') {
      return const Color(0xFFD44DFF);
    }
    if (c == 'madda_normal' || c == 'madd_normal') {
      return const Color(0xFF4B83FF);
    }
    if (c == 'madda_permissible' ||
        c == 'madd_permissible' ||
        c == 'madda_jaiz_munfasil' ||
        c == 'madd_jaiz_munfasil' ||
        c == 'madd_246') {
      return const Color(0xFFD928E6);
    }
    if (c == 'madda_necessary' ||
        c == 'madd_necessary' ||
        c == 'madda_lazim' ||
        c == 'madd_lazim' ||
        c == 'madd_6') {
      return const Color(0xFFFF4FB3);
    }
    if (c == 'madda_obligatory' ||
        c == 'madd_obligatory' ||
        c == 'madda_wajib_muttasil' ||
        c == 'madd_wajib_muttasil' ||
        c == 'madd_muttasil') {
      return const Color(0xFFFF5A5F);
    }
    if (c == 'qalaqah' || c == 'qalqalah' || c == 'qlq') {
      return const Color(0xFF3F7CFF);
    }
    if (c == 'ikhfa_shafawi' || c == 'ikhf_shfw' || c == 'ikhfa') {
      return const Color(0xFF36C2A0);
    }
    if (c == 'iqlab' || c == 'iqlb') {
      return const Color(0xFFA14BCB);
    }
    if (c == 'idgham_shafawi' || c == 'idghaam_shafawi' || c == 'idghm_shfw') {
      return const Color(0xFF47B86B);
    }
    if (c == 'idgham_ghunnah' ||
        c == 'idghaam_ghunnah' ||
        c == 'idgham_with_ghunnah' ||
        c == 'idghaam_with_ghunnah' ||
        c == 'idgh_ghn') {
      return const Color(0xFF20B879);
    }
    if (c == 'idgham_without_ghunnah' ||
        c == 'idghaam_without_ghunnah' ||
        c == 'idgham_bila_ghunnah' ||
        c == 'idghaam_bila_ghunnah' ||
        c == 'idgh_w_ghn') {
      return const Color(0xFF169C47);
    }
    if (c == 'idgham_mutajanisayn' ||
        c == 'idghaam_mutajanisayn' ||
        c == 'idgham_mutamathilayn' ||
        c == 'idgham_mutaqaribayn' ||
        c == 'idghaam_mutaqaaribayn') {
      return const Color(0xFFC55CFF);
    }
    if (c == 'ghunnah' || c == 'ghn') {
      return const Color(0xFFFF7E1E);
    }
    if (c == 'waqf_lazim' ||
        c == 'waqf_jaiz' ||
        c == 'waqf_muaqabah' ||
        c == 'waqf_muanaqah' ||
        c == 'waqf_muanqah') {
      return const Color(0xFF537FFF);
    }

    return scheme.onSurface;
  }

  String _stripTags(String value) => value.replaceAll(RegExp(r'<[^>]+>'), '');

  Widget _buildWordByWord(List<QuranWord> words, ColorScheme scheme) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Wrap(
        alignment: WrapAlignment.end,
        runSpacing: 8,
        spacing: 6,
        children: words.map((word) {
          return Container(
            constraints: const BoxConstraints(minWidth: 62),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: .055),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: scheme.outline.withValues(alpha: .45)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  word.arabic,
                  style: GoogleFonts.notoNaskhArabic(fontWeight: FontWeight.w600,fontSize: 20, color: scheme.onSurface),
                ),
                if (word.translation.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    word.translation,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: scheme.primary,
                          fontWeight: FontWeight.w700,
                          height: 1.1,
                        ),
                  ),
                ],
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildReaderSkeleton() {
    final scheme = Theme.of(context).colorScheme;
    return CustomScrollView(
      physics: const NeverScrollableScrollPhysics(),
      slivers: [
        const SliverAppBar(
          pinned: true,
          toolbarHeight: 66,
          leading: BackButton(),
          title: Text('Membaca'),
          centerTitle: true,
        ),
        SliverToBoxAdapter(
          child: Container(
            margin: const EdgeInsets.fromLTRB(20, 6, 20, 18),
            height: 154,
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: .10),
              borderRadius: BorderRadius.circular(27),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
          sliver: SliverList.separated(
            itemCount: 4,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, __) => Container(
              height: 180,
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: scheme.outline),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _errorState() {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: scheme.outline),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.wifi_off_rounded, color: scheme.primary, size: 42),
              const SizedBox(height: 14),
              Text(
                'Ayat belum dapat dimuat',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Periksa koneksi internet lalu coba lagi.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurface.withValues(alpha: .62),
                    ),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: () {
                  setState(() {
                    _ayahs = null;
                    _future = _load();
                  });
                },
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Coba lagi'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
