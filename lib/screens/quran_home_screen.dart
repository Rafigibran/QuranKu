import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/surah.dart';
import '../services/api_service.dart';
import 'surah_detail_screen.dart';

class QuranHomeScreen extends StatefulWidget {
  const QuranHomeScreen({super.key});

  @override
  State<QuranHomeScreen> createState() => _QuranHomeScreenState();
}

class _QuranHomeScreenState extends State<QuranHomeScreen> {
  late Future<List<Surah>> _future;
  List<Surah> _all = [];
  List<Surah> _filtered = [];
  final TextEditingController _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Surah>> _load() async {
    final surahs = await ApiService().fetchSurahs();
    if (mounted) {
      setState(() {
        _all = surahs;
        _filtered = surahs;
      });
    }
    return surahs;
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _filter(String value) {
    final q = value.trim().toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? _all
          : _all.where((s) {
              return s.name.toLowerCase().contains(q) ||
                  s.number.toString().contains(q);
            }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        title: RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: 'QURAN',
                style: GoogleFonts.spaceGrotesk(
                  fontWeight: FontWeight.bold,
                  fontSize: 24,
                  color: colors.onSurface,
                ),
              ),
              TextSpan(
                text: '.',
                style: GoogleFonts.spaceGrotesk(
                  fontWeight: FontWeight.bold,
                  fontSize: 24,
                  color: colors.primary,
                ),
              ),
            ],
          ),
        ),
        backgroundColor: const Color(0xFF0A0A0A),
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
            child: TextField(
              controller: _search,
              onChanged: _filter,
              style: GoogleFonts.spaceGrotesk(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search Surah...',
                hintStyle: GoogleFonts.spaceGrotesk(color: Colors.white54),
                suffixIcon: const Icon(Icons.search, color: Color(0xFF40B779)),
                enabledBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF2A2A2A), width: 2),
                ),
                focusedBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF40B779), width: 2),
                ),
              ),
            ),
          ),
        ),
      ),
      body: FutureBuilder<List<Surah>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && _all.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF40B779)),
            );
          }
          if (snapshot.hasError && _all.isEmpty) {
            return Center(
              child: Text(
                'Failed to load Quran data',
                style: GoogleFonts.spaceGrotesk(color: Colors.white),
              ),
            );
          }
          return RefreshIndicator(
            color: const Color(0xFF40B779),
            onRefresh: () async {
              setState(() {
                _future = ApiService().fetchSurahs(forceRefresh: true).then((surahs) {
                  _all = surahs;
                  _filtered = surahs;
                  return surahs;
                });
              });
              await _future;
            },
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
              itemCount: _filtered.length,
              itemBuilder: (context, index) {
                final surah = _filtered[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SurahDetailScreen(surah: surah),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFF2A2A2A)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${surah.number}  ${surah.totalAyahs} Ayahs',
                                style: GoogleFonts.spaceGrotesk(
                                  color: Colors.white54,
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                surah.type,
                                style: GoogleFonts.spaceGrotesk(
                                  color: Colors.white54,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Expanded(
                                child: Text(
                                  surah.name,
                                  style: GoogleFonts.spaceGrotesk(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                surah.nameAr,
                                style: GoogleFonts.amiri(
                                  color: Colors.white54,
                                  fontSize: 20,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
