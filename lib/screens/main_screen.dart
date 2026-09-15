import 'package:flutter/material.dart';
import 'surah_list_screen.dart';
import 'prayer_times_screen.dart';
import 'murotal_screen.dart';
import 'playlist_screen.dart';
import 'settings_screen.dart';
import '../services/audio_service.dart';
import '../widgets/mini_player.dart';
import '../widgets/full_player_view.dart';
import '../widgets/liquid_glass.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  bool _showFullPlayer = false;
  final AudioService _audioService = AudioService();

  late final List<Widget?> _screens = List<Widget?>.filled(5, null);

  @override
  void initState() {
    super.initState();
    _screens[0] = const SurahListScreen();
    _audioService.addListener(_onAudioUpdate);
  }

  @override
  void dispose() {
    _audioService.removeListener(_onAudioUpdate);
    super.dispose();
  }

  Widget _screenForIndex(int index) {
    final existing = _screens[index];
    if (existing != null) return existing;

    switch (index) {
      case 0:
        _screens[index] = const SurahListScreen();
        break;
      case 1:
        _screens[index] = const PrayerTimesScreen();
        break;
      case 2:
        _screens[index] = const MurotalScreen();
        break;
      case 3:
        _screens[index] = const PlaylistScreen();
        break;
      case 4:
        _screens[index] = const SettingsScreen();
        break;
      default:
        _screens[index] = const SurahListScreen();
    }
    return _screens[index]!;
  }

  void _onAudioUpdate() {
    if (mounted) setState(() {});
  }

  void _onItemTapped(int index) {
    _screenForIndex(index);
    setState(() {
      _selectedIndex = index;
      _showFullPlayer = false;
    });
  }

  DateTime? _currentBackPressTime;

  Future<bool> _onWillPop() async {
    if (_showFullPlayer) {
      setState(() => _showFullPlayer = false);
      return false;
    }

    final now = DateTime.now();
    if (_currentBackPressTime == null ||
        now.difference(_currentBackPressTime!) > const Duration(seconds: 2)) {
      _currentBackPressTime = now;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Ketuk sekali lagi untuk keluar'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Theme.of(context).colorScheme.surface.withValues(alpha: 0.92),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          elevation: 8,
        ),
      );
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final hasAudio = _audioService.currentSurah != null;
    final children = List<Widget>.generate(
      _screens.length,
      (index) => _screens[index] ?? const SizedBox.shrink(),
      growable: false,
    );

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBody: true,
        body: Stack(
          children: [
            IndexedStack(index: _selectedIndex, children: children),
            if (!_showFullPlayer && hasAudio)
              Positioned(
                left: 16,
                right: 16,
                bottom: 108,
                child: SafeArea(
                  top: false,
                  bottom: false,
                  child: MiniPlayer(
                    onTap: () => setState(() => _showFullPlayer = true),
                  ),
                ),
              ),
            if (_showFullPlayer && hasAudio)
              Positioned.fill(
                child: FullPlayerView(
                  onCollapse: () => setState(() => _showFullPlayer = false),
                ),
              ),
          ],
        ),
        bottomNavigationBar: _showFullPlayer
            ? null
            : _buildReferenceNavigation(context),
      ),
    );
  }

  Widget _buildReferenceNavigation(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final selected = scheme.primary;
    final unselected = Colors.white.withValues(alpha: 0.78);

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(18, 6, 18, 12),
      child: LiquidGlassCard(
        radius: 34,
        blur: 28,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        tint: scheme.surface.withValues(alpha: 0.32),
        child: SizedBox(
          height: 86,
          child: Row(
            children: [
              _navItem(context, 0, Icons.home_rounded, 'Al-Quran', selected, unselected),
              _navItem(context, 1, Icons.mosque_rounded, 'Jadwal', selected, unselected),
              _navItem(context, 2, Icons.person_rounded, 'Murotal', selected, unselected),
              _navItem(context, 3, Icons.queue_music_rounded, 'Playlist', selected, unselected),
              _navItem(context, 4, Icons.settings_rounded, 'Pengaturan', selected, unselected),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(
    BuildContext context,
    int index,
    IconData icon,
    String label,
    Color selected,
    Color unselected,
  ) {
    final isSelected = _selectedIndex == index;

    return Expanded(
      child: Semantics(
        button: true,
        selected: isSelected,
        label: label,
        child: InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: () => _onItemTapped(index),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
            decoration: BoxDecoration(
              color: isSelected ? selected.withValues(alpha: 0.18) : Colors.transparent,
              borderRadius: BorderRadius.circular(28),
              border: isSelected ? Border.all(color: selected.withValues(alpha: 0.20)) : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedScale(
                  duration: const Duration(milliseconds: 180),
                  scale: isSelected ? 1.06 : 1.0,
                  child: Icon(icon, size: isSelected ? 31 : 28, color: isSelected ? selected : unselected),
                ),
                const SizedBox(height: 5),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontSize: 10.5,
                    height: 1,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: isSelected ? selected : unselected,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
