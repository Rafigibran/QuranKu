import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import 'surah_list_screen.dart';
import 'prayer_times_screen.dart';
import 'murotal_screen.dart';
import 'kajian_screen.dart';
import 'khatam_screen.dart';
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
  bool _hadAudio = false;
  final AudioService _audioService = AudioService();

  // 5-tab IA: Home (dashboard + baca) / Jadwal Shalat (waktu shalat) /
  // Murotal (audio) / Target (tujuan+progres) / Kajian (jadwal kajian).
  late final List<Widget?> _screens = List<Widget?>.filled(5, null);

  @override
  void initState() {
    super.initState();
    _screens[0] = const SurahListScreen();
    _hadAudio = _audioService.currentSurah != null;
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
        _screens[index] = const KhatamScreen();
        break;
      case 4:
        _screens[index] = const KajianScreen();
        break;
      default:
        _screens[index] = const SurahListScreen();
    }
    return _screens[index]!;
  }

  void _onAudioUpdate() {
    // Rebuild host only when player visibility changes (surah set/cleared).
    // Position ticks are consumed by MiniPlayer/FullPlayerView listeners.
    final hasAudio = _audioService.currentSurah != null;
    if (hasAudio != _hadAudio && mounted) {
      setState(() => _hadAudio = hasAudio);
    }
  }

  void _onItemTapped(int index) {
    _screenForIndex(index);
    setState(() {
      _selectedIndex = index;
      _showFullPlayer = false;
    });
  }

  List<NavigationDestination> _barDestinations(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return [
      NavigationDestination(icon: const Icon(Icons.home_outlined), selectedIcon: const Icon(Icons.home_rounded), label: l.navHome, tooltip: l.navHome),
      NavigationDestination(icon: const Icon(Icons.schedule_rounded), selectedIcon: const Icon(Icons.schedule), label: l.navJadwalShalat, tooltip: l.navJadwalShalat),
      NavigationDestination(icon: const Icon(Icons.audiotrack_outlined), selectedIcon: const Icon(Icons.audiotrack_rounded), label: l.navMurotal, tooltip: l.navMurotal),
      NavigationDestination(icon: const Icon(Icons.track_changes_outlined), selectedIcon: const Icon(Icons.track_changes_rounded), label: l.navTarget, tooltip: l.navTarget),
      NavigationDestination(icon: const Icon(Icons.school_outlined), selectedIcon: const Icon(Icons.school_rounded), label: l.navKajian, tooltip: l.navKajian),
    ];
  }

  List<NavigationRailDestination> _railDestinations(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return [
      NavigationRailDestination(icon: const Icon(Icons.home_outlined), selectedIcon: const Icon(Icons.home_rounded), label: Text(l.navHome)),
      NavigationRailDestination(icon: const Icon(Icons.schedule_rounded), selectedIcon: const Icon(Icons.schedule), label: Text(l.navJadwalShalat)),
      NavigationRailDestination(icon: const Icon(Icons.audiotrack_outlined), selectedIcon: const Icon(Icons.audiotrack_rounded), label: Text(l.navMurotal)),
      NavigationRailDestination(icon: const Icon(Icons.track_changes_outlined), selectedIcon: const Icon(Icons.track_changes_rounded), label: Text(l.navTarget)),
      NavigationRailDestination(icon: const Icon(Icons.school_outlined), selectedIcon: const Icon(Icons.school_rounded), label: Text(l.navKajian)),
    ];
  }

  Widget _playerStack(bool hasAudio) {
    return Stack(
      children: [
        IndexedStack(
          index: _selectedIndex,
          children: List<Widget>.generate(
            _screens.length,
            (index) => _screens[index] ?? const SizedBox.shrink(),
            growable: false,
          ),
        ),
        if (!_showFullPlayer && hasAudio)
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasAudio = _audioService.currentSurah != null;
    final content = _playerStack(hasAudio);

    // System Back is never trapped: it collapses the full player when open,
    // otherwise it follows the OS default (backgrounds the app at root).
    return PopScope(
      canPop: !_showFullPlayer,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _showFullPlayer) {
          setState(() => _showFullPlayer = false);
        }
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 840;
          Widget body = content;
          if (wide) {
            body = Row(
              children: [
                if (!_showFullPlayer)
                  NavigationRail(
                    selectedIndex: _selectedIndex,
                    onDestinationSelected: _onItemTapped,
                    labelType: NavigationRailLabelType.all,
                    destinations: _railDestinations(context),
                  ),
                Expanded(child: content),
              ],
            );
          }
          return Scaffold(
            backgroundColor: Theme.of(context).colorScheme.surface,
            body: body,
            bottomNavigationBar: _showFullPlayer || wide
                ? null
                : NavigationBar(
                    selectedIndex: _selectedIndex,
                    onDestinationSelected: _onItemTapped,
                    labelBehavior:
                        NavigationDestinationLabelBehavior.alwaysShow,
                    destinations: _barDestinations(context),
                  ),
          );
        },
      ),
    );
  }
}
