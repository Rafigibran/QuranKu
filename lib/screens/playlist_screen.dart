import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/surah.dart';
import '../services/api_service.dart';
import '../services/app_language_service.dart';
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
  final AppLanguageService _language = AppLanguageService();
  List<Surah> _surahs = [];
  List<_Playlist> _playlists = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _audioService.addListener(_refresh);
    _language.addListener(_refresh);
    _load();
  }

  @override
  void dispose() {
    _audioService.removeListener(_refresh);
    _language.removeListener(_refresh);
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
            name: _language.isEnglish ? 'Favorites' : 'Favorit',
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
    } catch (_) {
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
        title: Text(_language.isEnglish ? 'New Playlist' : 'Playlist Baru'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textInputAction: TextInputAction.done,
          onSubmitted: (value) => Navigator.pop(dialogContext, value.trim()),
          decoration: InputDecoration(
            labelText: _language.isEnglish ? 'Playlist name' : 'Nama playlist',
            hintText: _language.isEnglish ? 'My Quran Journey' : 'Kajian & Tilawah',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(_language.isEnglish ? 'Cancel' : 'Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
            child: Text(_language.isEnglish ? 'Create' : 'Buat'),
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
        title: Text(_language.isEnglish ? 'Rename Playlist' : 'Ganti Nama Playlist'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            labelText: _language.isEnglish ? 'Playlist name' : 'Nama playlist',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(_language.isEnglish ? 'Cancel' : 'Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
            child: Text(_language.isEnglish ? 'Save' : 'Simpan'),
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
        title: Text(_language.isEnglish ? 'Delete Playlist?' : 'Hapus Playlist?'),
        content: Text(
          _language.isEnglish
              ? 'This playlist and its saved Surahs will be removed.'
              : 'Playlist ini dan Surah yang tersimpan di dalamnya akan dihapus.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(_language.isEnglish ? 'Cancel' : 'Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(_language.isEnglish ? 'Delete' : 'Hapus'),
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
          language: _language,
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
            tooltip: _language.isEnglish ? 'New playlist' : 'Playlist baru',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createPlaylist,
        icon: const Icon(Icons.add),
        label: Text(_language.isEnglish ? 'New Playlist' : 'Playlist Baru'),
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
                      language: _language,
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
            Text(
              _language.isEnglish ? 'Create your first playlist' : 'Buat playlist pertamamu',
              textAlign: TextAlign.center,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 21,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _language.isEnglish
                  ? 'Organize Surahs into separate playlists, just like Spotify.'
                  : 'Pisahkan Surah ke dalam banyak playlist, seperti Spotify.',
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
              label: Text(_language.isEnglish ? 'Create Playlist' : 'Buat Playlist'),
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
    required this.language,
    required this.onTap,
    required this.onPlay,
    required this.onRename,
    required this.onDelete,
  });

  final _Playlist playlist;
  final int itemCount;
  final bool isPlaying;
  final ColorScheme colors;
  final AppLanguageService language;
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
                      '$itemCount ${language.isEnglish ? (itemCount == 1 ? 'Surah' : 'Surahs') : 'Surah'}',
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
                  color: onPlay == null ? colors.onSurface.withValues(alpha: 0.25) : colors.primary,
                  size: 34,
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'rename') onRename();
                  if (value == 'delete') onDelete();
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'rename',
                    child: Text(language.isEnglish ? 'Rename' : 'Ganti Nama'),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Text(language.isEnglish ? 'Delete' : 'Hapus'),
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
    required this.language,
    required this.onChanged,
  });

  final _Playlist playlist;
  final List<Surah> surahs;
  final AudioService audioService;
  final AppLanguageService language;
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

  Future<void> _removeAt(int index) async {
    setState(() => widget.playlist.surahNumbers.removeAt(index));
    if (widget.playlist.surahNumbers.isEmpty) {
      widget.audioService.clearCustomSurahSequence();
    }
    await _saveAndRefresh();
  }

  Future<void> _clear() async {
    if (widget.playlist.surahNumbers.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(widget.language.isEnglish ? 'Clear Playlist?' : 'Kosongkan Playlist?'),
        content: Text(
          widget.language.isEnglish
              ? 'All Surahs in this playlist will be removed.'
              : 'Semua Surah dalam playlist ini akan dihapus.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(widget.language.isEnglish ? 'Cancel' : 'Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(widget.language.isEnglish ? 'Clear' : 'Hapus'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => widget.playlist.surahNumbers.clear());
    widget.audioService.clearCustomSurahSequence();
    await _saveAndRefresh();
  }

  Future<void> _showAddDialog() async {
    _query = '';
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          final selected = widget.playlist.surahNumbers.toSet();
          final query = _query.trim().toLowerCase();
          final available = widget.surahs.where((surah) {
            if (selected.contains(surah.number)) return false;
            if (query.isEmpty) return true;
            return surah.name.toLowerCase().contains(query) ||
                surah.nameAr.contains(_query.trim()) ||
                surah.number.toString() == _query.trim();
          }).toList();
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
                        Expanded(
                          child: Text(
                            widget.language.isEnglish ? 'Add to Playlist' : 'Tambah ke Playlist',
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(sheetContext),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                    child: TextField(
                      onChanged: (value) => setSheetState(() => _query = value),
                      decoration: InputDecoration(
                        hintText: widget.language.isEnglish ? 'Search Surah...' : 'Cari Surah...',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: available.length,
                      itemBuilder: (_, index) {
                        final surah = available[index];
                        return ListTile(
                          title: Text(
                            surah.name,
                            style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text('${surah.number}. ${surah.nameAr}'),
                          trailing: IconButton(
                            icon: Icon(Icons.add_circle_outline, color: colors.primary),
                            onPressed: () async {
                              await _addSurah(surah);
                              setSheetState(() {});
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

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final items = _items;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        title: Text(
          widget.playlist.name,
          style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold),
        ),
        actions: [
          if (items.isNotEmpty)
            IconButton(
              onPressed: _clear,
              icon: const Icon(Icons.delete_sweep_outlined),
              tooltip: widget.language.isEnglish ? 'Clear playlist' : 'Kosongkan playlist',
            ),
          IconButton(
            onPressed: items.isEmpty ? null : () => _playFrom(0),
            icon: const Icon(Icons.play_arrow_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddDialog,
        icon: const Icon(Icons.add),
        label: Text(widget.language.isEnglish ? 'Add Surah' : 'Tambah Surah'),
      ),
      body: items.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.queue_music_outlined, size: 64, color: colors.primary),
                    const SizedBox(height: 16),
                    Text(
                      widget.language.isEnglish ? 'This playlist is empty' : 'Playlist ini masih kosong',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.language.isEnglish
                          ? 'Add your favorite Surahs and arrange them in any order.'
                          : 'Tambahkan Surah favorit dan atur urutannya sesuka kamu.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 12,
                        color: colors.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: _showAddDialog,
                      icon: const Icon(Icons.add),
                      label: Text(widget.language.isEnglish ? 'Add Surah' : 'Tambah Surah'),
                    ),
                  ],
                ),
              ),
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 10, 24, 12),
                  child: Row(
                    children: [
                      Icon(Icons.queue_music, color: colors.primary),
                      const SizedBox(width: 10),
                      Text(
                        '${items.length} ${widget.language.isEnglish ? (items.length == 1 ? 'Surah' : 'Surahs') : 'Surah'}',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 12,
                          color: colors.onSurface.withValues(alpha: 0.65),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        widget.language.isEnglish ? 'Hold and drag to reorder' : 'Tahan lalu geser untuk mengurutkan',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 10,
                          color: colors.onSurface.withValues(alpha: 0.45),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ReorderableListView.builder(
                    padding: const EdgeInsets.fromLTRB(24, 4, 24, 120),
                    itemCount: items.length,
                    onReorder: (oldIndex, newIndex) async {
                      if (newIndex > oldIndex) newIndex -= 1;
                      final value = widget.playlist.surahNumbers.removeAt(oldIndex);
                      widget.playlist.surahNumbers.insert(newIndex, value);
                      await _saveAndRefresh();
                    },
                    itemBuilder: (context, index) {
                      final surah = items[index];
                      final playing = widget.audioService.currentSurah?.number == surah.number;
                      return Container(
                        key: ValueKey('${widget.playlist.id}_${surah.number}'),
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: playing ? colors.primary : colors.outline,
                          ),
                          color: playing
                              ? colors.primary.withValues(alpha: 0.05)
                              : Colors.transparent,
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: colors.primary.withValues(alpha: 0.12),
                            foregroundColor: colors.primary,
                            child: Text(
                              '${index + 1}',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          title: Text(
                            surah.name,
                            style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            '${surah.nameAr} • ${surah.totalAyahs} Ayat',
                            style: GoogleFonts.spaceGrotesk(fontSize: 11),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                onPressed: () => _playFrom(index),
                                icon: Icon(
                                  playing && widget.audioService.isPlaying
                                      ? Icons.pause_circle
                                      : Icons.play_circle,
                                  color: colors.primary,
                                  size: 30,
                                ),
                              ),
                              IconButton(
                                onPressed: () => _removeAt(index),
                                icon: Icon(
                                  Icons.remove_circle_outline,
                                  color: colors.onSurface.withValues(alpha: 0.5),
                                ),
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
}
