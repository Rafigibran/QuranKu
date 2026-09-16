import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../services/audio_service.dart';
import '../services/background_audio_service.dart';
import '../services/settings_service.dart';
import 'liquid_glass.dart';

/// Single live lamp in the system: the playing state.
/// Docked tonal bar above the Material nav; progress reads as one
/// continuous thread (the tasbih string), not a floating glass pill.
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
      isScrollControlled: true,
      builder: (context) => SafeArea(
        top: false,
        child: LiquidGlassCard(
          radius: 24,
          margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          padding: const EdgeInsets.fromLTRB(22, 14, 22, 28),
          child: StatefulBuilder(
            builder: (context, setSheetState) {
              final scheme = Theme.of(context).colorScheme;
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: scheme.primary.withValues(alpha: .14),
                        ),
                        child: Icon(
                          Icons.water_drop_rounded,
                          color: scheme.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.l10n.playerBackgroundSound,
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            Text(
                              context.l10n.playerBackgroundSoundSubtitle,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: scheme.onSurfaceVariant),
                            ),
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
                  _slider(context.l10n.playerVolumeQuran, _background.mainVolume, (
                    value,
                  ) async {
                    await _background.setMainVolume(value);
                    setSheetState(() {});
                  }),
                  _slider(
                    context.l10n.playerVolumeRain,
                    _background.backgroundVolume,
                    (value) async {
                      await _background.setBackgroundVolume(value);
                      setSheetState(() {});
                    },
                  ),
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
            Text(
              '${(value * 100).round()}%',
              style: TextStyle(
                color: scheme.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        Slider(value: value.clamp(0.0, 1.0), onChanged: onChanged),
        const SizedBox(height: 4),
      ],
    );
  }

  Future<void> _togglePlay() async {
    if (_audio.isPlaying) {
      await _audio.pause();
    } else {
      await _audio.resume();
    }
  }

  void _openPlayer() {
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final surah = _audio.currentSurah;
    if (surah == null) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final progress = StreamBuilder<Duration>(
      stream: _audio.positionStream,
      builder: (context, positionSnapshot) {
        return StreamBuilder<Duration?>(
          stream: _audio.durationStream,
          builder: (context, durationSnapshot) {
            final duration = durationSnapshot.data ?? Duration.zero;
            final position = positionSnapshot.data ?? Duration.zero;
            final total = duration.inMilliseconds;
            final current = total > 0
                ? (position.inMilliseconds / total).clamp(0.0, 1.0)
                : 0.0;
            return ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                minHeight: 4,
                value: current,
                backgroundColor: scheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(scheme.primary),
              ),
            );
          },
        );
      },
    );

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: scheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.35)
                : Colors.black.withValues(alpha: 0.08),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
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
                      borderRadius: BorderRadius.circular(16),
                      color: scheme.primary,
                    ),
                    child: Icon(
                      Icons.menu_book_rounded,
                      color: scheme.onPrimary,
                      size: 28,
                    ),
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _openPlayer,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Row(
                        children: [
                          if (_audio.isPlaying)
                            Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: scheme.tertiary,
                              ),
                            ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${surah.number}. ${surah.name}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(
                                        fontWeight: FontWeight.w800,
                                        color: scheme.onSurface,
                                        height: 1.1,
                                      ),
                                ),
                                Text(
                                  'QS ${surah.number}:${_settings.formatNumber(_audio.currentAyah)} • ${_audio.isPlaying ? "Diputar" : "Jeda"}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.labelSmall
                                      ?.copyWith(
                                        color: scheme.onSurfaceVariant,
                                        fontWeight: FontWeight.w600,
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
                _actionButton(
                  Icons.water_drop_outlined,
                  _background.enabled
                      ? scheme.primary
                      : scheme.onSurfaceVariant,
                  _openBackground,
                  context.l10n.playerBackgroundSound,
                ),
                const SizedBox(width: 5),
                _playAction(scheme),
                const SizedBox(width: 5),
                _actionButton(
                  Icons.skip_next_rounded,
                  _audio.hasNextSurah()
                      ? scheme.onSurface
                      : scheme.onSurface.withValues(alpha: .38),
                  _audio.hasNextSurah() ? _audio.playNextSurah : null,
                  'Berikutnya',
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: progress,
          ),
        ],
      ),
    );
  }

  Widget _playAction(ColorScheme scheme) {
    return Tooltip(
      message: _audio.isPlaying ? 'Jeda' : 'Putar',
      child: Material(
        color: scheme.primary,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: _togglePlay,
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            width: 48,
            height: 48,
            child: Center(
              child: Icon(
                _audio.isPlaying
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
                color: scheme.onPrimary,
                size: 26,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _actionButton(
    IconData icon,
    Color color,
    VoidCallback? onTap,
    String tooltip,
  ) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            width: 48,
            height: 48,
            child: Center(child: Icon(icon, color: color, size: 26)),
          ),
        ),
      ),
    );
  }
}
