import 'package:flutter/material.dart' hide RepeatMode;
import 'package:google_fonts/google_fonts.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import '../services/audio_service.dart';
import '../services/api_service.dart';
import '../services/settings_service.dart';
import '../models/ayah.dart';

class FullPlayerView extends StatefulWidget {
  final VoidCallback onCollapse;

  const FullPlayerView({super.key, required this.onCollapse});

  @override
  State<FullPlayerView> createState() => _FullPlayerViewState();
}

class _FullPlayerViewState extends State<FullPlayerView> {
  final AudioService _audioService = AudioService();
  final ApiService _apiService = ApiService();
  final SettingsService _settings = SettingsService();
  final ItemScrollController _itemScrollController = ItemScrollController();
  final ItemPositionsListener _itemPositionsListener =
      ItemPositionsListener.create();

  List<Ayah>? _ayahs;
  bool _loading = true;
  String? _error;
  int _lastAutoScrolledAyah = -1;
  bool _showTranslation = false;

  int? _startSurahNumber;
  String? _basmalahTranslation;

  @override
  void initState() {
    super.initState();
    _startSurahNumber = _audioService.currentSurah?.number;
    _audioService.addListener(_onAudioUpdate);
    _settings.addListener(_onSettingsUpdate);
    _loadLyrics();
  }

  @override
  void dispose() {
    _audioService.removeListener(_onAudioUpdate);
    _settings.removeListener(_onSettingsUpdate);
    super.dispose();
  }

  void _onSettingsUpdate() {
    if (mounted) {
      setState(() {});
      _loadLyrics(); // Reload lyrics with new settings
    }
  }

  void _onAudioUpdate() {
    if (!mounted) return;
    setState(() {});

    // Check if Surah changed
    final currentSurahNum = _audioService.currentSurah?.number;
    if (currentSurahNum != null && currentSurahNum != _startSurahNumber) {
      _startSurahNumber = currentSurahNum;
      _loadLyrics();
    }

    // Auto-scroll logic
    if (_ayahs != null && _ayahs!.isNotEmpty) {
      final currentAyah = _audioService.currentAyah;
      if (currentAyah != _lastAutoScrolledAyah) {
        _scrollToAyah(currentAyah);
        _lastAutoScrolledAyah = currentAyah;
      }
    }
  }

  Future<void> _loadLyrics() async {
    final surah = _audioService.currentSurah;
    if (surah == null) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // Fetch Basmalah if needed
      if (_hasBismillah(surah.number)) {
        try {
          final fatihah = await _apiService.fetchSurahDetails(
            1,
            edition: _settings.defaultTranslation,
          );
          if (fatihah.isNotEmpty) {
            _basmalahTranslation = fatihah.first.translation;
          }
        } catch (e) {
          debugPrint('Error fetching Basmalah: $e');
        }
      }

      final cachedAyahs = await _apiService.fetchSurahDetails(
        surah.number,
        edition: _settings.defaultTranslation,
      );

      // Race condition check
      if (_audioService.currentSurah?.number != surah.number) return;

      if (cachedAyahs.isNotEmpty && cachedAyahs.first.translation.isNotEmpty) {
        // Full cache hit - show immediately
        if (mounted) {
          setState(() {
            _ayahs = cachedAyahs;
            _loading = false;
          });
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _scrollToAyah(_audioService.currentAyah);
          });
        }
        return;
      }

      final arabicAyahs = await _apiService.fetchArabicOnly(surah.number);

      // Race condition check
      if (_audioService.currentSurah?.number != surah.number) return;

      if (mounted) {
        setState(() {
          _ayahs = arabicAyahs;
          _loading = false;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToAyah(_audioService.currentAyah);
        });
      }

      // STEP 3: Fetch translation in background, then update UI
      // STEP 3: Fetch translation in background, then update UI
      _apiService
          .fetchTranslation(
            surah.number,
            arabicAyahs,
            edition: _settings.defaultTranslation,
          )
          .then((fullAyahs) {
            if (mounted && _audioService.currentSurah?.number == surah.number) {
              setState(() {
                _ayahs = fullAyahs;
              });
            }
          });
    } catch (e) {
      if (mounted)
        setState(() {
          _loading = false;
          _error = e.toString();
        });
    }
  }

  bool _hasBismillah(int surahNumber) {
    return surahNumber != 1 && surahNumber != 9;
  }

  void _scrollToAyah(int ayahNumber) {
    if (_ayahs == null) return;

    // Calculate index based on Bismillah presence
    int index = ayahNumber - 1;
    final int surahNum = _audioService.currentSurah?.number ?? 0;

    if (_hasBismillah(surahNum)) {
      // Index 1 is Ayah 1
      // So if ayahNumber comes as 0 -> index 0
      // If ayahNumber comes as 1 -> index 1
      index = ayahNumber;
    }

    if (index >= 0 &&
        index < (_ayahs!.length + (_hasBismillah(surahNum) ? 1 : 0))) {
      try {
        _itemScrollController.scrollTo(
          index: index,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
          alignment: 0.1, // Move active item near top (0.1)
        );
      } catch (e) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final surah = _audioService.currentSurah;
    if (surah == null) return const SizedBox.shrink();

    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Column(
        children: [
          // Header
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.keyboard_arrow_down,
                      color: colorScheme.onSurface,
                      size: 32,
                    ),
                    onPressed: widget.onCollapse,
                  ),
                  Column(
                    children: [
                      Text(
                        "NOW PLAYING",
                        style: GoogleFonts.spaceGrotesk(
                          color: colorScheme.primary,
                          fontSize: 10,
                          letterSpacing: 1,
                        ),
                      ),
                      Text(
                        surah.name,
                        style: GoogleFonts.spaceGrotesk(
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.translate,
                      color: _showTranslation
                          ? colorScheme.primary
                          : colorScheme.onSurface,
                    ),
                    onPressed: () {
                      setState(() {
                        _showTranslation = !_showTranslation;
                      });
                      // Re-scroll to keep active item visible after height change
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        _scrollToAyah(_audioService.currentAyah);
                      });
                    },
                  ),
                ],
              ),
            ),
          ),

          // Lyrics List
          Expanded(child: _buildBody()),

          // Footer Controls
          _buildControls(),
        ],
      ),
    );
  }

  Widget _buildBody() {
    final colorScheme = Theme.of(context).colorScheme;
    if (_loading)
      return Center(
        child: CircularProgressIndicator(color: colorScheme.primary),
      );
    if (_error != null || (_ayahs == null || _ayahs!.isEmpty)) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.wifi_off_outlined,
                size: 64,
                color: colorScheme.primary,
              ),
              const SizedBox(height: 24),
              Text(
                'Failed to Load Data',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Please check your internet connection.',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 14,
                  color: colorScheme.onSurface.withValues(alpha: 0.5),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () {
                  _loadLyrics();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(0),
                  ),
                ),
                child: Text(
                  'Try Again',
                  style: GoogleFonts.spaceGrotesk(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 48),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: colorScheme.outline),
                  borderRadius: BorderRadius.circular(0),
                  color: Theme.of(context).cardColor,
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.offline_pin_outlined,
                          color: colorScheme.onSurface.withValues(alpha: 0.5),
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Offline Access',
                            style: GoogleFonts.spaceGrotesk(
                              color: colorScheme.onSurface,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'To access this page without internet, please download the "Arabic" and "${_settings.formatEditionName(_settings.defaultTranslation)}" editions via the Download button on the main page.',
                      style: GoogleFonts.spaceGrotesk(
                        color: colorScheme.onSurface.withValues(alpha: 0.5),
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    final surahNum = _audioService.currentSurah?.number ?? 0;
    final hasBismillah = _hasBismillah(surahNum);

    // If hasBismillah, total count is +1
    final itemCount = _ayahs!.length + (hasBismillah ? 1 : 0);

    return ScrollablePositionedList.builder(
      itemCount: itemCount,
      itemScrollController: _itemScrollController,
      itemPositionsListener: _itemPositionsListener,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 80),
      itemBuilder: (context, index) {
        Ayah ayah;
        bool isBismillah = false;

        if (hasBismillah) {
          if (index == 0) {
            isBismillah = true;
            // Construct specialized Ayah object for Bismillah
            ayah = Ayah(
              number: 0,
              arabic: "بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ",
              translation:
                  _basmalahTranslation ??
                  "In the name of Allah, the Entirely Merciful, the Especially Merciful",
            );
          } else {
            ayah = _ayahs![index - 1];
          }
        } else {
          ayah = _ayahs![index];
        }

        final isCurrent = _audioService.currentAyah == ayah.number;

        return GestureDetector(
          onTap: () {
            if (isBismillah) {
              _audioService.playAyah(_audioService.currentSurah!, 1);
            } else {
              _audioService.playAyah(_audioService.currentSurah!, ayah.number);
            }
          },
          child: Container(
            margin: isBismillah
                ? const EdgeInsets.fromLTRB(0, 24, 0, 0)
                : const EdgeInsets.symmetric(vertical: 0),
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            decoration: BoxDecoration(
              color: isCurrent
                  ? colorScheme.primary.withValues(alpha: 0.08)
                  : Colors.transparent,
              border: Border(bottom: BorderSide(color: colorScheme.outline)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!isBismillah)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isCurrent
                              ? Colors.transparent
                              : Theme.of(context).cardColor,
                          border: Border.all(
                            color: isCurrent
                                ? colorScheme.primary
                                : colorScheme.outline,
                          ),
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(
                          _settings.formatNumber(ayah.number),
                          style: GoogleFonts.spaceGrotesk(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                // Arabic text
                if (!isBismillah) const SizedBox(height: 16),
                Text(
                  ayah.arabic,
                  textAlign: TextAlign.right,
                  style: GoogleFonts.amiri(
                    fontSize: isCurrent ? 28 : 24,
                    color: isCurrent
                        ? colorScheme.primary
                        : colorScheme.onSurface,
                    height: 2.2,
                  ),
                ),
                // Translation
                if (_showTranslation && ayah.translation.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    ayah.translation,
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 16,
                      color: isCurrent
                          ? colorScheme.onSurface.withValues(alpha: 0.7)
                          : colorScheme.onSurface.withValues(alpha: 0.5),
                      height: 1.6,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildControls() {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF0D0D0D)
            : const Color(0xFFF5F5F5),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton.icon(
                onPressed: (_audioService.currentAyah > 1)
                    ? () => _audioService.playAyah(
                        _audioService.currentSurah!,
                        _audioService.currentAyah - 1,
                      )
                    : null,
                icon: Icon(
                  Icons.skip_previous_rounded,
                  color: (_audioService.currentAyah > 1)
                      ? colorScheme.onSurface.withValues(alpha: 0.54)
                      : colorScheme.onSurface.withValues(alpha: 0.1),
                ),
                label: Text(
                  "Prev Ayah",
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 12,
                    color: (_audioService.currentAyah > 1)
                        ? colorScheme.onSurface.withValues(alpha: 0.54)
                        : colorScheme.onSurface.withValues(alpha: 0.1),
                  ),
                ),
              ),
              TextButton.icon(
                onPressed:
                    (_audioService.currentSurah != null &&
                        _audioService.currentAyah <
                            _audioService.currentSurah!.totalAyahs)
                    ? () => _audioService.playAyah(
                        _audioService.currentSurah!,
                        _audioService.currentAyah + 1,
                      )
                    : null,
                label: Text(
                  "Next Ayah",
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 12,
                    color:
                        (_audioService.currentSurah != null &&
                            _audioService.currentAyah <
                                _audioService.currentSurah!.totalAyahs)
                        ? colorScheme.onSurface.withValues(alpha: 0.54)
                        : colorScheme.onSurface.withValues(alpha: 0.1),
                  ),
                ),
                icon: Icon(
                  Icons.skip_next_rounded,
                  color:
                      (_audioService.currentSurah != null &&
                          _audioService.currentAyah <
                              _audioService.currentSurah!.totalAyahs)
                      ? colorScheme.onSurface.withValues(alpha: 0.54)
                      : colorScheme.onSurface.withValues(alpha: 0.1),
                ),
              ),
            ],
          ),

          const SizedBox(height: 6),

          // Main Audio Controls
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Repeat Mode
              IconButton(
                iconSize: 16,
                icon: Icon(
                  _getRepeatIcon(_audioService.repeatMode),
                  color: _audioService.repeatMode == RepeatMode.none
                      ? colorScheme.onSurface.withValues(alpha: 0.38)
                      : colorScheme.primary,
                ),
                onPressed: _audioService.toggleRepeatMode,
              ),

              // Prev Surah
              IconButton(
                iconSize: 24,
                icon: Icon(
                  Icons.skip_previous,
                  color: _audioService.hasPrevSurah()
                      ? colorScheme.onSurface
                      : colorScheme.onSurface.withValues(alpha: 0.38),
                ),
                onPressed: _audioService.hasPrevSurah()
                    ? _audioService.playPrevSurah
                    : null,
              ),

              // Play/Pause
              Container(
                decoration: BoxDecoration(
                  color: colorScheme.primary,
                  borderRadius: BorderRadius.circular(99),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x4040B779),
                      blurRadius: 20,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: IconButton(
                  iconSize: 32,
                  icon: Icon(
                    _audioService.isPlaying ? Icons.pause : Icons.play_arrow,
                    color: Colors.black,
                  ),
                  onPressed: () {
                    if (_audioService.isPlaying) {
                      _audioService.pause();
                    } else {
                      _audioService.resume();
                    }
                  },
                ),
              ),

              // Next Surah
              IconButton(
                iconSize: 24,
                icon: Icon(
                  Icons.skip_next,
                  color: _audioService.hasNextSurah()
                      ? colorScheme.onSurface
                      : colorScheme.onSurface.withValues(alpha: 0.38),
                ),
                onPressed: _audioService.hasNextSurah()
                    ? _audioService.playNextSurah
                    : null,
              ),

              // Surah Order
              IconButton(
                iconSize: 16,
                icon: Icon(
                  Icons.sort_rounded,
                  color: _audioService.surahOrder == SurahOrder.ascending
                      ? colorScheme.primary
                      : Colors.amber,
                ),
                onPressed: _audioService.toggleSurahOrder,
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _getRepeatIcon(RepeatMode mode) {
    switch (mode) {
      case RepeatMode.none:
        return Icons.stop_circle_outlined;
      case RepeatMode.autoNext:
        return Icons.repeat;
      case RepeatMode.repeatOne:
        return Icons.repeat_one;
    }
  }
}
