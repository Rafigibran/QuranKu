import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/surah.dart';
import '../services/api_service.dart';
import '../services/audio_service.dart';

class _Playlist {
  _Playlist({
    required this.id,
    required this.name,
    List<int>? surahNumbers,
  }) : surahNumbers = surahNumbers ?? <int>[];

  final String id;
  String name;
  final List<int> surahNumbers;

  factory _Playlist.fromJson(Map<String, dynamic> json) {
    final rawNumbers = json['surahNumbers'];
    return _Playlist(
      id: json['id']?.toString() ?? DateTime.now().microsecondsSinceEpoch.toString(),
      name: json['name']?.toString().trim().isNotEmpty == true
          ? json['name'].toString()
          : 'Playlist',
      surahNumbers: rawNumbers is List
          ? rawNumbers
              .map((value) => int.tryParse(value.toString()))
              .whereType<int>()
              .where((value) => value >= 1 && value <= 114)
              .toList()
          : <int>[],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'surahNumbers': surahNumbers,
      };
}

class PlaylistScreen extends StatefulWidget {
  const PlaylistScreen({super.key});

  @override
  State<PlaylistScreen> createState() => _PlaylistScreenState();
}

class _PlaylistScreenState extends State<PlaylistScreen> {
  static const _storageKey = 'quranku_playlists_v2';
  static const _legacyStorageKey = 'quranku_playlist_numbers';

  final AudioService _audioService = AudioService();
  List<Surah> _surahs = [];
  List<_Playlist> _playlists = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _audioService.addListener(_refresh);
    _load();
  }

  @override
  void dispose() {
    _audioService.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final surahs = await ApiService().fetchSurahs();
      final raw = prefs.getString(_storageKey);
      final loaded = <_Playlist>[];

      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          for (final item in decoded) {
            if (item is Map<String, dynamic>) {
              loaded.add(_Playlist.fromJson(item));
            } else if (item is Map) {
              loaded.add(_Playlist.fromJson(Map<String, dynamic>.from(item)));
            }
          }
        }
      }

      if (loaded.isEmpty) {
        final legacy = prefs.getStringList(_legacyStorageKey) ?? <String>[];
        final legacyNumbers = legacy
            .map(int.tryParse)
            .whereType<int>()
            .where((value) => value >= 1 && value <= 114)
            .toList();
        if (legacyNumbers.isNotEmpty) {
          loaded.add(_Playlist(
            id: DateTime.now().microsecondsSinceEpoch.toString(),
            name: 'Favorit',
            surahNumbers: legacyNumbers,
          ));
        }
      }

      if (!mounted) return;
      setState(() {
        _surahs = surahs;
        _playlists = loaded;
        _loading = false;
      });
      await _save();
    } catch (e) {
      debugPrint('Playlist load error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _storageKey,
      jsonEncode(_playlists.map((playlist) => playlist.toJson()).toList()),
    );
  }

  List<Surah> _itemsFor(_Playlist playlist) {
    final byNumber = {for (final surah in _surahs) surah.number: surah};
    return playlist.surahNumbers
        .map((number) => byNumber[number])
        .whereType<Surah>()
        .toList();
  }

  Future<void> _createPlaylist() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Playlist Baru'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textInputAction: TextInputAction.done,
          onSubmitted: (value) => Navigator.pop(dialogContext, value.trim()),
          decoration: const InputDecoration(
            labelText: 'Nama playlist',
            hintText: 'Kajian & Tilawah',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Buat'),
          ),
        ],
      ),
    );
    controller.dispose();

    final cleanName = name?.trim() ?? '';
    if (cleanName.isEmpty) return;

    setState(() {
      _playlists.add(_Playlist(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        name: cleanName,
      ));
    });
    await _save();
  }

  Future<void> _renamePlaylist(_Playlist playlist) async {
    final controller = TextEditingController(text: playlist.name);
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Ganti Nama Playlist'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Nama playlist'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    controller.dispose();

    final cleanName = name?.trim() ?? '';
    if (cleanName.isEmpty) return;
    setState(() => playlist.name = cleanName);
    await _save();
  }

  Future<void> _deletePlaylist(_Playlist playlist) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hapus Playlist?'),
        content: const Text(
          'Playlist ini dan Surah yang tersimpan di dalamnya akan dihapus.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _playlists.removeWhere((item) => item.id == playlist.id));
    if (_playlists.isEmpty) {
      _audioService.clearCustomSurahSequence();
    }
    await _save();
  }

  void _playPlaylist(_Playlist playlist, {int startIndex = 0}) {
    final items = _itemsFor(playlist);
    if (items.isEmpty || startIndex < 0 || startIndex >= items.length) return;

    _audioService.setCustomSurahSequence(playlist.surahNumbers);
    _audioService.playAyah(items[startIndex], 1);
  }

  Future<void> _openPlaylist(_Playlist playlist) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => _PlaylistDetailScreen(
          playlist: playlist,
          surahs: _surahs,
          audioService: _audioService,
          onChanged: () async {
            await _save();
            if (mounted) setState(() {});
          },
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        title: Text.rich(
          TextSpan(
            text: 'PLAYLIST',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: colors.onSurface,
            ),
            children: [
              TextSpan(
                text: '.',
                style: GoogleFonts.spaceGrotesk(color: colors.primary),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            onPressed: _createPlaylist,
            icon: const Icon(Icons.add),
            tooltip: 'Playlist baru',
          ),
        ],
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: colors.primary))
          : _playlists.isEmpty
              ? _buildEmptyHome(colors)
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(24, 10, 24, 120),
                  itemCount: _playlists.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final playlist = _playlists[index];
                    final items = _itemsFor(playlist);
                    final isPlaying = items.isNotEmpty &&
                        items.any((surah) => _audioService.currentSurah?.number == surah.number);
                    return _PlaylistCard(
                      playlist: playlist,
                      itemCount: items.length,
                      isPlaying: isPlaying,
                      colors: colors,
                      onTap: () => _openPlaylist(playlist),
                      onPlay: items.isEmpty ? null : () => _playPlaylist(playlist),
                      onRename: () => _renamePlaylist(playlist),
                      onDelete: () => _deletePlaylist(playlist),
                    );
                  },
                ),
    );
  }

  Widget _buildEmptyHome(ColorScheme colors) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.library_music_outlined, size: 68, color: colors.primary),
            const SizedBox(height: 18),
            const Text(
              'Buat playlist pertamamu',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Pisahkan Surah ke dalam banyak playlist, seperti Spotify.',
              textAlign: TextAlign.center,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 12,
                color: colors.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _createPlaylist,
              icon: const Icon(Icons.add),
              label: const Text('Buat Playlist'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaylistCard extends StatelessWidget {
  const _PlaylistCard({
    required this.playlist,
    required this.itemCount,
    required this.isPlaying,
    required this.colors,
    required this.onTap,
    required this.onPlay,
    required this.onRename,
    required this.onDelete,
  });

  final _Playlist playlist;
  final int itemCount;
  final bool isPlaying;
  final ColorScheme colors;
  final VoidCallback onTap;
  final VoidCallback? onPlay;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).cardColor,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(
              color: isPlaying ? colors.primary : colors.outline,
              width: isPlaying ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.10),
                  border: Border.all(color: colors.outline),
                ),
                child: Icon(Icons.queue_music, color: colors.primary, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      playlist.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.spaceGrotesk(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$itemCount Surah',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 11,
                        color: colors.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onPlay,
                icon: Icon(
                  isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill,
                  color: onPlay == null
                      ? colors.onSurface.withValues(alpha: 0.25)
                      : colors.primary,
                  size: 34,
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'rename') onRename();
                  if (value == 'delete') onDelete();
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'rename',
                    child: Text('Ganti Nama'),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Text('Hapus'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlaylistDetailScreen extends StatefulWidget {
  const _PlaylistDetailScreen({
    required this.playlist,
    required this.surahs,
    required this.audioService,
    required this.onChanged,
  });

  final _Playlist playlist;
  final List<Surah> surahs;
  final AudioService audioService;
  final Future<void> Function() onChanged;

  @override
  State<_PlaylistDetailScreen> createState() => _PlaylistDetailScreenState();
}

class _PlaylistDetailScreenState extends State<_PlaylistDetailScreen> {
  String _query = '';

  List<Surah> get _items {
    final byNumber = {for (final surah in widget.surahs) surah.number: surah};
    return widget.playlist.surahNumbers
        .map((number) => byNumber[number])
        .whereType<Surah>()
        .toList();
  }

  Future<void> _saveAndRefresh() async {
    await widget.onChanged();
    if (mounted) setState(() {});
  }

  void _playFrom(int index) {
    final items = _items;
    if (items.isEmpty || index < 0 || index >= items.length) return;
    widget.audioService.setCustomSurahSequence(widget.playlist.surahNumbers);
    widget.audioService.playAyah(items[index], 1);
  }

  Future<void> _addSurah(Surah surah) async {
    if (widget.playlist.surahNumbers.contains(surah.number)) return;
    setState(() => widget.playlist.surahNumbers.add(surah.number));
    await _saveAndRefresh();
  }

  Future<void> _removeSurah(Surah surah) async {
    setState(() => widget.playlist.surahNumbers.remove(surah.number));
    await _saveAndRefresh();
  }

  Future<void> _reorder(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex -= 1;
    setState(() {
      final value = widget.playlist.surahNumbers.removeAt(oldIndex);
      widget.playlist.surahNumbers.insert(newIndex, value);
    });
    await _saveAndRefresh();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final items = _items;
    final visible = _query.trim().isEmpty
        ? _surahCandidates(items, widget.surahs)
        : _surahCandidates(items, widget.surahs)
            .where((surah) =>
                surah.name.toLowerCase().contains(_query.toLowerCase()) ||
                surah.nameAr.contains(_query))
            .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.playlist.name),
        actions: [
          IconButton(
            onPressed: () async {
              for (final surah in items) {
                if (!widget.audioService.currentSurah!.number.toString().contains(surah.number.toString())) {
                  break;
                }
              }
              if (items.isNotEmpty) _playFrom(0);
            },
            icon: const Icon(Icons.play_arrow),
            tooltip: 'Putar playlist',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              onChanged: (value) => setState(() => _query = value),
              decoration: const InputDecoration(
                hintText: 'Tambah Surah ke playlist...',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          Expanded(
            child: ReorderableListView.builder(
              itemCount: visible.length,
              onReorder: (oldIndex, newIndex) async {
                final actualOld = widget.playlist.surahNumbers.indexOf(visible[oldIndex].number);
                final actualNew = widget.playlist.surahNumbers.indexOf(visible[newIndex.clamp(0, visible.length - 1)].number);
                if (actualOld >= 0 && actualNew >= 0) await _reorder(actualOld, actualNew);
              },
              itemBuilder: (context, index) {
                final surah = visible[index];
                final selected = widget.playlist.surahNumbers.contains(surah.number);
                return ListTile(
                  key: ValueKey(surah.number),
                  title: Text(surah.name),
                  subtitle: Text('${surah.totalAyahs} ayat • ${surah.nameAr}'),
                  leading: Icon(selected ? Icons.check_circle : Icons.add_circle_outline),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        onPressed: selected ? () => _playFrom(index) : () => _addSurah(surah),
                        icon: Icon(selected ? Icons.play_arrow : Icons.add),
                      ),
                      if (selected)
                        IconButton(
                          onPressed: () => _removeSurah(surah),
                          icon: const Icon(Icons.delete_outline),
                        ),
                      const Icon(Icons.drag_handle),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  List<Surah> _surahCandidates(List<Surah> items, List<Surah> all) {
    final selected = {for (final surah in items) surah.number};
    final ordered = <Surah>[...items];
    for (final surah in all) {
      if (!selected.contains(surah.number)) ordered.add(surah);
    }
    return ordered;
  }
}