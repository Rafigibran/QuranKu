import 'package:flutter/material.dart';
import '../l10n/l10n.dart';
import '../services/settings_service.dart';
import '../services/api_service.dart';
import '../models/surah.dart';

class StorageManagementScreen extends StatefulWidget {
  const StorageManagementScreen({super.key});

  @override
  State<StorageManagementScreen> createState() =>
      _StorageManagementScreenState();
}

class _StorageManagementScreenState extends State<StorageManagementScreen>
    with SingleTickerProviderStateMixin {
  final SettingsService _settings = SettingsService();
  final ApiService _api = ApiService();
  late TabController _tabController;

  bool _isLoading = true;
  List<Map<String, dynamic>> _audioDetails = [];
  List<Map<String, dynamic>> _surahDetails = [];
  List<Map<String, dynamic>> _translationDetails = [];
  Map<int, Surah> _surahMap = {};

  // Storage summary
  int _totalAudioSize = 0;
  int _totalDataSize = 0;

  bool _showSurahData =
      true; // Toggle between Surah vs Translation view in Data tab

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    // Fetch Surah metadata only if not already loaded
    if (_surahMap.isEmpty) {
      try {
        final surahs = await _api.fetchSurahs();
        _surahMap = {for (var s in surahs) s.number: s};
      } catch (e) {
        debugPrint('Error loading surah map: $e');
      }
    }

    final audio = await _settings.getAudioStorageDetails();
    final surah = await _settings.getSurahStorageDetails();
    final trans = await _settings.getTranslationStorageDetails();

    int audioSize = 0;
    for (var i in audio) {
      audioSize += (i['totalSize'] as int);
    }

    int dataSize = 0;
    for (var i in surah) {
      dataSize += (i['totalSize'] as int);
    }

    if (mounted) {
      setState(() {
        _audioDetails = audio;
        _surahDetails = surah;
        _translationDetails = trans;
        _totalAudioSize = audioSize;
        _totalDataSize = dataSize;
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteAudio(int surahNum) async {
    await _settings.deleteAudioForSurah(surahNum);
    _loadData();
  }

  Future<void> _deleteSurahData(int surahNum) async {
    await _settings.deleteSurahCache(surahNum);
    _loadData();
  }

  Future<void> _deleteTranslationData(String edition) async {
    await _settings.deleteTranslationCache(edition);
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          context.l10n.storageTitle,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: colorScheme.onSurface,
          ),
        ),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        iconTheme: IconThemeData(color: colorScheme.onSurface),
        bottom: TabBar(
          controller: _tabController,
          labelColor: colorScheme.primary,
          unselectedLabelColor: colorScheme.onSurface.withValues(alpha: 0.72),
          indicatorColor: colorScheme.primary,
          labelStyle: TextStyle(fontWeight: FontWeight.bold),
          tabs: const [
            Tab(text: 'Audio'),
            Tab(text: 'Data'),
          ],
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: colorScheme.primary))
          : TabBarView(
              controller: _tabController,
              children: [_buildAudioTab(), _buildDataTab()],
            ),
    );
  }

  Widget _buildAudioTab() {
    if (_audioDetails.isEmpty) {
      return _buildEmptyState(context.l10n.storageNoAudio);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSummaryCard(
          context.l10n.storageTotalAudio,
          _settings.formatBytes(_totalAudioSize),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
            itemCount: _audioDetails.length,
            itemBuilder: (context, index) {
              final item = _audioDetails[index];
              final surahNum = item['surahNumber'];
              final surah = _surahMap[surahNum];

              final surahName = surah != null ? surah.name : context.l10n.storageSurahLabel(surahNum);
              final totalAyahs = surah?.totalAyahs ?? 0;
              final downloadCount = item['fileCount'];

              return _buildStorageItem(
                title: surahName,
                subtitle: context.l10n.storageAyahsDownloaded(downloadCount, totalAyahs),
                size: _settings.formatBytes(item['totalSize']),
                onDelete: () => _confirmDelete(
                  title: context.l10n.storageDeleteAudioTitle,
                  content: context.l10n.storageDeleteAudioBody(surahName),
                  onConfirm: () => _deleteAudio(surahNum),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDataTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSummaryCard(
          context.l10n.storageTotalData,
          _settings.formatBytes(_totalDataSize),
        ),

        // Toggle
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Row(
            children: [
              _buildFilterChip(
                context.l10n.storageBySurah,
                _showSurahData,
                () => setState(() => _showSurahData = true),
              ),
              const SizedBox(width: 8),
              _buildFilterChip(
                context.l10n.storageByTranslation,
                !_showSurahData,
                () => setState(() => _showSurahData = false),
              ),
            ],
          ),
        ),

        Expanded(
          child: _showSurahData ? _buildSurahList() : _buildTranslationList(),
        ),
      ],
    );
  }

  Widget _buildSurahList() {
    if (_surahDetails.isEmpty) return _buildEmptyState(context.l10n.storageNoCachedSurahs);

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
      itemCount: _surahDetails.length,
      itemBuilder: (context, index) {
        final item = _surahDetails[index];
        final surahNum = item['surahNumber'];
        final surah = _surahMap[surahNum];

        final surahName = surah != null ? surah.name : context.l10n.storageSurahLabel(surahNum);
        final totalAyahs = surah?.totalAyahs ?? 0;

        // Since we cache full surahs, it's safe to say "X / X Ayahs"
        // or just "X Ayahs Downloaded"
        final subtitle = context.l10n.storageAyahsDownloaded(totalAyahs, totalAyahs);

        return _buildStorageItem(
          title: surahName,
          subtitle: subtitle,
          size: _settings.formatBytes(item['totalSize']),
          onDelete: () => _confirmDelete(
            title: context.l10n.storageDeleteCacheTitle,
            content:
                context.l10n.storageDeleteCacheBody(surahName),
            onConfirm: () => _deleteSurahData(surahNum),
          ),
        );
      },
    );
  }

  Widget _buildTranslationList() {
    if (_translationDetails.isEmpty)
      return _buildEmptyState(context.l10n.storageNoCachedTranslations);

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
      itemCount: _translationDetails.length,
      itemBuilder: (context, index) {
        final item = _translationDetails[index];
        return _buildStorageItem(
          title: item['name'],
          subtitle: context.l10n.storageSurahsCached(item['surahCount'] as int),
          size: _settings.formatBytes(item['totalSize']),
          onDelete: () => _confirmDelete(
            title: context.l10n.storageDeleteTranslationTitle,
            content: context.l10n.storageDeleteTranslationBody('${item['name']}'),
            onConfirm: () => _deleteTranslationData(item['edition']),
          ),
        );
      },
    );
  }

  Widget _buildFilterChip(String label, bool isSelected, VoidCallback onTap) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primary
              : colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? colorScheme.onPrimary : colorScheme.onSurface,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.pie_chart_outline,
                size: 16,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.bold,
              letterSpacing: -1.0,
              color: colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 64,
            color: colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              color: colorScheme.onSurface.withValues(alpha: 0.72),
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStorageItem({
    required String title,
    required String subtitle,
    required String size,
    required VoidCallback onDelete,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      color: Colors.transparent, // No background
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            fontSize: 12,
            color: colorScheme.onSurface.withValues(alpha: 0.72),
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              size,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: onDelete,
              icon: Icon(Icons.delete_outline, color: Colors.red[400]),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete({
    required String title,
    required String content,
    required VoidCallback onConfirm,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colorScheme.outline),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
          ),
        ),
        content: Text(content, style: TextStyle(color: colorScheme.onSurface)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: colorScheme.onSurface.withValues(alpha: 0.72),
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              onConfirm();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.error,
            ),
            child: Text(
              'Delete',
              style: TextStyle(color: colorScheme.onError),
            ),
          ),
        ],
      ),
    );
  }
}
