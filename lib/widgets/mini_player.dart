import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/audio_service.dart';
import '../services/background_audio_service.dart';
import '../services/settings_service.dart';
import 'liquid_glass.dart';

class MiniPlayer extends StatefulWidget {
  final VoidCallback onTap;

  const MiniPlayer({super.key, required this.onTap});

  @override
  State<MiniPlayer> createState() => _MiniPlayerState();
}

class _MiniPlayerState extends State<MiniPlayer> {
  final AudioService _audio = AudioService();
  final SettingsService _settings = SettingsService();
  final BackgroundAudioService _background = BackgroundAudioService();

  @override
  void initState() {
    super.initState();
    _audio.addListener(_refresh);
    _settings.addListener(_refresh);
    _background.addListener(_refresh);
    _background.init();
  }

  @override
  void dispose() {
    _audio.removeListener(_refresh);
    _settings.removeListener(_refresh);
    _background.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _openBackground() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        top: false,
        child: LiquidGlassCard(
          radius: 30,
          margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          padding: const EdgeInsets.fromLTRB(22, 14, 22, 28),
          blur: 26,
          tint: Theme.of(context).colorScheme.surface.withValues(alpha: .52),
          child: StatefulBuilder(
            builder: (context, setSheetState) {
              final scheme = Theme.of(context).colorScheme;
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: Container(width: 42, height: 4, decoration: BoxDecoration(color: scheme.onSurface.withValues(alpha: .25), borderRadius: BorderRadius.circular(99)))),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Container(width: 44, height: 44, decoration: BoxDecoration(shape: BoxShape.circle, color: scheme.primary.withValues(alpha: .14)), child: Icon(Icons.water_drop_rounded, color: scheme.primary)),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Suara latar', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)), Text('Berjalan bersama murotal.', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onSurface.withValues(alpha: .62)))])),
                      Switch.adaptive(value: _background.enabled, onChanged: (value) async { await _background.setEnabled(value); setSheetState(() {}); }),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _slider('Volume Al-Qur’an', _background.mainVolume, (value) async { await _background.setMainVolume(value); setSheetState(() {}); }),
                  _slider('Volume hujan', _background.backgroundVolume, (value) async { await _background.setBackgroundVolume(value); setSheetState(() {}); }),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _slider(String title, double value, ValueChanged<double> onChanged) {
    final scheme = Theme.of(context).colorScheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w700)), Text('${(value * 100).round()}%', style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w800))]),
      Slider(value: value.clamp(0.0, 1.0), onChanged: onChanged),
      const SizedBox(height: 4),
    ]);
  }

  Future<void> _togglePlay() async {
    if (_audio.isPlaying) {
      await _audio.pause();
    } else {
      await _audio.resume();
    }
  }

  Future<void> _openPlayer() async {
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final surah = _audio.currentSurah;
    if (surah == null) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    final progress = StreamBuilder<Duration>(
      stream: _audio.positionStream,
      builder: (context, positionSnapshot) {
        return StreamBuilder<Duration?>(
          stream: _audio.durationStream,
          builder: (context, durationSnapshot) {
            final duration = durationSnapshot.data ?? Duration.zero;
            final position = positionSnapshot.data ?? Duration.zero;
            final total = duration.inMilliseconds;
            final current = total > 0 ? (position.inMilliseconds / total).clamp(0.0, 1.0) : 0.0;
            return ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                minHeight: 3,
                value: current,
                backgroundColor: Colors.white.withValues(alpha: .10),
                valueColor: AlwaysStoppedAnimation<Color>(scheme.primary),
              ),
            );
          },
        );
      },
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          decoration: BoxDecoration(
            color: scheme.surface.withValues(alpha: .68),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withValues(alpha: .10)),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .22), blurRadius: 24, offset: const Offset(0, 10))],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 9, 10, 8),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: _openPlayer,
                      child: Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(17),
                          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [scheme.primary, scheme.primary.withValues(alpha: .34)]),
                          border: Border.all(color: Colors.white.withValues(alpha: .13)),
                        ),
                        child: const Icon(Icons.menu_book_rounded, color: Colors.white, size: 28),
                      ),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: _openPlayer,
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('${surah.number}. ${surah.name}', maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.spaceGrotesk(fontSize: 15.5, fontWeight: FontWeight.w800, color: scheme.onSurface)),
                          const SizedBox(height: 3),
                          Text('Mishary Rashid Alafasy  •  Ayat ${_settings.formatNumber(_audio.currentAyah)}', maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.spaceGrotesk(fontSize: 11.5, color: scheme.onSurface.withValues(alpha: .60))),
                        ]),
                      ),
                    ),
                    _actionButton(Icons.water_drop_outlined, _background.enabled ? scheme.primary : scheme.onSurface.withValues(alpha: .72), _openBackground, 'Suara latar'),
                    const SizedBox(width: 5),
                    _actionButton(_audio.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, scheme.onSurface, _togglePlay, _audio.isPlaying ? 'Jeda' : 'Putar'),
                    const SizedBox(width: 5),
                    _actionButton(Icons.skip_next_rounded, _audio.hasNextSurah() ? scheme.onSurface : scheme.onSurface.withValues(alpha: .26), _audio.hasNextSurah() ? _audio.playNextSurah : null, 'Berikutnya'),
                  ],
                ),
              ),
              Padding(padding: const EdgeInsets.fromLTRB(12, 0, 12, 0), child: progress),
            ],
          ),
        ),
      ),
    );
  }

  Widget _actionButton(IconData icon, Color color, VoidCallback? onTap, String tooltip) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(17),
          child: SizedBox(width: 47, height: 47, child: Center(child: Icon(icon, color: color, size: 26))),
        ),
      ),
    );
  }
}
