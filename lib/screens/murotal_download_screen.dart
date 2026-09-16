import 'package:flutter/material.dart';
import '../l10n/l10n.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/surah.dart';
import '../services/api_service.dart';
import '../services/murotal_download_service.dart';
import '../services/settings_service.dart';

class MurotalDownloadScreen extends StatefulWidget {
  final ScrollController? scrollController;
  const MurotalDownloadScreen({super.key, this.scrollController});

  @override
  State<MurotalDownloadScreen> createState() => _MurotalDownloadScreenState();
}

class _MurotalDownloadScreenState extends State<MurotalDownloadScreen> {
  final _service = MurotalDownloadService();
  final _settings = SettingsService();
  int? selectedSurahToAdd;
  List<Surah> availableSurahs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _service.addListener(_onServiceUpdate);
    _settings.addListener(_onServiceUpdate);

    // Check Notification Permission
    Permission.notification.request();

    _loadSurahs();
  }

  Future<void> _loadSurahs() async {
    try {
      final surahs = await ApiService().fetchSurahs();
      if (mounted) {
        setState(() {
          availableSurahs = surahs;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading surahs: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _service.removeListener(_onServiceUpdate);
    _settings.removeListener(_onServiceUpdate);
    super.dispose();
  }

  void _onServiceUpdate() {
    if (mounted) setState(() {});
  }

  String _getSurahName(int number) {
    final surah = availableSurahs.firstWhere(
      (s) => s.number == number,
      orElse: () => Surah(
        number: number,
        name: 'Surah $number',
        nameAr: '',
        type: '',
        totalAyahs: 0,
      ),
    );
    return surah.name;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: colorScheme.outline,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: context.l10n.murotalDownloadsTitle,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                          color: colorScheme.onSurface,
                          letterSpacing: -1,
                        ),
                      ),
                      TextSpan(
                        text: '.',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                          color: colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_service.status != MurotalDownloadStatus.idle)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.2),
                      border: Border.all(color: colorScheme.primary),
                    ),
                    child: Text(
                      _service.status == MurotalDownloadStatus.paused
                          ? 'PAUSED'
                          : 'DOWNLOADING',
                      style: TextStyle(
                        color: colorScheme.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Body
          Expanded(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(
                      color: colorScheme.primary,
                    ),
                  )
                : SingleChildScrollView(
                    controller: widget.scrollController,
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.l10n.murotalDownloadsSubtitle,
                          style: TextStyle(
                            color: colorScheme.onSurface.withValues(alpha: 0.72),
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Add Surah Dropdown
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            border: Border.all(color: colorScheme.outline),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<int>(
                              value: selectedSurahToAdd,
                              hint: Text(
                                context.l10n.murotalDownloadsSelect,
                                style: TextStyle(
                                  color: colorScheme.onSurface.withValues(
                                    alpha: 0.5,
                                  ),
                                ),
                              ),
                              dropdownColor: Theme.of(context).cardColor,
                              isExpanded: true,
                              menuMaxHeight: 300,
                              items: availableSurahs
                                  .where(
                                    (s) =>
                                        !_service.queue.contains(s.number) &&
                                        !_service.downloadedSurahs.contains(
                                          s.number,
                                        ),
                                  )
                                  .map((Surah surah) {
                                    return DropdownMenuItem<int>(
                                      value: surah.number,
                                      child: Text(
                                        '${_settings.formatNumber(surah.number)}. ${surah.name}',
                                        style: TextStyle(
                                          color: colorScheme.onSurface,
                                        ),
                                      ),
                                    );
                                  })
                                  .toList(),
                              onChanged: (newValue) {
                                if (newValue != null) {
                                  setState(() {
                                    _service.addToQueue(newValue);
                                    selectedSurahToAdd = null;
                                  });
                                }
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Controls & Progress
                        if (_service.status != MurotalDownloadStatus.idle ||
                            _service.queue.isNotEmpty) ...[
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed:
                                      _service.status ==
                                          MurotalDownloadStatus.downloading
                                      ? _service.pauseDownload
                                      : _service.startDownload,
                                  icon: Icon(
                                    _service.status ==
                                            MurotalDownloadStatus.downloading
                                        ? Icons.pause
                                        : Icons.play_arrow,
                                    color: colorScheme.onPrimary,
                                  ),
                                  label: Text(
                                    _service.status ==
                                            MurotalDownloadStatus.downloading
                                        ? 'Pause'
                                        : 'Download',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: colorScheme.onPrimary,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: colorScheme.primary,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.zero,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              if (_service.status != MurotalDownloadStatus.idle)
                                IconButton(
                                  onPressed: _service.stopDownload,
                                  icon: Icon(
                                    Icons.stop,
                                    color: colorScheme.error,
                                  ),
                                  style: IconButton.styleFrom(
                                    shape: const RoundedRectangleBorder(
                                      borderRadius: BorderRadius.zero,
                                    ),
                                    side: BorderSide(
                                      color: colorScheme.outline,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          if (_service.status !=
                              MurotalDownloadStatus.idle) ...[
                            const SizedBox(height: 12),
                            LinearProgressIndicator(
                              value: _service.progress,
                              backgroundColor:
                                  colorScheme.surfaceContainerHighest,
                              color: colorScheme.primary,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Downloading ${_getSurahName(_service.currentSurah)}: Ayah ${_settings.formatNumber(_service.currentAyah)} of ${_settings.formatNumber(_service.totalAyahs)}',
                              style: TextStyle(
                                color: colorScheme.onSurface.withValues(
                                  alpha: 0.5,
                                ),
                                fontSize: 12,
                              ),
                            ),
                          ],
                          const SizedBox(height: 24),
                        ],

                        // Queue List
                        if (_service.queue.isNotEmpty) ...[
                          Text(
                            'Queue:',
                            style: TextStyle(
                              color: colorScheme.onSurface,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _service.queue.length,
                            itemBuilder: (context, index) {
                              final surahNum = _service.queue[index];
                              final isCurrentlyDownloading =
                                  _service.currentSurah == surahNum &&
                                  _service.status ==
                                      MurotalDownloadStatus.downloading;
                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: isCurrentlyDownloading
                                        ? colorScheme.primary
                                        : colorScheme.outline,
                                  ),
                                  color: isCurrentlyDownloading
                                      ? colorScheme.primary.withValues(
                                          alpha: 0.05,
                                        )
                                      : Colors.transparent,
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 28,
                                            height: 28,
                                            alignment: Alignment.center,
                                            decoration: BoxDecoration(
                                              color: Theme.of(
                                                context,
                                              ).scaffoldBackgroundColor,
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: colorScheme.outline,
                                              ),
                                            ),
                                            child: Text(
                                              _settings.formatNumber(surahNum),
                                              style: TextStyle(
                                                color: colorScheme.primary,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              _getSurahName(surahNum),
                                              style: TextStyle(
                                                color: colorScheme.onSurface,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (isCurrentlyDownloading)
                                      SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          value: _service.progress,
                                          color: colorScheme.primary,
                                        ),
                                      )
                                    else
                                      IconButton(
                                        icon: Icon(
                                          Icons.close,
                                          size: 18,
                                          color: colorScheme.onSurface
                                              .withValues(alpha: 0.72),
                                        ),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        onPressed: () =>
                                            _service.removeFromQueue(surahNum),
                                      ),
                                  ],
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 24),
                        ],

                        // Downloaded List
                        if (_service.downloadedSurahs.isNotEmpty) ...[
                          Container(height: 1, color: colorScheme.outline),
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              Icon(
                                Icons.check_circle,
                                color: colorScheme.primary,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Downloaded (${_settings.formatNumber(_service.downloadedSurahs.length)})',
                                style: TextStyle(
                                  color: colorScheme.onSurface,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 200),
                            child: Scrollbar(
                              child: ListView.builder(
                                shrinkWrap: true,
                                itemCount: _service.downloadedSurahs.length,
                                itemBuilder: (context, index) {
                                  final surahNum =
                                      _service.downloadedSurahs[index];
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).cardColor,
                                      border: Border.all(
                                        color: colorScheme.outline,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              width: 28,
                                              height: 28,
                                              alignment: Alignment.center,
                                              decoration: BoxDecoration(
                                                color: colorScheme.primary
                                                    .withValues(alpha: 0.2),
                                                shape: BoxShape.circle,
                                              ),
                                              child: Text(
                                                _settings.formatNumber(
                                                  surahNum,
                                                ),
                                                style: TextStyle(
                                                  color: colorScheme.primary,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Text(
                                              _getSurahName(surahNum),
                                              style: TextStyle(
                                                color: colorScheme.onSurface
                                                    .withValues(alpha: 0.72),
                                                fontSize: 14,
                                              ),
                                            ),
                                          ],
                                        ),
                                        Icon(
                                          Icons.check_circle_outline,
                                          color: colorScheme.primary,
                                          size: 18,
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
