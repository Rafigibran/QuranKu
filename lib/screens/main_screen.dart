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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
        body: Stack(
          children: [
            IndexedStack(index: _selectedIndex, children: children),
            if (!_showFullPlayer && hasAudio)
              Positioned(
                left: 14,
                right: 14,
                bottom: 8,
                child: SafeArea(
                  bottom: false,
                  child: LiquidGlassCard(
                    radius: 22,
                    padding: EdgeInsets.zero,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(22),
                      child: MiniPlayer(
                        onTap: () => setState(() => _showFullPlayer = true),
                      ),
                    ),
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
            : _buildGlassNavigation(context, hasAudio),
      ),
    );
  }

  Widget _buildGlassNavigation(BuildContext context, bool hasAudio) {
    final scheme = Theme.of(context).colorScheme;
    final selected = scheme.primary;
    final unselected = scheme.onSurface.withValues(alpha: 0.55);

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: LiquidGlassCard(
        radius: 28,
        padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
        blur: 20,
        child: NavigationBarTheme(
          data: NavigationBarThemeData(
            backgroundColor: Colors.transparent,
            indicatorColor: selected.withValues(alpha: 0.13),
            indicatorShape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            labelTextStyle: WidgetStatePropertyAll(
              Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 10,
                  ),
            ),
            iconTheme: WidgetStateProperty.resolveWith((states) {
              final isSelected = states.contains(WidgetState.selected);
              return IconThemeData(
                size: isSelected ? 25 : 23,
                color: isSelected ? selected : unselected,
              );
            }),
          ),
          child: NavigationBar(
            backgroundColor: Colors.transparent,
            selectedIndex: _selectedIndex,
            onDestinationSelected: _onItemTapped,
            height: 68,
            elevation: 0,
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.auto_stories_outlined),
                selectedIcon: Icon(Icons.auto_stories),
                label: 'Al-Quran',
              ),
              NavigationDestination(
                icon: Icon(Icons.mosque_outlined),
                selectedIcon: Icon(Icons.mosque),
                label: 'Jadwal',
              ),
              NavigationDestination(
                icon: Icon(Icons.headphones_outlined),
                selectedIcon: Icon(Icons.headphones),
                label: 'Murotal',
              ),
              NavigationDestination(
                icon: Icon(Icons.queue_music_outlined),
                selectedIcon: Icon(Icons.queue_music),
                label: 'Playlist',
              ),
              NavigationDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings),
                label: 'Pengaturan',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
