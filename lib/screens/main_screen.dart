import 'package:flutter/material.dart';
import 'surah_list_screen.dart';
import 'prayer_times_screen.dart';
import 'murotal_screen.dart';
import 'playlist_screen.dart';
import 'settings_screen.dart';
import 'package:google_fonts/google_fonts.dart';
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

  Widget _bottomItem(int index, IconData icon, String label) {
    final selected = _selectedIndex == index;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        onTap: () => _onItemTapped(index),
        borderRadius: BorderRadius.circular(18),
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 7),
            decoration: BoxDecoration(
              color: selected
                  ? Colors.white.withValues(alpha: .14)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  color: selected
                      ? Colors.white
                      : Colors.white.withValues(alpha: .62),
                  size: selected ? 23 : 21,
                ),
                const SizedBox(height: 3),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      label,
                      maxLines: 1,
                      softWrap: false,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.spaceGrotesk(
                        color: selected
                            ? Colors.white
                            : Colors.white.withValues(alpha: .62),
                        fontSize: 10.5,
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
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
        const SnackBar(content: Text('Ketuk sekali lagi untuk keluar')),
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
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Stack(
          children: [
            IndexedStack(index: _selectedIndex, children: children),
            if (!_showFullPlayer && hasAudio)
              Positioned(
                left: 16,
                right: 16,
                bottom: 12,
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
            : BottomAppBar(
                color: const Color(0xFF25364B),
                surfaceTintColor: Colors.transparent,
                elevation: 14,
                shape: const CircularNotchedRectangle(),
                notchMargin: 8,
                padding: EdgeInsets.zero,
                child: SizedBox(
                  height: 72,
                  child: Row(
                    children: [
                      Expanded(child: _bottomItem(0, Icons.home_rounded, 'Beranda')),
                      Expanded(child: _bottomItem(1, Icons.access_time_rounded, 'Jadwal')),
                      const SizedBox(width: 72),
                      Expanded(child: _bottomItem(3, Icons.queue_music_rounded, 'Playlist')),
                      Expanded(child: _bottomItem(4, Icons.tune_rounded, 'Pengaturan')),
                    ],
                  ),
                ),
              ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
        floatingActionButton: _showFullPlayer
            ? null
            : FloatingActionButton(
                heroTag: 'quran-nav',
                onPressed: () => _onItemTapped(2),
                backgroundColor: const Color(0xFFD4BE82),
                foregroundColor: const Color(0xFF25364B),
                elevation: 8,
                shape: const CircleBorder(),
                child: const Icon(Icons.menu_book_rounded, size: 29),
              ),
      ),
    );
  }
}
