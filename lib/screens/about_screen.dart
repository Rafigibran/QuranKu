import 'package:flutter/material.dart';
import 'package:quranku/l10n/app_localizations.dart';
import 'package:quranku/l10n/l10n.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/audio_service.dart';
import '../services/update_service.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  final AudioService _audioService = AudioService();
  final UpdateService _updates = UpdateService();

  static const String _developerName = 'QuranKu Community';
  static const String _githubProfile = 'https://github.com/Rafigibran';
  static const String _repository = 'https://github.com/Rafigibran/QuranKu';
  static const String _issues = 'https://github.com/Rafigibran/QuranKu/issues';

  @override
  void initState() {
    super.initState();
    _audioService.addListener(_onAudioChanged);
    _updates.addListener(_onAudioChanged);
    _updates.loadInstalled();
  }

  @override
  void dispose() {
    _audioService.removeListener(_onAudioChanged);
    _updates.removeListener(_onAudioChanged);
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

  Future<void> _checkForUpdates() async {
    final ok = await _updates.checkLatest();
    if (!mounted) return;
    if (!ok) {
      _showMessage(_updates.error ?? context.l10n.aboutUpdateFailed);
      return;
    }
    if (!_updates.updateAvailable) {
      final v = _updates.installedVersion;
      _showMessage(
        v.isEmpty
            ? context.l10n.aboutNoUpdate
            : context.l10n.aboutLatestVersion(v),
      );
    }
  }

  Future<void> _downloadAndInstall() async {
    final ok = await _updates.downloadAndInstall();
    if (!mounted) return;
    if (!ok && _updates.error != null) {
      _showMessage(_updates.error!);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: l.aboutTitle,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 24,
                  color: colorScheme.onSurface,
                  letterSpacing: -0.4,
                ),
              ),
              TextSpan(
                text: '.',
                style: TextStyle(
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
              l.aboutTitle,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 24),
            _buildAboutInfoItem(
              context,
              l.aboutDeveloper,
              _developerName,
              Icons.groups_outlined,
            ),
            _buildAboutInfoItem(
              context,
              l.aboutVersion,
              _updates.installedVersion.isEmpty
                  ? '…'
                  : 'v${_updates.installedVersion}',
              Icons.info_outline,
            ),
            _buildAboutInfoItem(
              context,
              l.aboutGithub,
              'github.com/Rafigibran',
              Icons.code,
              isLink: true,
              valueOverride: _githubProfile,
            ),
            _buildAboutInfoItem(
              context,
              l.aboutRepository,
              _repository,
              Icons.source_outlined,
              isLink: true,
            ),

            const SizedBox(height: 24),
            Text(
              l.aboutSupport,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            _buildAboutInfoItem(
              context,
              context.l10n.aboutPrayerSource,
              'Equran.id',
              Icons.api,
              isLink: true,
              valueOverride: 'https://equran.id/',
            ),

            const SizedBox(height: 24),
            Text(
              l.aboutCheckUpdate,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            if (_updates.updateAvailable && _updates.latest != null)
              _buildUpdateCard(context, colorScheme),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _updates.busy ? null : _checkForUpdates,
                icon: _updates.busy
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
                  _updates.busy
                      ? 'Working…'
                      : l.aboutCheckUpdate,
                  style: TextStyle(
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
                  l.aboutReportIssue,
                  style: TextStyle(
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
            if (_audioService.currentSurah != null) const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  /// Update card with release notes, download progress, and install.
  Widget _buildUpdateCard(BuildContext context, ColorScheme colorScheme) {
    final release = _updates.latest!;
    final downloading =
        _updates.busy && _updates.downloadProgress > 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.primary.withValues(alpha: .30),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.system_update_rounded,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Update ${release.tag} ready',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
          if (release.body.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              release.body.trim().split('\n').take(6).join('\n'),
              maxLines: 6,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
          const SizedBox(height: 12),
          if (downloading) ...[
            LinearProgressIndicator(
              value: _updates.downloadProgress,
              color: colorScheme.primary,
            ),
            const SizedBox(height: 8),
            Text(
              context.l10n.aboutDownloading((_updates.downloadProgress * 100).round()),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ] else
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _updates.busy ? null : _downloadAndInstall,
                icon: const Icon(Icons.download_rounded, size: 18),
                label: Text(context.l10n.aboutDownloadInstall),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
        ],
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
                    color: isLink ? colorScheme.primary : colorScheme.onSurface,
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
                        style: TextStyle(
                          color: colorScheme.onSurface.withValues(alpha: 0.72),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        value,
                        style: TextStyle(
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
