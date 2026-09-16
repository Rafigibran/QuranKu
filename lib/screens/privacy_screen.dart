import 'package:flutter/material.dart';
import 'package:quranku/l10n/app_localizations.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          l.privacyTitle,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        scrolledUnderElevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l.privacyEffectiveDate,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.onSurface.withValues(alpha: .72),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              l.privacySubtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.onSurface.withValues(alpha: .72),
              ),
            ),
            const SizedBox(height: 16),
            _section(
              context,
              l.privacyPurposeTitle,
              l.privacyPurposeBody,
            ),
            _section(
              context,
              l.privacyCollectedTitle,
              null,
              bullets: [
                l.privacyCollectedLocation,
                l.privacyCollectedPreferences,
                l.privacyCollectedAudio,
                l.privacyCollectedUpdate,
              ],
            ),
            _section(
              context,
              l.privacyNotCollectedTitle,
              null,
              bullets: [
                l.privacyNotCollectedIdentity,
                l.privacyNotCollectedGps,
                l.privacyNotCollectedSell,
                l.privacyNotCollectedAds,
              ],
            ),
            _section(
              context,
              l.privacyPermissionsTitle,
              null,
              bullets: [
                l.privacyPermissionInternet,
                l.privacyPermissionLocation,
                l.privacyPermissionNotifications,
                l.privacyPermissionInstall,
              ],
            ),
            _section(
              context,
              l.privacyThirdPartyTitle,
              null,
              bullets: [
                l.privacyThirdPartyEquran,
                l.privacyThirdPartyGithub,
                l.privacyThirdPartyQuranCom,
              ],
            ),
            _section(
              context,
              l.privacyStorageTitle,
              l.privacyStorageBody,
            ),
            _section(
              context,
              l.privacyChoicesTitle,
              null,
              bullets: [
                l.privacyChoiceLocation,
                l.privacyChoiceNotifications,
                l.privacyChoiceDownloads,
                l.privacyChoiceSaved,
              ],
            ),
            _section(
              context,
              l.privacyChildrenTitle,
              l.privacyChildrenBody,
            ),
            _section(
              context,
              l.privacyChangesTitle,
              l.privacyChangesBody,
            ),
            _section(
              context,
              l.privacyContactTitle,
              l.privacyContactBody,
            ),
          ],
        ),
      ),
    );
  }

  static Widget _section(
    BuildContext context,
    String title,
    String? body, {
    List<String>? bullets,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          if (body != null)
            Text(
              body,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                height: 1.6,
              ),
            ),
          if (bullets != null)
            ...bullets.map(
              (b) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('•  '),
                    Expanded(
                      child: Text(
                        b,
                        style: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.copyWith(height: 1.6),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
