import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/surah.dart';
import '../services/api_service.dart';
import '../services/audio_service.dart';

class PlaylistScreen extends StatefulWidget {
  const PlaylistScreen({super.key});

  @override
  State<PlaylistScreen> createState() => _PlaylistScreenState();
}

class _PlaylistScreenState extends State<PlaylistScreen> {
  static const _storageKey = 'quranku_playlist_numbers';

  final AudioService _audioService = AudioService();
  List<Surah> _surahs = [];
  List<int> _playlistNumbers = [];
  bool _loading = true;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _audioService.addListener(_onAudioUpdate);
    _load();
  }

  @override
  void dispose() {
    _audioService.removeListener(_onAudioUpdate);
    super.dispose();
  }

  void _onAudioUpdate() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getStringList(_storageKey) ?? <String>[];
      final surahs = await ApiService().fetchSurahs();
      final valid = stored
          .map(int.tryParse)
          .whereType<int>()
          .where((n) => n >= 1 && n <= 114)
          .toList();
      if (!mounted) return;
      setState(() {
        _surahs = surahs;
        _playlistNumbers = valid;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _storageKey,
      _playlistNumbers.map((number) => number.toString()).toList(),
    );
  }

  List<Surah> get _items {
    final byNumber = {for (final surah in _surahs) surah.number: surah};
    final result = <Surah>[];
    for (final number in _playlistNumbers) {
      final surah = byNumber[number];
      if (surah != null) result.add(surah);
    }
    return result;
  }

  List<Surah> get _availableToAdd {
    final selected = _playlistNumbers.toSet();
    final query = _query.trim().toLowerCase();
    return _surahs.where((surah) {
      if (selected.contains(surah.number)) return false;
      if (query.isEmpty) return true;
      return surah.name.toLowerCase().contains(query) ||
          surah.nameAr.contains(_query.trim()) ||
          surah.number.toString() == _query.trim();
    }).toList();
  }

  void _playFrom(int index) {
    final numbers = _playlistNumbers.toList();
    if (numbers.isEmpty || index < 0 || index >= numbers.length) return;
    _audioService.setCustomSurahSequence(numbers);
    final surah = _items[index];
    _audioService.playAyah(surah, 1);
  }

  void _move(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final value = _playlistNumbers.removeAt(oldIndex);
      _playlistNumbers.insert(newIndex, value);
    });
    _save();
  }

  Future<void> _addSurah(Surah surah) async {
    setState(() => _playlistNumbers.add(surah.number));
    await _save();
  }

  Future<void> _removeAt(int index) async {
    setState(() => _playlistNumbers.removeAt(index));
    await _save();
    if (_playlistNumbers.isEmpty) {
      _audioService.clearCustomSurahSequence();
    }
  }

  Future<void> _clear() async {
    if (_playlistNumbers.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Kosongkan Playlist?'),
        content: const Text('Semua Surah di daftar putar akan dihapus.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Hapus')),
        ],
      ),
    );
    if (confirmed == true) {
      setState(() => _playlistNumbers.clear());
      await _save();
      _audioService.clearCustomSurahSequence();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final items = _items;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        title: Text.rich(
          TextSpan(
            text: 'PLAYLIST',
            style: GoogleFonts.spaceGrotesk(fontSize: 24, fontWeight: FontWeight.bold, color: colors.onSurface),
            children: [TextSpan(text: '.', style: GoogleFonts.spaceGrotesk(color: colors.primary))],
          ),
        ),
        actions: [
          if (items.isNotEmpty)
            IconButton(onPressed: _clear, icon: const Icon(Icons.delete_sweep_outlined), tooltip: 'Clear playlist'),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _surahs.isEmpty ? null : () => _showAddDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('Tambah Surah'),
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: colors.primary))
          : items.isEmpty
              ? _emptyState(colors)
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
                      child: Row(
                        children: [
                          Icon(Icons.queue_music, color: colors.primary),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              '${items.length} Surah • Urutan bisa diubah',
                              style: GoogleFonts.spaceGrotesk(color: colors.onSurface.withValues(alpha: 0.65), fontSize: 12),
                            ),
                          ),
                          IconButton(
                            onPressed: () => _playFrom(0),
                            icon: Icon(Icons.play_arrow_rounded, color: colors.primary),
                            tooltip: 'Play playlist',
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ReorderableListView.builder(
                        padding: const EdgeInsets.fromLTRB(24, 4, 24, 120),
                        itemCount: items.length,
                        onReorder: _move,
                        itemBuilder: (context, index) {
                          final surah = items[index];
                          final playing = _audioService.currentSurah?.number == surah.number;
                          return Container(
                            key: ValueKey('playlist_${surah.number}'),
                            margin: const EdgeInsets.only(bottom: 10),
                            decoration: BoxDecoration(
                              border: Border.all(color: playing ? colors.primary : colors.outline),
                              color: playing ? colors.primary.withValues(alpha: 0.05) : Colors.transparent,
                            ),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: colors.primary.withValues(alpha: 0.12),
                                foregroundColor: colors.primary,
                                child: Text('${index + 1}', style: const TextStyle(fontWeight: FontWeight.bold)),
                              ),
                              title: Text(surah.name, style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold)),
                              subtitle: Text('${surah.nameAr} • ${surah.totalAyahs} Ayat', style: GoogleFonts.spaceGrotesk(fontSize: 11)),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    onPressed: () => _playFrom(index),
                                    icon: Icon(playing && _audioService.isPlaying ? Icons.pause_circle : Icons.play_circle, color: colors.primary, size: 30),
                                  ),
                                  IconButton(
                                    onPressed: () => _removeAt(index),
                                    icon: Icon(Icons.remove_circle_outline, color: colors.onSurface.withValues(alpha: 0.5)),
                                  ),
                                  const Icon(Icons.drag_handle),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _emptyState(ColorScheme colors) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.queue_music_outlined, size: 64, color: colors.primary),
            const SizedBox(height: 16),
            Text('Playlist masih kosong', style: GoogleFonts.spaceGrotesk(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              'Tambahkan Surah favorit dan susun urutannya. Tombol Next dan Previous akan mengikuti playlist ini.',
              textAlign: TextAlign.center,
              style: GoogleFonts.spaceGrotesk(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.6)),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(onPressed: () => _showAddDialog(context), icon: const Icon(Icons.add), label: const Text('Tambah Surah')),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddDialog(BuildContext context) async {
    _query = '';
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          final available = _availableToAdd;
          final colors = Theme.of(context).colorScheme;
          return SafeArea(
            child: SizedBox(
              height: MediaQuery.of(context).size.height * 0.82,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
                    child: Row(
                      children: [
                        Expanded(child: Text('Tambah ke Playlist', style: GoogleFonts.spaceGrotesk(fontSize: 18, fontWeight: FontWeight.bold))),
                        IconButton(onPressed: () => Navigator.pop(sheetContext), icon: const Icon(Icons.close)),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                    child: TextField(
                      onChanged: (value) => setSheetState(() => _query = value),
                      decoration: InputDecoration(
                        hintText: 'Cari Surah...',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: available.length,
                      itemBuilder: (_, index) {
                        final surah = available[index];
                        return ListTile(
                          title: Text(surah.name, style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w600)),
                          subtitle: Text('${surah.number}. ${surah.nameAr}'),
                          trailing: IconButton(
                            icon: Icon(Icons.add_circle_outline, color: colors.primary),
                            onPressed: () async {
                              await _addSurah(surah);
                              setSheetState(() {});
                              if (mounted) setState(() {});
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
