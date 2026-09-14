import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/audio_service.dart';
import '../services/settings_service.dart';
import '../services/background_audio_service.dart';

class MiniPlayer extends StatefulWidget {
  final VoidCallback onTap;

  const MiniPlayer({super.key, required this.onTap});

  @override
  State<MiniPlayer> createState() => _MiniPlayerState();
}

class _MiniPlayerState extends State<MiniPlayer> {
  final AudioService _audioService = AudioService();
  final SettingsService _settings = SettingsService();
  final BackgroundAudioService _background = BackgroundAudioService();

  @override
  void initState() {
    super.initState();
    _audioService.addListener(_update);
    _settings.addListener(_update);
    _background.addListener(_update);
    _background.init().then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _audioService.removeListener(_update);
    _settings.removeListener(_update);
    _background.removeListener(_update);
    super.dispose();
  }

  void _update() {
    if (mounted) setState(() {});
  }

  Future<void> _showBackgroundControls() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: StatefulBuilder(
            builder: (context, setSheetState) {
              final colors = Theme.of(context).colorScheme;
              return Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.cloud_outlined, color: colors.primary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Background Sound',
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: colors.onSurface,
                            ),
                          ),
                        ),
                        Switch(
                          value: _background.enabled,
                          onChanged: (value) async {
                            await _background.setEnabled(value);
                            setSheetState(() {});
                          },
                        ),
                      ],
                    ),
                    Text(
                      'Suara hujan mengikuti pemutaran surah.',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 12,
                        color: colors.onSurface.withValues(alpha: 0.55),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Quran Volume  ${(_background.mainVolume * 100).round()}%',
                      style: GoogleFonts.spaceGrotesk(
                        color: colors.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Slider(
                      value: _background.mainVolume,
                      onChanged: (value) async {
                        await _background.setMainVolume(value);
                        setSheetState(() {});
                      },
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Rain Volume  ${(_background.backgroundVolume * 100).round()}%',
                      style: GoogleFonts.spaceGrotesk(
                        color: colors.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Slider(
                      value: _background.backgroundVolume,
                      onChanged: (value) async {
                        await _background.setBackgroundVolume(value);
                        setSheetState(() {});
                      },
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_audioService.currentSurah == null) return const SizedBox.shrink();

    final surah = _audioService.currentSurah!;
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        color: Theme.of(context).cardColor,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        surah.name,
                        style: GoogleFonts.spaceGrotesk(
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Ayah ${_settings.formatNumber(_audioService.currentAyah)}',
                        style: GoogleFonts.spaceGrotesk(
                          color: colorScheme.primary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      tooltip: 'Background sound',
                      icon: Icon(
                        _background.enabled
                            ? Icons.water_drop
                            : Icons.water_drop_outlined,
                        color: _background.enabled
                            ? colorScheme.primary
                            : colorScheme.onSurface,
                      ),
                      onPressed: _showBackgroundControls,
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.skip_previous,
                        color: colorScheme.onSurface,
                      ),
                      onPressed: _audioService.hasPrevSurah()
                          ? _audioService.playPrevSurah
                          : null,
                    ),
                    IconButton(
                      icon: Icon(
                        _audioService.isPlaying
                            ? Icons.pause_circle_filled
                            : Icons.play_circle_fill,
                        size: 40,
                        color: colorScheme.primary,
                      ),
                      onPressed: () {
                        if (_audioService.isPlaying) {
                          _audioService.pause();
                        } else {
                          _audioService.resume();
                        }
                      },
                    ),
                    IconButton(
                      icon: Icon(Icons.skip_next, color: colorScheme.onSurface),
                      onPressed: _audioService.hasNextSurah()
                          ? _audioService.playNextSurah
                          : null,
                    ),
                  ],
                ),
              ],
            ),
            if (_audioService.isBuffering)
              LinearProgressIndicator(
                color: colorScheme.primary,
                backgroundColor: colorScheme.surfaceContainerHighest,
                minHeight: 2,
              ),
          ],
        ),
      ),
    );
  }
}
