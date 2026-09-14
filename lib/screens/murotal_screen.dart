import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/surah.dart';
import '../services/api_service.dart';
import '../services/audio_service.dart';
import '../services/murotal_download_service.dart';
import '../services/settings_service.dart';
import '../widgets/liquid_glass.dart';
import 'murotal_download_screen.dart';

class MurotalScreen extends StatefulWidget {
  const MurotalScreen({super.key});

  @override
  State<MurotalScreen> createState() => _MurotalScreenState();
}

class _MurotalScreenState extends State<MurotalScreen> {
  final AudioService _audio = AudioService();
  final MurotalDownloadService _downloads = MurotalDownloadService();
  final SettingsService _settings = SettingsService();
  final TextEditingController _search = TextEditingController();

  late Future<List<Surah>> _future;
  List<Surah> _all = [];
  List<Surah> _visible = [];

  @override
  void initState() {
    super.initState();
    _audio.addListener(_refresh);
    _downloads.addListener(_refresh);
    _settings.addListener(_refresh);
    _downloads.init();
    _downloads.scanDownloadedFiles();
    _future = ApiService().fetchSurahs().then((surahs) {
      if (mounted) {
        setState(() {
          _all = surahs;
          _visible = surahs;
        });
      }
      return surahs;
    });
  }

  @override
  void dispose() {
    _audio.removeListener(_refresh);
    _downloads.removeListener(_refresh);
    _settings.removeListener(_refresh);
    _search.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  void _filter(String value) {
    final q = value.trim().toLowerCase();
    setState(() {
      if (q == 'offline') {
        _visible = _all.where((s) => _downloads.isSurahDownloaded(s.number)).toList();
        _audio.setCustomSurahSequence(_visible.map((s) => s.number).toList());
        return;
      }
      _audio.clearCustomSurahSequence();
      if (q.isEmpty) {
        _visible = _all;
      } else {
        _visible = _all.where((s) {
          return s.name.toLowerCase().contains(q) ||
              s.nameAr.toLowerCase().contains(q) ||
              s.number.toString() == q;
        }).toList();
      }
    });
  }

  Future<void> _openDownloads() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: .78,
        minChildSize: .55,
        maxChildSize: .94,
        builder: (context, controller) => MurotalDownloadScreen(scrollController: controller),
      ),
    );
  }

  Future<void> _openHelp() async {
    final scheme = Theme.of(context).colorScheme;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        top: false,
        child: Container(
          decoration: BoxDecoration(
            color: scheme.surface.withValues(alpha: .96),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 42, height: 4, decoration: BoxDecoration(color: scheme.outline, borderRadius: BorderRadius.circular(99)))),
              const SizedBox(height: 22),
              Text('Tentang Murotal', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text('Pilih surah untuk mulai mendengarkan. Ketik “offline” untuk menampilkan surah yang sudah tersimpan di perangkat.', style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: scheme.onSurface.withValues(alpha: .68), height: 1.45)),
              const SizedBox(height: 20),
              LiquidGlassCard(
                radius: 20,
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.touch_app_rounded, color: scheme.primary, size: 26),
                    const SizedBox(width: 14),
                    Expanded(child: Text('Ketuk kartu untuk memilih ayat awal.', style: Theme.of(context).textTheme.bodyMedium)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              LiquidGlassCard(
                radius: 20,
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.download_done_rounded, color: scheme.primary, size: 26),
                    const SizedBox(width: 14),
                    Expanded(child: Text('Ikon centang menandakan audio tersedia offline.', style: Theme.of(context).textTheme.bodyMedium)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openAyahPicker(Surah surah) async {
    final scheme = Theme.of(context).colorScheme;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * .68,
          decoration: BoxDecoration(
            color: scheme.surface.withValues(alpha: .98),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            children: [
              Center(child: Container(width: 42, height: 4, decoration: BoxDecoration(color: scheme.outline, borderRadius: BorderRadius.circular(99)))),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(child: Text('Mulai dari ayat', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800))),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
                ],
              ),
              Align(alignment: Alignment.centerLeft, child: Text(surah.name, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onSurface.withValues(alpha: .60)))),
              const SizedBox(height: 16),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.only(top: 4),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 5, crossAxisSpacing: 10, mainAxisSpacing: 10),
                  itemCount: surah.totalAyahs,
                  itemBuilder: (context, index) {
                    final number = index + 1;
                    return LiquidGlassCard(
                      radius: 16,
                      padding: EdgeInsets.zero,
                      onTap: () {
                        _audio.playAyah(surah, number);
                        Navigator.pop(context);
                      },
                      child: Center(child: Text(_settings.formatNumber(number), style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800, color: scheme.primary))),
                    );
                  },
                ),
              ),
            ],
          ),
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
        child: FutureBuilder<List<Surah>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting && _all.isEmpty) {
              return Center(child: CircularProgressIndicator(color: scheme.primary));
            }

            return CustomScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              slivers: [
                SliverAppBar(
                  pinned: true,
                  elevation: 0,
                  scrolledUnderElevation: 0,
                  backgroundColor: Colors.transparent,
                  automaticallyImplyLeading: false,
                  toolbarHeight: 74,
                  titleSpacing: 20,
                  title: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('MUROTAL', style: GoogleFonts.spaceGrotesk(fontSize: 23, fontWeight: FontWeight.w800, letterSpacing: -1)),
                      Text('Dengarkan Al-Qur’an dengan tenang', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: scheme.onSurface.withValues(alpha: .55))),
                    ],
                  ),
                  actions: [
                    Padding(padding: const EdgeInsets.only(right: 6), child: LiquidGlassIconButton(icon: Icons.help_outline_rounded, onPressed: _openHelp, tooltip: 'Bantuan')),
                    Padding(padding: const EdgeInsets.only(right: 14), child: LiquidGlassIconButton(icon: Icons.download_outlined, onPressed: _openDownloads, tooltip: 'Unduhan')),
                  ],
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 18),
                    child: LiquidGlassCard(
                      radius: 20,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: TextField(
                        controller: _search,
                        onChanged: _filter,
                        textInputAction: TextInputAction.search,
                        style: Theme.of(context).textTheme.bodyLarge,
                        decoration: InputDecoration(
                          icon: Icon(Icons.search_rounded, color: scheme.primary),
                          hintText: 'Cari surah atau ketik “offline”…',
                          border: InputBorder.none,
                          suffixIcon: _search.text.isEmpty ? null : IconButton(onPressed: () { _search.clear(); _filter(''); }, icon: const Icon(Icons.close_rounded)),
                        ),
                      ),
                    ),
                  ),
                ),
                if (_visible.isEmpty)
                  SliverFillRemaining(hasScrollBody: false, child: Center(child: Text('Surah tidak ditemukan', style: Theme.of(context).textTheme.bodyLarge)))
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
                    sliver: SliverList.separated(
                      itemCount: _visible.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) => _surahCard(_visible[index]),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _surahCard(Surah surah) {
    final scheme = Theme.of(context).colorScheme;
    final isCurrent = _audio.currentSurah?.number == surah.number;
    final isPlaying = isCurrent && _audio.isPlaying;
    final downloaded = _downloads.isSurahDownloaded(surah.number);

    return LiquidGlassCard(
      radius: 24,
      padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
      tint: isCurrent ? scheme.primary.withValues(alpha: .10) : null,
      onTap: () => _openAyahPicker(surah),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: [scheme.primary.withValues(alpha: .24), scheme.primary.withValues(alpha: .07)]),
              border: Border.all(color: scheme.primary.withValues(alpha: .30)),
            ),
            child: Center(child: Text(_settings.formatNumber(surah.number), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800, color: scheme.primary))),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(surah.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800))),
                    if (downloaded) ...[const SizedBox(width: 6), Icon(Icons.download_done_rounded, size: 18, color: scheme.primary)],
                  ],
                ),
                const SizedBox(height: 3),
                Text('${surah.nameAr}  •  ${_settings.formatNumber(surah.totalAyahs)} ayat', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurface.withValues(alpha: .56))),
                if (isCurrent) ...[
                  const SizedBox(height: 7),
                  Text(isPlaying ? 'Sedang diputar' : 'Siap dilanjutkan', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: scheme.primary, fontWeight: FontWeight.w700)),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 52,
            height: 52,
            child: LiquidGlassCard(
              radius: 18,
              padding: EdgeInsets.zero,
              tint: scheme.primary.withValues(alpha: .16),
              onTap: () {
                if (isCurrent) {
                  isPlaying ? _audio.pause() : _audio.resume();
                } else {
                  _audio.playAyah(surah, 1);
                }
              },
              child: Icon(isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, color: scheme.primary, size: 28),
            ),
          ),
        ],
      ),
    );
  }
}
