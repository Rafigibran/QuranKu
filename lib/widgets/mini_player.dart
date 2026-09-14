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
        child: LiquidGlassCard(
          radius: 30,
          margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          padding: const EdgeInsets.fromLTRB(22, 14, 22, 28),
          blur: 24,
          tint: Theme.of(context).colorScheme.surface.withValues(alpha: .45),
          child: StatefulBuilder(
            builder: (context, setSheetState) {
              final scheme = Theme.of(context).colorScheme;
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: scheme.onSurface.withValues(alpha: .28),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: scheme.primary.withValues(alpha: .14),
                        ),
                        child: Icon(Icons.water_drop_rounded, color: scheme.primary),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Suara latar', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                            Text('Suara hujan mengikuti pemutaran surah.', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onSurface.withValues(alpha: .62))),
                          ],
                        ),
                      ),
                      Switch.adaptive(
                        value: _background.enabled,
                        onChanged: (value) async {
                          await _background.setEnabled(value);
                          setSheetState(() {});
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
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
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            Text('${(value * 100).round()}%', style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w800)),
          ],
        ),
        Slider(value: value, onChanged: onChanged),
        const SizedBox(height: 6),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final surah = _audio.currentSurah;
    if (surah == null) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;

    return LiquidGlassCard(
      radius: 26,
      blur: 26,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      tint: scheme.surface.withValues(alpha: .34),
      child: Row(
        children: [
          GestureDetector(
            onTap: widget.onTap,
            child: Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    scheme.primary.withValues(alpha: .92),
                    const Color(0xFF143F37),
                  ],
                ),
                border: Border.all(color: Colors.white.withValues(alpha: .14)),
                boxShadow: [
                  BoxShadow(
                    color: scheme.primary.withValues(alpha: .18),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Icon(Icons.menu_book_rounded, color: Colors.white, size: 28),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.onTap,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${surah.number}. ${surah.name}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Mishary Rashid Alafasy • Ayat ${_settings.formatNumber(_audio.currentAyah)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 12,
                      color: scheme.onSurface.withValues(alpha: .62),
                    ),
                  ),
                ],
              ),
            ),
          ),
          _miniAction(
            icon: _background.enabled ? Icons.water_drop_rounded : Icons.water_drop_outlined,
            color: _background.enabled ? scheme.primary : scheme.onSurface.withValues(alpha: .76),
            tooltip: 'Suara latar',
            onPressed: _openBackground,
          ),
          _miniAction(
            icon: _audio.hasNextSurah() ? Icons.play_arrow_rounded : Icons.play_arrow_rounded,
            color: scheme.onSurface.withValues(alpha: .90),
            tooltip: 'Buka player',
            onPressed: widget.onTap,
          ),
          _miniAction(
            icon: Icons.skip_next_rounded,
            color: _audio.hasNextSurah() ? scheme.onSurface : scheme.onSurface.withValues(alpha: .30),
            tooltip: 'Berikutnya',
            onPressed: _audio.hasNextSurah() ? _audio.playNextSurah : null,
          ),
        ],
      ),
    );
  }

  Widget _miniAction({
    required IconData icon,
    required Color color,
    required String tooltip,
    required VoidCallback? onPressed,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: SizedBox(
        width: 48,
        height: 48,
        child: LiquidGlassCard(
          radius: 16,
          padding: EdgeInsets.zero,
          blur: 14,
          tint: scheme.surface.withValues(alpha: .20),
          onTap: onPressed,
          child: Icon(icon, color: color, size: 25),
        ),
      ),
    );
  }
}
