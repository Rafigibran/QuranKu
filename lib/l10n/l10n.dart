import 'package:flutter/widgets.dart';

import 'app_localizations.dart';

/// Shorthand for `AppLocalizations.of(context)!`.
///
/// Usage: `context.l10n.settingsTitle`
extension L10nX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this)!;
}
