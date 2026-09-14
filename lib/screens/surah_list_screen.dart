import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/surah.dart';
import '../services/api_service.dart';
import '../services/settings_service.dart';
import 'surah_detail_screen.dart';
import 'download_screen.dart';

class SurahListScreen extends StatefulWidget {
  const SurahListScreen({super.key});

  @override
  State<SurahListScreen> createState() => _SurahListScreenState();
}

class _SurahListScreenState extends State<SurahListScreen> with TickerProviderStateMixin {
  late Future<List<Surah>> _surahListFuture;
  List<Surah> _allSurahs = [];
  List<Surah> _filteredSurahs = [];
  final TextEditingController _searchController = TextEditingController();
  final SettingsService _settings = SettingsService();

  @override
  void initState() {
    super.initState();
    // Do not initialize notifications/download services while Quran is starting.
    // The Download Manager initializes them only when it is explicitly opened.
    _settings.addListener(_onSettingsUpdate);

    _surahListFuture = ApiService().fetchSurahs().then((surahs) {
      if (mounted) {
        setState(() {
          _allSurahs = surahs;
          _filteredSurahs = surahs;
        });
      }
      return surahs;
    });
  }

  @override
  void dispose() {
    _settings.removeListener(_onSettingsUpdate);
    _searchController.dispose();
    super.dispose();
  }

  void _onSettingsUpdate() {
    if (mounted) setState(() {});
  }

  void _filterSurahs(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredSurahs = _allSurahs;
      } else {
        _filteredSurahs = _allSurahs.where((surah) {
          return surah.name.toLowerCase().contains(query.toLowerCase()) ||
              surah.number.toString().contains(query);
        }).toList();
      }
    });
  }

  Future<void> _openDownloadManager() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        builder: (context, scrollController) => DownloadScreen(
          scrollController: scrollController,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: 'QURAN',
                style: GoogleFonts.spaceGrotesk(
                  fontWeight: FontWeight.bold,
                  fontSize: 24,
                  color: colorScheme.onSurface,
                  letterSpacing: -1,
                ),
              ),
              TextSpan(
                text: '.',
                style: GoogleFonts.spaceGrotesk(
                  fontWeight: FontWeight.bold,
                  fontSize: 24,
                  color: colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
        centerTitle: false,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        scrolledUnderElevation: 0,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            onPressed: _openDownloadManager,
            icon: Icon(Icons.download_outlined, color: colorScheme.primary),
            tooltip: 'Download Manager',
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60.0),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
            child: TextField(
              controller: _searchController,
              onChanged: _filterSurahs,
              style: GoogleFonts.spaceGrotesk(color: colorScheme.onSurface, height: 1.5),
              decoration: InputDecoration(
                hintText: 'Search Surah...',
                hintStyle: GoogleFonts.spaceGrotesk(color: colorScheme.onSurface.withValues(alpha: 0.5)),
                isDense: true,
                filled: true,
                fillColor: Colors.transparent,
                contentPadding: const EdgeInsets.only(bottom: 4, top: 12),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: colorScheme.outline, width: 2),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: colorScheme.primary, width: 2),
                ),
                suffixIcon: Icon(Icons.search, color: colorScheme.primary, size: 20),
              ),
            ),
          ),
        ),
      ),
      body: FutureBuilder<List<Surah>>(
        future: _surahListFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && _allSurahs.isEmpty) {
            return Center(child: CircularProgressIndicator(color: colorScheme.primary));
          } else if (snapshot.hasError) {
            return Center(child: Text('Failed to load data', style: TextStyle(color: Colors.red)));
          } else if (_filteredSurahs.isEmpty && _allSurahs.isNotEmpty) {
            return Center(
              child: Text(
                "No Surahs found matching '${_searchController.text}'",
                style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.7)),
              ),
            );
          } else if (_allSurahs.isEmpty) {
            if (snapshot.connectionState == ConnectionState.done) {
              return const Center(child: Text('No Surahs found'));
            }
            return const SizedBox.shrink();
          }

          return LayoutBuilder(
            builder: (context, constraints) {
              int crossAxisCount = 1;
              if (constraints.maxWidth > 1024) {
                crossAxisCount = 3;
              } else if (constraints.maxWidth > 768) {
                crossAxisCount = 2;
              }

              return RefreshIndicator(
                color: colorScheme.primary,
                backgroundColor: Theme.of(context).cardColor,
                onRefresh: () async {
                  try {
                    final surahs = await ApiService().fetchSurahs(forceRefresh: true);
                    setState(() {
                      _allSurahs = surahs;
                      _filteredSurahs = surahs;
                      _searchController.clear();
                    });
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to refresh: $e')),
                    );
                  }
                },
                child: _filteredSurahs.isEmpty
                    ? SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: SizedBox(
                          height: constraints.maxHeight,
                          child: Center(
                            child: Text(
                              'No Surahs found. Pull to refresh.',
                              style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.7)),
                            ),
                          ),
                        ),
                      )
                    : crossAxisCount == 1
                        ? ListView.builder(
                            padding: const EdgeInsets.fromLTRB(24, 24, 24, 100),
                            itemCount: _filteredSurahs.length,
                            itemBuilder: (context, index) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: _buildSurahCard(_filteredSurahs[index]),
                              );
                            },
                          )
                        : GridView.builder(
                            padding: const EdgeInsets.fromLTRB(24, 24, 24, 100),
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: crossAxisCount,
                              crossAxisSpacing: 24,
                              mainAxisSpacing: 24,
                              childAspectRatio: 2.2,
                            ),
                            itemCount: _filteredSurahs.length,
                            itemBuilder: (context, index) {
                              return _buildSurahCard(_filteredSurahs[index]);
                            },
                          ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildSurahCard(Surah surah) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: Colors.transparent,
        border: Border.all(color: colorScheme.outline),
        borderRadius: BorderRadius.circular(0),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          hoverColor: Colors.transparent,
          highlightColor: colorScheme.primary.withValues(alpha: 0.05),
          splashColor: colorScheme.primary.withValues(alpha: 0.1),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => SurahDetailScreen(surah: surah),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Text(
                          _settings.formatNumber(surah.number),
                          style: GoogleFonts.spaceGrotesk(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '${_settings.formatNumber(surah.totalAyahs)} Ayahs',
                          style: GoogleFonts.spaceGrotesk(
                            color: colorScheme.onSurface.withValues(alpha: 0.5),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(color: colorScheme.outline),
                      ),
                      child: Text(
                        surah.type,
                        style: GoogleFonts.spaceGrotesk(
                          color: colorScheme.onSurface.withValues(alpha: 0.5),
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Text(
                        surah.name,
                        style: GoogleFonts.spaceGrotesk(
                          color: colorScheme.onSurface,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          height: 1.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      surah.nameAr,
                      style: GoogleFonts.amiri(
                        color: colorScheme.onSurface.withValues(alpha: 0.5),
                        fontSize: 20,
                        height: 1.0,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
