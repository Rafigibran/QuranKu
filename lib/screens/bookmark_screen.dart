import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/surah.dart';
import '../services/api_service.dart';
import '../services/bookmark_service.dart';
import 'surah_detail_screen.dart';

class BookmarkScreen extends StatefulWidget {
  const BookmarkScreen({super.key});
  @override
  State<BookmarkScreen> createState() => _BookmarkScreenState();
}

class _BookmarkScreenState extends State<BookmarkScreen> {
  final BookmarkService _service = BookmarkService();
  final Map<int, Surah> _surahs = {};

  @override
  void initState() {
    super.initState();
    _service.addListener(_refresh);
    _service.init();
    ApiService().fetchSurahs().then((items) {
      if (!mounted) return;
      for (final s in items) _surahs[s.number] = s;
      setState(() {});
    });
  }

  @override
  void dispose() {
    _service.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() { if (mounted) setState(() {}); }

  Future<void> _createFolder() async {
    final c = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Folder bookmark'),
        content: TextField(controller: c, autofocus: true, decoration: const InputDecoration(hintText: 'Nama folder')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(context, c.text), child: const Text('Buat')),
        ],
      ),
    );
    if (name != null) await _service.addFolder(name);
    c.dispose();
  }

  Future<void> _editFolder(BookmarkFolder folder) async {
    final c = TextEditingController(text: folder.name);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ubah nama folder'),
        content: TextField(controller: c, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(context, c.text), child: const Text('Simpan')),
        ],
      ),
    );
    if (name != null) await _service.renameFolder(folder.id, name);
    c.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bookmark & riwayat'),
        actions: [IconButton(onPressed: _createFolder, icon: const Icon(Icons.create_new_folder_outlined))],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          Text('Folder bookmark', style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w800, fontSize: 18)),
          const SizedBox(height: 10),
          ..._service.folders.map((folder) => Card(
            child: ListTile(
              leading: const Icon(Icons.bookmarks_outlined),
              title: Text(folder.name),
              subtitle: Text('${_service.itemsForFolder(folder.id).length} ayat'),
              onTap: () => _showFolder(folder),
              trailing: folder.id == _service.defaultFolderId ? null : PopupMenuButton<String>(
                onSelected: (value) async {
                  if (value == 'rename') await _editFolder(folder);
                  if (value == 'delete') await _service.deleteFolder(folder.id);
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'rename', child: Text('Ubah nama')),
                  PopupMenuItem(value: 'delete', child: Text('Hapus folder')),
                ],
              ),
            ),
          )),
          const SizedBox(height: 24),
          Row(children: [
            Expanded(child: Text('Riwayat baca', style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w800, fontSize: 18))),
            TextButton(onPressed: _service.history.isEmpty ? null : _service.clearHistory, child: const Text('Hapus')),
          ]),
          const SizedBox(height: 8),
          if (_service.history.isEmpty)
            const Card(child: Padding(padding: EdgeInsets.all(18), child: Text('Belum ada riwayat baca.')))
          else
            ..._service.history.take(20).map((entry) => ListTile(
              leading: CircleAvatar(child: Text('${entry.surahNumber}')),
              title: Text('Surah ${_surahs[entry.surahNumber]?.name ?? entry.surahNumber}'),
              subtitle: Text('Ayat ${entry.ayahNumber} • ${entry.timestamp.toLocal()}'),
              onTap: () async {
                final surah = _surahs[entry.surahNumber];
                if (surah == null) return;
                await Navigator.push(context, MaterialPageRoute(
                  builder: (_) => SurahDetailScreen(surah: surah, initialAyah: entry.ayahNumber),
                ));
              },
            )),
        ],
      ),
    );
  }

  Future<void> _showFolder(BookmarkFolder folder) async {
    final items = _service.itemsForFolder(folder.id);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.of(context).size.height * .72,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 30),
            children: [
              Text(folder.name, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              if (items.isEmpty) const Text('Folder ini masih kosong.'),
              ...items.map((item) => ListTile(
                leading: const Icon(Icons.bookmark_rounded),
                title: Text('Surah ${_surahs[item.surahNumber]?.name ?? item.surahNumber}'),
                subtitle: Text('Ayat ${item.ayahNumber}'),
                onTap: () async {
                  final surah = _surahs[item.surahNumber];
                  if (surah == null) return;
                  Navigator.pop(context);
                  await Navigator.push(context, MaterialPageRoute(
                    builder: (_) => SurahDetailScreen(surah: surah, initialAyah: item.ayahNumber),
                  ));
                },
                trailing: IconButton(onPressed: () => _service.remove(item.id), icon: const Icon(Icons.delete_outline)),
              )),
            ],
          ),
        ),
      ),
    );
  }
}
