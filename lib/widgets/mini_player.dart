import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/audio_service.dart';
import '../services/settings_service.dart';
import '../services/background_audio_service.dart';
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
      builder: (context) => SafeArea(
        top: false,
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface.withValues(alpha: .97),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.fromLTRB(22, 14, 22, 28),
          child: StatefulBuilder(
            builder: (context, setSheetState) {
              final scheme = Theme.of(context).colorScheme;
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: Container(width: 42, height: 4, decoration: BoxDecoration(color: scheme.outline, borderRadius: BorderRadius.circular(99)))),
                  const SizedBox(height: 20),
                  Text('Suara latar', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Text('Suara hujan mengikuti pemutaran surah.', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onSurface.withValues(alpha: .62))),
                  const SizedBox(height: 12),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Aktifkan suara hujan'),
                    value: _background.enabled,
                    onChanged: (value) async {
                      await _background.setEnabled(value);
                      setSheetState(() {});
                    },
                  ),
                  const SizedBox(height: 4),
                  _slider('Volume Al-Qur’an', _background.mainVolume, (value) async {
                    await _background.setMainVolume(value);
                    setSheetState(() {});
                  }),
                  _slider('Volume hujan', _background.backgroundVolume, (value) async {
                    await _background.setBackgroundVolume(value);
                    setSheetState(() {});
                  }),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w700)), Text('${(value * 100).round()}%', style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w700))]),
        Slider(value: value, onChanged: onChanged),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final surah = _audio.currentSurah;
    if (surah == null) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;

    return LiquidGlassCard(
      radius: 22,
      padding: const EdgeInsets.fromLTRB(12, 8, 10, 8),
      tint: scheme.surface.withValues(alpha: .32),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: [scheme.primary.withValues(alpha: .85), scheme.primary.withValues(alpha: .35)]),
              ),
              child: const Icon(Icons.menu_book_rounded, color: Colors.white, size: 23),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(surah.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.spaceGrotesk(fontSize: 15, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text('Ayat ${_settings.formatNumber(_audio.currentAyah)}', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.primary, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            IconButton(tooltip: 'Suara latar', onPressed: _openBackground, icon: Icon(_background.enabled ? Icons.water_drop_rounded : Icons.water_drop_outlined, color: _background.enabled ? scheme.primary : scheme.onSurface.withValues(alpha: .72))),
            IconButton(tooltip: 'Sebelumnya', onPressed: _audio.hasPrevSurah() ? _audio.playPrevSurah : null, icon: const Icon(Icons.skip_previous_rounded)),
            SizedBox(
              width: 48,
              height: 48,
              child: LiquidGlassCard(
                radius: 16,
                padding: EdgeInsets.zero,
                tint: scheme.primary.withValues(alpha: .16),
                onTap: () => _audio.isPlaying ? _audio.pause() : _audio.resume(),
                child: Icon(_audio.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, color: scheme.primary, size: 27),
              ),
            ),
            IconButton(tooltip: 'Berikutnya', onPressed: _audio.hasNextSurah() ? _audio.playNextSurah : null, icon: const Icon(Icons.skip_next_rounded)),
          ],
        ),
      ),
    );
  }
}
