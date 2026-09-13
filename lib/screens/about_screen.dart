import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../services/audio_service.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  final AudioService _audioService = AudioService();
  final String _appVersion = "1.0.0";

  static const String _developerName = 'Rafi Gibran';
  static const String _githubProfile = 'https://github.com/Rafigibran';
  static const String _repository = 'https://github.com/Rafigibran/QuranKu';
  static const String _issues = 'https://github.com/Rafigibran/QuranKu/issues';
  static const String _donationUrl = 'https://saweria.co/rafdev';
  static const String _latestReleaseApi =
      'https://api.github.com/repos/Rafigibran/QuranKu/releases/latest';

  bool _checkingUpdate = false;

  @override
  void initState() {
    super.initState();
    _audioService.addListener(_onAudioChanged);
  }

  @override
  void dispose() {
    _audioService.removeListener(_onAudioChanged);
    super.dispose();
  }

  void _onAudioChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _launchUrl(String urlString) async {
    try {
      final Uri url = Uri.parse(urlString);
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        debugPrint('Could not launch $url');
      }
    } catch (e) {
      debugPrint('Error launching URL: $e');
    }
  }

  int _versionPart(String version, int index) {
    final cleaned = version.replaceFirst(RegExp(r'^[vV]'), '');
    final parts = cleaned.split(RegExp(r'[-+.]'));
    if (index >= parts.length) return 0;
    return int.tryParse(parts[index]) ?? 0;
  }

  bool _isNewerVersion(String latest, String current) {
    for (var i = 0; i < 3; i++) {
      final latestPart = _versionPart(latest, i);
      final currentPart = _versionPart(current, i);
      if (latestPart != currentPart) return latestPart > currentPart;
    }
    return false;
  }

  Future<void> _checkForUpdates() async {
    if (_checkingUpdate) return;
    setState(() => _checkingUpdate = true);

    try {
      final response = await http.get(
        Uri.parse(_latestReleaseApi),
        headers: const {
          'Accept': 'application/vnd.github+json',
        },
      ).timeout(const Duration(seconds: 10));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final latestTag = (data['tag_name'] ?? '').toString();
        final releaseName = (data['name'] ?? latestTag).toString();
        final releaseUrl = (data['html_url'] ?? _repository).toString();

        if (latestTag.isNotEmpty && _isNewerVersion(latestTag, _appVersion)) {
          await _showUpdateDialog(releaseName, latestTag, releaseUrl);
        } else {
          _showMessage('QuranKu sudah menggunakan versi terbaru (v$_appVersion).');
        }
      } else if (response.statusCode == 404) {
        _showMessage('Belum ada release terbaru di GitHub.');
      } else {
        _showMessage('Tidak dapat memeriksa update saat ini.');
      }
    } catch (e) {
      if (mounted) {
        _showMessage('Gagal memeriksa update. Periksa koneksi internet.');
      }
      debugPrint('Update check error: $e');
    } finally {
      if (mounted) setState(() => _checkingUpdate = false);
    }
  }

  Future<void> _showUpdateDialog(
    String releaseName,
    String latestTag,
    String releaseUrl,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final colors = Theme.of(dialogContext).colorScheme;
        return AlertDialog(
          backgroundColor: Theme.of(dialogContext).cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: colors.outline),
          ),
          title: Text(
            'Update tersedia',
            style: GoogleFonts.spaceGrotesk(
              color: colors.onSurface,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            '$releaseName ($latestTag) tersedia di GitHub.',
            style: GoogleFonts.spaceGrotesk(
              color: colors.onSurface.withValues(alpha: 0.7),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(
                'Nanti',
                style: GoogleFonts.spaceGrotesk(color: colors.onSurface),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(dialogContext);
                await _launchUrl(releaseUrl);
              },
              child: Text(
                'Update',
                style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
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
                text: 'ABOUT',
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
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: colorScheme.onSurface),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              'About Developer',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 24),
            _buildAboutInfoItem(
              context,
              'Developer',
              _developerName,
              Icons.person_outline,
            ),
            _buildAboutInfoItem(
              context,
              'App Version',
              'v$_appVersion',
              Icons.info_outline,
            ),
            _buildAboutInfoItem(
              context,
              'GitHub',
              'github.com/Rafigibran',
              Icons.code,
              isLink: true,
              valueOverride: _githubProfile,
            ),
            _buildAboutInfoItem(
              context,
              'Repository',
              _repository,
              Icons.source_outlined,
              isLink: true,
            ),

            const SizedBox(height: 24),
            Text(
              'Attribution',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            _buildAboutInfoItem(
              context,
              'Prayer Times Source',
              'Equran.id',
              Icons.api,
              isLink: true,
              valueOverride: 'https://equran.id/',
            ),

            const SizedBox(height: 24),
            Text(
              'Support',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _launchUrl(_donationUrl),
                icon: const Icon(Icons.favorite, color: Colors.black),
                label: Text(
                  'Donate to Developer',
                  style: GoogleFonts.spaceGrotesk(
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _checkingUpdate ? null : _checkForUpdates,
                icon: _checkingUpdate
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        Icons.system_update_outlined,
                        color: colorScheme.onSurface,
                      ),
                label: Text(
                  _checkingUpdate ? 'Checking for Updates...' : 'Check for Updates',
                  style: GoogleFonts.spaceGrotesk(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: colorScheme.outline),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _launchUrl(_issues),
                icon: Icon(
                  Icons.bug_report_outlined,
                  color: colorScheme.onSurface,
                ),
                label: Text(
                  'Report Issue',
                  style: GoogleFonts.spaceGrotesk(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: colorScheme.outline),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            if (_audioService.currentSurah != null)
              const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildAboutInfoItem(
    BuildContext context,
    String label,
    String value,
    IconData icon, {
    bool isLink = false,
    String? valueOverride,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outline),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: isLink ? () => _launchUrl(valueOverride ?? value) : null,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    color: isLink
                        ? colorScheme.primary
                        : colorScheme.onSurface,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: GoogleFonts.spaceGrotesk(
                          color: colorScheme.onSurface.withValues(alpha: 0.5),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        value,
                        style: GoogleFonts.spaceGrotesk(
                          color: isLink
                              ? colorScheme.primary
                              : colorScheme.onSurface,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          decoration: isLink
                              ? TextDecoration.underline
                              : TextDecoration.none,
                          decorationColor: colorScheme.primary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (isLink)
                  Icon(
                    Icons.arrow_outward,
                    color: colorScheme.primary,
                    size: 16,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
