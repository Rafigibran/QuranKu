import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:google_fonts/google_fonts.dart';
import '../models/surah.dart';
import '../services/api_service.dart';
import 'surah_detail_screen.dart';

/// Parses the alquran.cloud `/search` response body into result rows.
///
/// The API answers HTTP 404 with `{"data": "Nothing matching..."}` when
/// nothing matches — that is an empty result, not a failure. A malformed
/// payload throws so the caller can show an error state instead.
List<Map<String, dynamic>> parseAyahSearchResults(int statusCode, String body) {
  final decoded = jsonDecode(body);
  if (decoded is! Map<String, dynamic>) {
    throw const FormatException('Respons pencarian tidak valid');
  }
  final data = decoded['data'];
  if (statusCode == 404 || data is! Map<String, dynamic>) return const [];
  final matches = data['matches'];
  if (matches is! List) return const [];
  return matches.whereType<Map<String, dynamic>>().map((m) => <String, dynamic>{
    'numberInSurah': m['numberInSurah'],
    'text': m['text']?.toString() ?? '',
    'surah': (m['surah'] as Map<String, dynamic>?)?['number'],
    'surahName':
        (m['surah'] as Map<String, dynamic>?)?['englishName']?.toString() ?? '',
  }).toList();
}

class AyahSearchScreen extends StatefulWidget {
  const AyahSearchScreen({super.key});
  @override
  State<AyahSearchScreen> createState() => _AyahSearchScreenState();
}

class _AyahSearchScreenState extends State<AyahSearchScreen> {
  final _query = TextEditingController();
  bool _loading = false;
  bool _searched = false;
  String _lastQuery = '';
  String? _error;
  List<Map<String, dynamic>> _results = [];

  @override
  void dispose() { _query.dispose(); super.dispose(); }

  Future<void> _search() async {
    final q = _query.text.trim();
    if (q.length < 2) return;
    setState(() {
      _loading = true;
      _error = null;
      _results = [];
      _searched = true;
      _lastQuery = q;
    });
    try {
      final uri = Uri.parse('https://api.alquran.cloud/v1/search/${Uri.encodeComponent(q)}/all/id');
      final response = await http.get(uri).timeout(const Duration(seconds: 15));
      final results = parseAyahSearchResults(response.statusCode, response.body);
      if (!mounted) return;
      setState(() => _results = results);
    } catch (e) {
      if (mounted) setState(() => _error = 'Pencarian gagal: $e');
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
      final surah = surahs.firstWhere(
        (s) => s.number == number,
        orElse: () => throw Exception('Surah tidak ditemukan'),
      );
      if (!mounted) return;
      await Navigator.push(context, MaterialPageRoute(
        builder: (_) => SurahDetailScreen(surah: surah, initialAyah: ayah),
      ));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
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
          else if (!_searched) const Text('Masukkan kata atau frasa untuk mencari seluruh Al-Qur’an.')
          else if (_results.isEmpty) Text('Tidak ada ayat yang cocok dengan "$_lastQuery".')
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
