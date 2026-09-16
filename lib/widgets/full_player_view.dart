import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:quranku/l10n/app_localizations.dart';
import '../services/audio_service.dart' as as_audio;
import '../services/background_audio_service.dart';
import '../l10n/l10n.dart';
import '../services/settings_service.dart';
import '../services/api_service.dart';
import '../models/ayah.dart';
import '../models/surah.dart';
import '../widgets/liquid_glass.dart';

class FullPlayerView extends StatefulWidget {
  final VoidCallback onCollapse;

  const FullPlayerView({super.key, required this.onCollapse});

  @override
  State<FullPlayerView> createState() => _FullPlayerViewState();
}

class _FullPlayerViewState extends State<FullPlayerView> {
  final as_audio.AudioService _audio = as_audio.AudioService();
  final BackgroundAudioService _background = BackgroundAudioService();
  final SettingsService _settings = SettingsService();
  final ApiService _api = ApiService();
  final ScrollController _lyricsScroll = ScrollController();
  final Map<int, GlobalKey> _lyricsKeys = {};
  List<Ayah> _lyricsAyahs = [];
  bool _lyricsLoading = false;
  int? _lastLyricsSurah;
  int _lastLyricsAyah = -1;

  @override
  void initState() {
    super.initState();
    _audio.addListener(_refresh);
    _background.addListener(_refresh);
    _settings.addListener(_refresh);
    _background.init();
    _maybeLoadLyrics();
  }

  @override
  void dispose() {
    _audio.removeListener(_refresh);
    _background.removeListener(_refresh);
    _settings.removeListener(_refresh);
    _lyricsScroll.dispose();
    super.dispose();
  }

  void _refresh() {
    if (!mounted) return;
    setState(() {});
    _maybeLoadLyrics();
    _maybeScrollToCurrent();
  }

  void _maybeLoadLyrics() {
    final surah = _audio.currentSurah;
    if (surah == null) return;
    if (_lastLyricsSurah == surah.number && _lyricsAyahs.isNotEmpty) return;
    if (_lyricsLoading) return;
    _lastLyricsSurah = surah.number;
    _lyricsLoading = true;
    _api
        .fetchSurahDetails(
          surah.number,
          edition: _settings.defaultTranslation,
          transliterationEdition: _settings.showTransliteration
              ? _settings.transliterationEdition
              : null,
        )
        .then((ayahs) {
          if (!mounted) return;
          setState(() {
            _lyricsAyahs = ayahs;
            _lyricsLoading = false;
            for (final a in ayahs) {
              _lyricsKeys.putIfAbsent(a.number, () => GlobalKey());
            }
          });
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => _scrollToCurrentAyah(),
          );
        })
        .catchError((_) {
          if (mounted) setState(() => _lyricsLoading = false);
        });
  }

  void _maybeScrollToCurrent() {
    final ayah = _audio.currentAyah;
    if (ayah == _lastLyricsAyah) return;
    _lastLyricsAyah = ayah;
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToCurrentAyah());
  }

  void _scrollToCurrentAyah() {
    if (!_settings.showLyrics) return;
    final key = _lyricsKeys[_audio.currentAyah];
    if (key?.currentContext == null) return;
    final reduce = MediaQuery.maybeOf(context) != null
        ? MediaQuery.disableAnimationsOf(context)
        : false;
    Scrollable.ensureVisible(
      key!.currentContext!,
      duration: reduce ? Duration.zero : const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
      alignment: 0.35,
    );
  }

  Future<void> _openBackgroundSound() async {
    final l = AppLocalizations.of(context)!;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _GlassSheet(
        title: l.playerTitle,
        child: StatefulBuilder(
          builder: (context, setSheetState) {
            final scheme = Theme.of(context).colorScheme;
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: _background.enabled,
                  onChanged: (value) async {
                    await _background.setEnabled(value);
                    setSheetState(() {});
                  },
                  title: Text(context.l10n.playerRainSound),
                  subtitle: Text(context.l10n.playerBackgroundSoundSubtitle),
                  activeTrackColor: scheme.primary.withValues(alpha: .45),
                  activeThumbColor: scheme.primary,
                ),
                const SizedBox(height: 10),
                _volumeSlider(
                  context.l10n.playerVolumeQuran,
                  _background.mainVolume,
                  (v) async {
                    await _background.setMainVolume(v);
                    setSheetState(() {});
                  },
                ),
                _volumeSlider(
                  context.l10n.playerVolumeRain,
                  _background.backgroundVolume,
                  (v) async {
                    await _background.setBackgroundVolume(v);
                    setSheetState(() {});
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _volumeSlider(String label, double value, ValueChanged<double> onChanged) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
              Text('${(value * 100).round()}%', style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w700)),
            ],
          ),
          Slider(value: value, onChanged: onChanged),
        ],
      ),
    );
  }


  String _repeatLabel() {
    switch (_audio.repeatMode) {
      case as_audio.RepeatMode.repeatOne:
        return 'Ulang 1';
      case as_audio.RepeatMode.none:
        return context.l10n.playerRepeatNone;
      case as_audio.RepeatMode.autoNext:
        return context.l10n.playerRepeatAuto;
    }
  }

  Future<void> _showRepeatSheet() async {
    final scheme = Theme.of(context).colorScheme;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _GlassSheet(
        title: context.l10n.playerRepeatMode,
        child: StatefulBuilder(
          builder: (context, setSheet) {
            Widget tile(as_audio.RepeatMode mode, IconData icon, String title, String subtitle) {
              final selected = _audio.repeatMode == mode;
              return InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () {
                  _audio.setRepeatMode(mode);
                  setSheet(() {});
                  setState(() {});
                  Navigator.pop(context);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: selected ? scheme.primary.withValues(alpha: .12) : Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: selected ? scheme.primary.withValues(alpha: .30) : scheme.outlineVariant),
                  ),
                  child: Row(
                    children: [
                      Icon(icon, color: selected ? scheme.primary : scheme.onSurfaceVariant),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: TextStyle(fontWeight: FontWeight.w800, color: selected ? scheme.primary : scheme.onSurface)), const SizedBox(height: 2), Text(subtitle, style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant))])),
                      if (selected) Icon(Icons.check_circle_rounded, color: scheme.primary, size: 20),
                    ],
                  ),
                ),
              );
            }
            return Column(mainAxisSize: MainAxisSize.min, children: [
              tile(as_audio.RepeatMode.autoNext, Icons.repeat_rounded, context.l10n.playerRepeatAuto,
                context.l10n.playerRepeatAutoSubtitle),
              const SizedBox(height: 10),
              tile(as_audio.RepeatMode.repeatOne, Icons.repeat_one_rounded, context.l10n.playerRepeatOne,
                context.l10n.playerRepeatOneSubtitle),
              const SizedBox(height: 10),
              tile(as_audio.RepeatMode.none, Icons.block_rounded, context.l10n.playerRepeatOff,
                context.l10n.playerRepeatOffSubtitle),
            ]);
          },
        ),
      ),
    );
  }

  Future<void> _showQueueSheet() async {
    final scheme = Theme.of(context).colorScheme;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheet) => SafeArea(
          top: false,
          child: LiquidGlassCard(
            radius: 30,
            margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            padding: const EdgeInsets.fromLTRB(22, 14, 22, 28),
            blur: 26,
            tint: Theme.of(context).colorScheme.surface.withValues(alpha: .52),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 42, height: 4, decoration: BoxDecoration(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: .25), borderRadius: BorderRadius.circular(99)))),
                const SizedBox(height: 16),
                Text(context.l10n.playerQueue, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.58,
                  child: Column(
                    children: [
                      if (_audio.customSurahSequence.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(color: scheme.secondaryContainer.withValues(alpha: .55), borderRadius: BorderRadius.circular(14), border: Border.all(color: scheme.outlineVariant)),
                          child: Row(children: [
                            Icon(Icons.filter_list_rounded, size: 16, color: scheme.onSurfaceVariant),
                            const SizedBox(width: 8),
                            Expanded(child: Text(context.l10n.playerQueueFiltered(_audio.customSurahSequence.length), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: scheme.onSurfaceVariant))),
                            TextButton(onPressed: () { _audio.clearCustomSurahSequence(); setSheet(() {}); setState(() {}); }, child: Text(context.l10n.playerShowAll)),
                          ]),
                        ),
                      Row(children: [
                        Text('Urutan:', style: TextStyle(fontWeight: FontWeight.w700, color: scheme.onSurfaceVariant, fontSize: 12)),
                        const SizedBox(width: 8),
                        ChoiceChip(label: const Text('1 → 114'), selected: _audio.surahOrder == as_audio.SurahOrder.ascending, onSelected: (_) { _audio.setSurahOrder(as_audio.SurahOrder.ascending); setSheet(() {}); setState(() {}); }, selectedColor: scheme.primary.withValues(alpha: .18)),
                        const SizedBox(width: 8),
                        ChoiceChip(label: const Text('114 → 1'), selected: _audio.surahOrder == as_audio.SurahOrder.descending, onSelected: (_) { _audio.setSurahOrder(as_audio.SurahOrder.descending); setSheet(() {}); setState(() {}); }, selectedColor: scheme.primary.withValues(alpha: .18)),
                      ]),
                      const SizedBox(height: 12),
                      Expanded(
                        child: FutureBuilder<List<Surah>>(
                          future: ApiService().fetchSurahs(),
                          builder: (context, snap) {
                            if (snap.connectionState == ConnectionState.waiting) return Center(child: CircularProgressIndicator(color: scheme.primary));
                            final all = snap.data ?? const <Surah>[];
                            if (all.isEmpty) return Text(context.l10n.playerQueueUnavailable);
                            final byNum = {for (final s in all) s.number: s};
                            final ids = _audio.effectiveQueue;
                            final ordered = <Surah>[for (final id in ids) if (byNum[id] != null) byNum[id]!];
                            final currentNum = _audio.currentSurah?.number;
                            return ListView.separated(
                              itemCount: ordered.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 6),
                              itemBuilder: (context, i) {
                                final s = ordered[i];
                                final isCurrent = s.number == currentNum;
                                final isPlaying = isCurrent && _audio.isPlaying;
                                return InkWell(
                                  borderRadius: BorderRadius.circular(14),
                                  onTap: () { Navigator.pop(context); _audio.playAyah(s, 1); },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                    decoration: BoxDecoration(color: isCurrent ? scheme.primary.withValues(alpha: .12) : scheme.surfaceContainerHighest.withValues(alpha: .55), borderRadius: BorderRadius.circular(14), border: Border.all(color: isCurrent ? scheme.primary.withValues(alpha: .35) : scheme.outlineVariant)),
                                    child: Row(children: [
                                      Container(width: 36, height: 36, decoration: BoxDecoration(shape: BoxShape.circle, color: isCurrent ? scheme.primary : scheme.surface, border: Border.all(color: scheme.outlineVariant)), alignment: Alignment.center, child: Text(_settings.formatNumber(s.number), style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: isCurrent ? scheme.onPrimary : scheme.onSurface))),
                                      const SizedBox(width: 12),
                                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(s.name, style: TextStyle(fontWeight: FontWeight.w800, color: isCurrent ? scheme.primary : scheme.onSurface)), Text('${s.nameAr} • ${s.totalAyahs} ayat', style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant))])),
                                      if (isCurrent) ...[const SizedBox(width: 8), Icon(isPlaying ? Icons.equalizer_rounded : Icons.pause_circle_outline_rounded, size: 18, color: scheme.primary)] else ...[Icon(Icons.play_arrow_rounded, size: 20, color: scheme.onSurfaceVariant)],
                                    ]),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _lyricsHeader(ColorScheme scheme, surah) {
    return Row(children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: scheme.primary.withValues(alpha: .10), borderRadius: BorderRadius.circular(99), border: Border.all(color: scheme.primary.withValues(alpha: .18))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.lyrics_rounded, size: 14, color: scheme.primary), const SizedBox(width: 6), Text('Lirik • QS ${surah.number}:${_settings.formatNumber(_audio.currentAyah)}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: scheme.primary))]),
      ),
      const Spacer(),
      Text('${_lyricsAyahs.length} ayat', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: scheme.onSurfaceVariant)),
    ]);
  }

  Widget _lyricsStage(ColorScheme scheme, surah) {
    if (_lyricsLoading) return Center(child: CircularProgressIndicator(color: scheme.primary));
    if (_lyricsAyahs.isEmpty) return Center(child: Text(context.l10n.playerLyricsEmpty, style: Theme.of(context).textTheme.bodyMedium));
    return Container(
      decoration: BoxDecoration(color: scheme.surfaceContainerLow, borderRadius: BorderRadius.circular(18), border: Border.all(color: scheme.outlineVariant)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: ListView.builder(
          controller: _lyricsScroll,
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: _lyricsAyahs.length,
          itemBuilder: (context, index) {
            final ayah = _lyricsAyahs[index];
            final isCurrent = ayah.number == _audio.currentAyah;
            final isPrev = ayah.number == _audio.currentAyah - 1;
            final isNext = ayah.number == _audio.currentAyah + 1;
            return Container(
              key: _lyricsKeys[ayah.number],
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: isCurrent ? scheme.primary.withValues(alpha: .10) : Colors.transparent, borderRadius: BorderRadius.circular(14), border: isCurrent ? Border.all(color: scheme.primary, width: 1.4) : null),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => _audio.playAyah(surah, ayah.number),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  child: Opacity(
                    opacity: isCurrent ? 1 : (isPrev || isNext ? 0.85 : 0.62),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(children: [
                          Container(width: 28, height: 28, decoration: BoxDecoration(shape: BoxShape.circle, color: isCurrent ? scheme.primary : scheme.primary.withValues(alpha: .12), border: Border.all(color: scheme.primary.withValues(alpha: isCurrent ? 1 : .20))), alignment: Alignment.center, child: Text(_settings.formatNumber(ayah.number), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: isCurrent ? scheme.onPrimary : scheme.primary))),
                          const SizedBox(width: 8),
                          if (isCurrent) Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: scheme.primary, borderRadius: BorderRadius.circular(99)), child: Text('Diputar', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: scheme.onPrimary))),
                          const Spacer(),
                          Icon(Icons.play_arrow_rounded, size: 16, color: scheme.primary.withValues(alpha: isCurrent ? 1 : 0)),
                        ]),
                        if (_settings.showArabic) ...[const SizedBox(height: 8), SelectableText(ayah.arabic, textAlign: TextAlign.right, style: GoogleFonts.amiri(fontSize: 20 * _settings.arabicFontScale, height: 1.9, color: scheme.onSurface))],
                        if (_settings.showTransliteration && ayah.transliteration.isNotEmpty) ...[const SizedBox(height: 6), Text(ayah.transliteration, style: GoogleFonts.inter(fontSize: 12.5 * _settings.transliterationFontScale, height: 1.6, fontStyle: FontStyle.italic, color: scheme.onSurface.withValues(alpha: .68)))],
                        if (_settings.showTranslation && ayah.translation.isNotEmpty) ...[const SizedBox(height: 6), Text(ayah.translation, style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.5, color: scheme.onSurface.withValues(alpha: .72)))],
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final surah = _audio.currentSurah;
    if (surah == null) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: scheme.surfaceContainerLowest,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const _PlayerBackdrop(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 10),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      LiquidGlassIconButton(
                        icon: Icons.keyboard_arrow_down_rounded,
                        onPressed: widget.onCollapse,
                        tooltip: 'Tutup',
                      ),
                      LiquidGlassIconButton(
                        icon: _background.enabled
                            ? Icons.water_drop_rounded
                            : Icons.water_drop_outlined,
                        onPressed: _openBackgroundSound,
                        tooltip: context.l10n.playerBackgroundSound,
                      ),
                    ],
                  ),
                  if (_settings.showLyrics && (_lyricsAyahs.isNotEmpty || _lyricsLoading)) ...[
                    const SizedBox(height: 8),
                    _Artwork(compact: true),
                    const SizedBox(height: 12),
                    _lyricsHeader(scheme, surah),
                    const SizedBox(height: 8),
                    Expanded(child: _lyricsStage(scheme, surah)),
                    const SizedBox(height: 12),
                  ] else ...[
                    const Spacer(flex: 2),
                    _Artwork(),
                    const SizedBox(height: 26),
                  ],
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(surah.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800, color: Theme.of(context).colorScheme.onSurface)),
                            const SizedBox(height: 5),
                            Text(context.l10n.playerNowPlayingAyah(_settings.formatNumber(_audio.currentAyah)), style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                          ],
                        ),
                      ),
                      LiquidGlassIconButton(
                        icon: _settings.showLyrics ? Icons.lyrics_rounded : Icons.menu_book_rounded,
                        onPressed: () async {
                          await _settings.setShowLyrics(!_settings.showLyrics);
                          if (_settings.showLyrics) _maybeLoadLyrics();
                        },
                        tooltip: _settings.showLyrics
                            ? context.l10n.playerHideLyrics
                            : context.l10n.playerShowLyrics,
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  StreamBuilder<Duration>(
                    stream: _audio.positionStream,
                    builder: (context, positionSnapshot) {
                      return StreamBuilder<Duration?>(
                        stream: _audio.durationStream,
                        builder: (context, durationSnapshot) {
                          final duration = durationSnapshot.data ?? Duration.zero;
                          final position = positionSnapshot.data ?? Duration.zero;
                          final max = duration.inMilliseconds > 0 ? duration.inMilliseconds.toDouble() : 1.0;
                          final current = position.inMilliseconds.clamp(0, max.toInt()).toDouble();
                          return Column(
                            children: [
                              SliderTheme(
                                data: SliderTheme.of(context).copyWith(trackHeight: 4, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6), overlayShape: const RoundSliderOverlayShape(overlayRadius: 16), activeTrackColor: Theme.of(context).colorScheme.primary, inactiveTrackColor: Theme.of(context).colorScheme.surfaceContainerHighest, thumbColor: Theme.of(context).colorScheme.primary),
                                child: Slider(
                                  min: 0,
                                  max: max,
                                  value: current,
                                  onChanged: duration == Duration.zero ? null : (value) => _seek(Duration(milliseconds: value.round())),
                                ),
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(_formatDuration(position), style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
                                  Text('-${_formatDuration(duration - position < Duration.zero ? Duration.zero : duration - position)}', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
                                ],
                              ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _ControlButton(icon: _repeatIcon(), small: true, active: _audio.repeatMode != as_audio.RepeatMode.none, onPressed: _showRepeatSheet, tooltip: _repeatLabel()),
                        _ControlButton(icon: Icons.skip_previous_rounded, onPressed: _audio.hasPrevSurah() ? _audio.playPrevSurah : null, tooltip: 'Sebelumnya'),
                        _PlayButton(playing: _audio.isPlaying, onPressed: () => _audio.isPlaying ? _audio.pause() : _audio.resume()),
                        _ControlButton(icon: Icons.skip_next_rounded, onPressed: _audio.hasNextSurah() ? _audio.playNextSurah : null, tooltip: 'Berikutnya'),
                        _ControlButton(icon: Icons.format_list_bulleted_rounded, small: true, active: false, onPressed: _showQueueSheet, tooltip: context.l10n.playerQueue),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _repeatIcon() {
    switch (_audio.repeatMode) {
      case as_audio.RepeatMode.none:
        return Icons.block_rounded;
      case as_audio.RepeatMode.autoNext:
        return Icons.repeat_rounded;
      case as_audio.RepeatMode.repeatOne:
        return Icons.repeat_one_rounded;
    }
  }

  Future<void> _seek(Duration value) async {
    await _audio.seek(value);
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
  }
}

/// Flat tonal surface for the player.
///
/// A page gradient, two blurred radial orbs and a backdrop blur were stacked
/// here, all from hardcoded near-black hex. DESIGN.md refuses blur and
/// gradients, and the hardcoded colours meant light theme rendered a black
/// player. The darkest tonal step carries the same focus without any of it.
class _PlayerBackdrop extends StatelessWidget {
  const _PlayerBackdrop();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerLowest,
    );
  }
}

class _Artwork extends StatelessWidget {
  const _Artwork({this.compact = false});
  final bool compact;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final size = compact ? 110.0 : 230.0;
    final iconSize = compact ? 36.0 : 70.0;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: scheme.surfaceContainerHighest,
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Center(
        child: Icon(
          Icons.menu_book_rounded,
          color: scheme.primary,
          size: iconSize,
        ),
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  const _ControlButton({required this.icon, required this.onPressed, this.small = false, this.active = false, this.tooltip});

  final IconData icon;
  final VoidCallback? onPressed;
  final bool small;
  final bool active;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = onPressed == null
        ? scheme.onSurface.withValues(alpha: .38)
        : (active ? scheme.primary : scheme.onSurface);
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, color: color, size: small ? 27 : 36),
      padding: EdgeInsets.all(small ? 8 : 6),
      constraints: const BoxConstraints(minWidth: 50, minHeight: 50),
    );
  }
}

class _PlayButton extends StatelessWidget {
  const _PlayButton({required this.playing, required this.onPressed});

  final bool playing;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return IconButton.filled(
      onPressed: onPressed,
      tooltip: playing ? context.l10n.playerPause : context.l10n.playerPlay,
      iconSize: 38,
      style: IconButton.styleFrom(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        minimumSize: const Size(72, 72),
        shape: const CircleBorder(),
      ),
      icon: Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded),
    );
  }
}

class _GlassSheet extends StatelessWidget {
  const _GlassSheet({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: LiquidGlassCard(
        radius: 30,
        margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        padding: const EdgeInsets.fromLTRB(22, 14, 22, 28),
        blur: 26,
        tint: Theme.of(context).colorScheme.surface.withValues(alpha: .52),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 42, height: 4, decoration: BoxDecoration(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: .25), borderRadius: BorderRadius.circular(99)))),
            const SizedBox(height: 16),
            Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}
