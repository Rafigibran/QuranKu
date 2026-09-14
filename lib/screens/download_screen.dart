import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/download_service.dart';
import '../services/settings_service.dart';

class DownloadScreen extends StatefulWidget {
  final ScrollController? scrollController;
  const DownloadScreen({super.key, this.scrollController});

  @override
  State<DownloadScreen> createState() => _DownloadScreenState();
}

class _DownloadScreenState extends State<DownloadScreen> {
  final _service = DownloadService();
  final _settings = SettingsService();
  String? selectedEditionToAdd;
  List<String> availableEditions = [];

  @override
  void initState() {
    super.initState();
    _service.addListener(_onServiceUpdate);
    _settings.addListener(_onServiceUpdate);

    // Initialize notification/download services only after the user opens
    // the Download Manager. Never do this during Quran startup.
    _initializeDownloadManager();
  }

  Future<void> _initializeDownloadManager() async {
    try {
      await _service.init();
      if (!mounted) return;
      await Permission.notification.request();
      await _loadEditions();
    } catch (e) {
      debugPrint('Download Manager initialization failed: $e');
      if (mounted) {
        await _loadEditions();
      }
    }
  }

  Future<void> _loadEditions() async {
    try {
      final String jsonString = await DefaultAssetBundle.of(
        context,
      ).loadString('assets/editions.json');
      final Map<String, dynamic> jsonMap = json.decode(jsonString);
      if (!mounted) return;
      setState(() {
        availableEditions = List<String>.from(jsonMap['editions']);
      });
    } catch (e) {
      debugPrint('Error loading editions: $e');
      if (!mounted) return;
      setState(() {
        availableEditions = ['id-indonesian', 'en-sahih', 'ar-jalalayn'];
      });
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
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: colorScheme.outline,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: 'QURAN DOWNLOADS',
                        style: GoogleFonts.spaceGrotesk(
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                          color: colorScheme.onSurface,
                          letterSpacing: -1,
                        ),
                      ),
                      TextSpan(
                        text: '.',
                        style: GoogleFonts.spaceGrotesk(
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                          color: colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_service.status != DownloadStatus.idle)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.2),
                      border: Border.all(color: colorScheme.primary),
                    ),
                    child: Text(
                      _service.status == DownloadStatus.paused ? 'PAUSED' : 'DOWNLOADING',
                      style: GoogleFonts.spaceGrotesk(
                        color: colorScheme.primary,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              controller: widget.scrollController,
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Download translations and tafsir for offline reading.',
                    style: GoogleFonts.spaceGrotesk(
                      color: colorScheme.onSurface.withValues(alpha: 0.5),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      border: Border.all(color: colorScheme.outline),
                      borderRadius: BorderRadius.circular(0),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedEditionToAdd,
                        hint: Text(
                          'Select edition to add',
                          style: GoogleFonts.spaceGrotesk(
                            color: colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                        dropdownColor: Theme.of(context).cardColor,
                        isExpanded: true,
                        items: availableEditions
                            .where((e) => !_service.queue.contains(e) && !_service.downloadedEditions.contains(e))
                            .map((String value) => DropdownMenuItem<String>(
                                  value: value,
                                  child: Text(value, style: GoogleFonts.spaceGrotesk(color: colorScheme.onSurface)),
                                ))
                            .toList(),
                        onChanged: (newValue) {
                          if (newValue != null) {
                            setState(() {
                              _service.addToQueue(newValue);
                              selectedEditionToAdd = null;
                            });
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (_service.status != DownloadStatus.idle || _service.queue.isNotEmpty) ...[
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _service.status == DownloadStatus.downloading ? _service.pauseDownload : _service.startDownload,
                            icon: Icon(_service.status == DownloadStatus.downloading ? Icons.pause : Icons.play_arrow, color: Colors.black),
                            label: Text(
                              _service.status == DownloadStatus.downloading ? 'Pause' : 'Resume',
                              style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold, color: Colors.black),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: colorScheme.primary,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        if (_service.status != DownloadStatus.idle)
                          IconButton(
                            onPressed: _service.stopDownload,
                            icon: const Icon(Icons.stop, color: Colors.redAccent),
                            style: IconButton.styleFrom(
                              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                              side: BorderSide(color: colorScheme.outline),
                            ),
                          ),
                      ],
                    ),
                    if (_service.status != DownloadStatus.idle) ...[
                      const SizedBox(height: 12),
                      LinearProgressIndicator(
                        value: _service.progress,
                        backgroundColor: colorScheme.surfaceContainerHighest,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Downloading ${_service.currentEdition}: Surah ${_settings.formatNumber(_service.currentSurah)} of ${_settings.formatNumber(114)}',
                        style: GoogleFonts.spaceGrotesk(color: colorScheme.onSurface.withValues(alpha: 0.5), fontSize: 12),
                      ),
                    ],
                    const SizedBox(height: 24),
                  ],
                  if (_service.queue.isNotEmpty) ...[
                    Text('Queue:', style: GoogleFonts.spaceGrotesk(color: colorScheme.onSurface, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _service.queue.length,
                      itemBuilder: (context, index) {
                        final edition = _service.queue[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          width: double.infinity,
                          decoration: BoxDecoration(border: Border.all(color: colorScheme.outline), borderRadius: BorderRadius.circular(0)),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(edition, style: GoogleFonts.spaceGrotesk(color: colorScheme.onSurface, fontSize: 14)),
                              IconButton(
                                icon: Icon(Icons.close, size: 18, color: colorScheme.onSurface.withValues(alpha: 0.5)),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () => _service.removeFromQueue(edition),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                  ],
                  if (_service.downloadedEditions.isNotEmpty) ...[
                    Container(height: 1, color: colorScheme.outline),
                    const SizedBox(height: 24),
                    Text('Downloaded:', style: GoogleFonts.spaceGrotesk(color: colorScheme.onSurface, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 200),
                      child: Scrollbar(
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: _service.downloadedEditions.length,
                          itemBuilder: (context, index) {
                            final edition = _service.downloadedEditions[index];
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: Theme.of(context).cardColor,
                                border: Border.all(color: colorScheme.outline),
                                borderRadius: BorderRadius.circular(0),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(edition, style: GoogleFonts.spaceGrotesk(color: colorScheme.onSurface.withValues(alpha: 0.5), fontSize: 14)),
                                  const Icon(Icons.check_circle_outline, color: Color(0xFF40B779), size: 18),
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
