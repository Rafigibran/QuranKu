import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/audio_service.dart' as as_audio;
import '../services/background_audio_service.dart';
import '../services/settings_service.dart';
import '../services/api_service.dart';
import '../models/ayah.dart';
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

  @override
  void initState() {
    super.initState();
    _audio.addListener(_refresh);
    _background.addListener(_refresh);
    _settings.addListener(_refresh);
    _background.init();
  }

  @override
  void dispose() {
    _audio.removeListener(_refresh);
    _background.removeListener(_refresh);
    _settings.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _openBackgroundSound() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _GlassSheet(
        title: 'Suara latar',
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
                  title: const Text('Suara hujan'),
                  subtitle: const Text('Berjalan bersama audio Al-Qur’an'),
                  activeTrackColor: scheme.primary.withValues(alpha: .45),
                  activeThumbColor: scheme.primary,
                ),
                const SizedBox(height: 10),
                _volumeSlider(
                  'Volume Al-Qur’an',
                  _background.mainVolume,
                  (v) async {
                    await _background.setMainVolume(v);
                    setSheetState(() {});
                  },
                ),
                _volumeSlider(
                  'Volume hujan',
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

  Future<void> _openCurrentAyah() async {
    final surah = _audio.currentSurah;
    if (surah == null) return;
    final scheme = Theme.of(context).colorScheme;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => FutureBuilder<List<Ayah>>(
        future: _api.fetchSurahDetails(surah.number, edition: _settings.defaultTranslation),
        builder: (context, snapshot) {
          final ayahs = snapshot.data ?? const <Ayah>[];
          Ayah? current;
          for (final ayah in ayahs) {
            if (ayah.number == _audio.currentAyah) {
              current = ayah;
              break;
            }
          }
          return _GlassSheet(
            title: '${surah.name} • Ayat ${_audio.currentAyah}',
            child: snapshot.connectionState == ConnectionState.waiting
                ? Center(child: Padding(padding: const EdgeInsets.all(30), child: CircularProgressIndicator(color: scheme.primary)))
                : current == null
                    ? const Text('Ayat belum tersedia.')
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(current.arabic, textAlign: TextAlign.right, style: GoogleFonts.amiri(fontSize: 27, height: 2.0)),
                          const SizedBox(height: 18),
                          Text(current.translation, style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.55, color: scheme.onSurface.withValues(alpha: .72))),
                        ],
                      ),
          );
        },
      ),
    );
  }

  String _repeatLabel() {
    switch (_audio.repeatMode) {
      case as_audio.RepeatMode.repeatOne:
        return 'Ulang 1';
      case as_audio.RepeatMode.none:
        return 'Tidak mengulang';
      case as_audio.RepeatMode.autoNext:
        return 'Lanjut otomatis';
    }
  }

  @override
  Widget build(BuildContext context) {
    final surah = _audio.currentSurah;
    if (surah == null) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: const Color(0xFF061013),
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
                    children: [
                      LiquidGlassIconButton(icon: Icons.keyboard_arrow_down_rounded, onPressed: widget.onCollapse, tooltip: 'Tutup'),
                      const Spacer(),
                      LiquidGlassPill(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.keyboard_arrow_down_rounded, size: 17, color: scheme.onSurface),
                            const SizedBox(width: 4),
                            const Text('Suara latar', style: TextStyle(fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                      const Spacer(),
                      LiquidGlassIconButton(icon: _background.enabled ? Icons.water_drop_rounded : Icons.water_drop_outlined, onPressed: _openBackgroundSound, tooltip: 'Suara latar'),
                    ],
                  ),
                  const Spacer(flex: 2),
                  _Artwork(),
                  const SizedBox(height: 26),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(surah.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800, color: Colors.white)),
                            const SizedBox(height: 5),
                            Text('Ayat ${_settings.formatNumber(_audio.currentAyah)}  •  Murotal QuranKu', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white.withValues(alpha: .68))),
                          ],
                        ),
                      ),
                      LiquidGlassIconButton(icon: Icons.menu_book_rounded, onPressed: _openCurrentAyah, tooltip: 'Lihat ayat'),
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
                                data: SliderTheme.of(context).copyWith(trackHeight: 4, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6), overlayShape: const RoundSliderOverlayShape(overlayRadius: 16), activeTrackColor: Colors.white, inactiveTrackColor: Colors.white.withValues(alpha: .22), thumbColor: Colors.white),
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
                                  Text(_formatDuration(position), style: const TextStyle(color: Colors.white70, fontSize: 12)),
                                  Text('-${_formatDuration(duration - position < Duration.zero ? Duration.zero : duration - position)}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
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
                      _ControlButton(icon: _repeatIcon(), small: true, active: _audio.repeatMode != as_audio.RepeatMode.none, onPressed: _audio.toggleRepeatMode, tooltip: _repeatLabel()),
                      _ControlButton(icon: Icons.skip_previous_rounded, onPressed: _audio.hasPrevSurah() ? _audio.playPrevSurah : null),
                      _PlayButton(playing: _audio.isPlaying, onPressed: () => _audio.isPlaying ? _audio.pause() : _audio.resume()),
                      _ControlButton(icon: Icons.skip_next_rounded, onPressed: _audio.hasNextSurah() ? _audio.playNextSurah : null),
                      _ControlButton(icon: Icons.format_list_bulleted_rounded, small: true, active: _audio.surahOrder == as_audio.SurahOrder.descending, onPressed: _audio.toggleSurahOrder, tooltip: 'Urutan'),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _BottomAction(icon: Icons.cloud_outlined, label: 'Latar', active: _background.enabled, onTap: _openBackgroundSound),
                      _BottomAction(icon: Icons.menu_book_outlined, label: 'Ayat', onTap: _openCurrentAyah),
                      _BottomAction(icon: Icons.repeat_rounded, label: _repeatLabel(), active: _audio.repeatMode != as_audio.RepeatMode.none, onTap: _audio.toggleRepeatMode),
                      _BottomAction(icon: Icons.format_list_bulleted_rounded, label: 'Urutan', active: _audio.surahOrder == as_audio.SurahOrder.descending, onTap: _audio.toggleSurahOrder),
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
        return Icons.repeat_rounded;
      case as_audio.RepeatMode.autoNext:
        return Icons.repeat_rounded;
      case as_audio.RepeatMode.repeatOne:
        return Icons.repeat_one_rounded;
    }
  }

  Future<void> _seek(Duration value) async {
    final player = _audio;
    final position = value;
    // AudioService intentionally exposes streams but not a seek method.
    // Keep the progress bar informational until the service exposes seek().
    debugPrint('Seek requested: $position for ${player.currentSurah?.name}');
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
  }
}

class _PlayerBackdrop extends StatelessWidget {
  const _PlayerBackdrop();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF051010), Color(0xFF06161A), Color(0xFF073E37)],
          stops: [0.0, 0.58, 1.0],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -120,
            bottom: -140,
            child: Container(
              width: 420,
              height: 420,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [Color(0x6640B779), Color(0x00204020)]),
              ),
            ),
          ),
          Positioned(
            left: -160,
            bottom: 110,
            child: Container(
              width: 360,
              height: 360,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [Color(0x2230A98B), Color(0x00060E0F)]),
              ),
            ),
          ),
          BackdropFilter(filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12), child: Container(color: Colors.transparent)),
        ],
      ),
    );
  }
}

class _Artwork extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 230,
      height: 230,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [scheme.primary.withValues(alpha: .92), const Color(0xFF0D3B35)]),
        boxShadow: const [BoxShadow(color: Color(0x5534B785), blurRadius: 42, spreadRadius: 4)],
        border: Border.all(color: Colors.white.withValues(alpha: .16), width: 1.4),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.menu_book_rounded, color: Colors.white, size: 70),
            const SizedBox(height: 10),
            Text('QuranKu', style: GoogleFonts.spaceGrotesk(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 22)),
          ],
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
    final color = onPressed == null ? Colors.white24 : (active ? Theme.of(context).colorScheme.primary : Colors.white);
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
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(shape: BoxShape.circle, color: scheme.primary, boxShadow: const [BoxShadow(color: Color(0x5534B785), blurRadius: 28, spreadRadius: 2)]),
        child: Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded, color: Colors.white, size: 38),
      ),
    );
  }
}

class _BottomAction extends StatelessWidget {
  const _BottomAction({required this.icon, required this.label, required this.onTap, this.active = false});

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: active ? scheme.primary : Colors.white70, size: 24),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 11, color: active ? scheme.primary : Colors.white60, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _GlassSheet extends StatelessWidget {
  const _GlassSheet({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: scheme.surface.withValues(alpha: .96),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        ),
        padding: const EdgeInsets.fromLTRB(22, 12, 22, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 42, height: 4, decoration: BoxDecoration(color: scheme.outline, borderRadius: BorderRadius.circular(99)))),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(child: Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800))),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
              ],
            ),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}
