import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:google_fonts/google_fonts.dart';
import '../models/surah.dart';
import '../services/api_service.dart';
import 'surah_detail_screen.dart';

class AyahSearchScreen extends StatefulWidget {
  const AyahSearchScreen({super.key});
  @override
  State<AyahSearchScreen> createState() => _AyahSearchScreenState();
}

class _AyahSearchScreenState extends State<AyahSearchScreen> {
  final _query = TextEditingController();
  bool _loading = false;
  String? _error;
  List<Map<String, dynamic>> _results = [];

  @override
  void dispose() { _query.dispose(); super.dispose(); }

  Future<void> _search() async {
    final q = _query.text.trim();
    if (q.length < 2) return;
    setState(() { _loading = true; _error = null; });
    try {
      final uri = Uri.parse('https://api.alquran.cloud/v1/search/${Uri.encodeComponent(q)}/all/id');
      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) throw Exception('HTTP ${response.statusCode}');
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final data = body['data'] as Map<String, dynamic>;
      final matches = (data['matches'] as List<dynamic>? ?? const []);
      setState(() {
        _results = matches.whereType<Map<String, dynamic>>().map((m) => {
          'numberInSurah': m['numberInSurah'],
          'text': m['text']?.toString() ?? '',
          'surah': (m['surah'] as Map<String, dynamic>?)?['number'],
          'surahName': (m['surah'] as Map<String, dynamic>?)?['englishName']?.toString() ?? '',
        }).toList();
      });
    } catch (e) {
      setState(() => _error = 'Pencarian gagal: ${e}');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openResult(Map<String, dynamic> result) async {
    final number = (result['surah'] as num?)?.toInt();
    final ayah = (result['numberInSurah'] as num?)?.toInt();
    if (number == null || ayah == null) return;
    try {
      final surahs = await ApiService().fetchSurahs();
      final surah = surahs.firstWhere((s) => s.number == number);
      if (!mounted) return;
      await Navigator.push(context, MaterialPageRoute(
        builder: (_) => SurahDetailScreen(surah: surah, initialAyah: ayah),
      ));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${e}')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Cari ayat')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 40),
        children: [
          Row(children: [
            Expanded(child: TextField(
              controller: _query,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _search(),
              decoration: const InputDecoration(hintText: 'Cari kata pada terjemahan...', prefixIcon: Icon(Icons.search_rounded)),
            )),
            const SizedBox(width: 10),
            FilledButton(onPressed: _loading ? null : _search, child: const Icon(Icons.search_rounded)),
          ]),
          const SizedBox(height: 18),
          if (_loading) const Center(child: Padding(padding: EdgeInsets.all(30), child: CircularProgressIndicator()))
          else if (_error != null) Text(_error!, style: TextStyle(color: scheme.error))
          else if (_results.isEmpty) const Text('Masukkan kata atau frasa untuk mencari seluruh Al-Qur’an.')
          else ..._results.map((item) => Card(
            child: ListTile(
              title: Text('${item['surahName']} • Ayat ${item['numberInSurah']}', style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w700)),
              subtitle: Text(item['text'], maxLines: 5, overflow: TextOverflow.ellipsis),
              onTap: () => _openResult(item),
            ),
          )),
        ],
      ),
    );
  }
}
