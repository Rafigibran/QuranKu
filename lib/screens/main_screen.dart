import 'package:flutter/material.dart';
import 'surah_list_screen.dart';
import 'prayer_times_screen.dart';
import 'murotal_screen.dart';
import 'playlist_screen.dart';
import 'settings_screen.dart';
import '../services/audio_service.dart';
import '../widgets/mini_player.dart';
import '../widgets/full_player_view.dart';

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
        const SnackBar(
          content: Text('Ketuk dua kali untuk keluar'),
          backgroundColor: Color(0xFF2A2A2A),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final hasAudio = _audioService.currentSurah != null;
    final colorScheme = Theme.of(context).colorScheme;

    final children = List<Widget>.generate(
      _screens.length,
      (index) => _screens[index] ?? const SizedBox.shrink(),
      growable: false,
    );

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Stack(
          children: [
            IndexedStack(index: _selectedIndex, children: children),
            if (!_showFullPlayer && hasAudio)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: MiniPlayer(
                  onTap: () => setState(() => _showFullPlayer = true),
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
            : Container(
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: colorScheme.outline)),
                ),
                child: NavigationBarTheme(
                  data: NavigationBarThemeData(
                    indicatorColor: colorScheme.primary.withOpacity(0.2),
                    labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
                    height: 52,
                    iconTheme: WidgetStateProperty.resolveWith((states) {
                      if (states.contains(WidgetState.selected)) {
                        return IconThemeData(size: 20, color: colorScheme.primary);
                      }
                      return IconThemeData(
                        size: 20,
                        color: colorScheme.onSurface.withOpacity(0.5),
                      );
                    }),
                  ),
                  child: NavigationBar(
                    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                    selectedIndex: _selectedIndex,
                    onDestinationSelected: _onItemTapped,
                    height: 52,
                    elevation: 0,
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
                        label: 'Daftar Putar',
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
      ),
    );
  }
}
