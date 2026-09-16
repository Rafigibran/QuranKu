import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

/// Locale tag for the app's two supported UI languages.
///
/// Accepts either a language code (`'en'`) or a full tag (`'en_US'`).
String localeTagFor(String? languageCode) =>
    languageCode != null && languageCode.startsWith('en') ? 'en_US' : 'id_ID';

/// Locale tag of the active [Localizations] scope.
String localeTagOf(BuildContext context) =>
    localeTagFor(Localizations.localeOf(context).languageCode);

/// `DateFormat` bound to the active UI language.
DateFormat dateFormatOf(BuildContext context, String pattern) =>
    DateFormat(pattern, localeTagOf(context));

/// `NumberFormat` bound to the active UI language.
NumberFormat numberFormatOf(BuildContext context, [String? pattern]) =>
    pattern == null
        ? NumberFormat(null, localeTagOf(context))
        : NumberFormat(pattern, localeTagOf(context));

/// Currency formatter bound to the active UI language.
///
/// The currency itself is unchanged — only grouping/decimal separators and
/// symbol placement follow the UI language.
NumberFormat currencyFormatOf(
  BuildContext context, {
  required String symbol,
  int decimalDigits = 0,
}) => NumberFormat.currency(
  locale: localeTagOf(context),
  symbol: symbol,
  decimalDigits: decimalDigits,
);
