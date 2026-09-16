import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the `id`/`en` ARB pair from drifting apart.
///
/// `app_id.arb` is the template, so any key defined there must exist in
/// `app_en.arb` too — and with the same placeholders, otherwise
/// `flutter gen-l10n` produces a getter whose signature differs per locale.
void main() {
  late Map<String, dynamic> idArb;
  late Map<String, dynamic> enArb;

  Set<String> messages(Map<String, dynamic> arb) =>
      arb.keys.where((k) => !k.startsWith('@')).toSet();

  Set<String> metaKeys(Map<String, dynamic> arb) => arb.keys
      .where((k) => k.startsWith('@') && !k.startsWith('@@'))
      .map((k) => k.substring(1))
      .toSet();

  List<String> placeholders(Map<String, dynamic> arb, String key) {
    final meta = arb['@$key'];
    if (meta is! Map) return const [];
    final placeholders = meta['placeholders'];
    if (placeholders is! Map) return const [];
    return placeholders.keys.cast<String>().toList()..sort();
  }

  setUpAll(() {
    idArb =
        json.decode(File('lib/l10n/app_id.arb').readAsStringSync())
            as Map<String, dynamic>;
    enArb =
        json.decode(File('lib/l10n/app_en.arb').readAsStringSync())
            as Map<String, dynamic>;
  });

  test('id and en define exactly the same message keys', () {
    expect(
      messages(idArb).difference(messages(enArb)),
      isEmpty,
      reason: 'keys present in app_id.arb but missing from app_en.arb',
    );
    expect(
      messages(enArb).difference(messages(idArb)),
      isEmpty,
      reason: 'keys present in app_en.arb but missing from the template',
    );
  });

  test('every message has @-metadata in both locales', () {
    expect(messages(idArb).difference(metaKeys(idArb)), isEmpty);
    expect(messages(enArb).difference(metaKeys(enArb)), isEmpty);
  });

  test('placeholders match across locales', () {
    for (final key in messages(idArb)) {
      expect(
        placeholders(enArb, key),
        placeholders(idArb, key),
        reason: 'placeholder mismatch for "$key"',
      );
    }
  });

  test('no empty translations', () {
    for (final arb in [idArb, enArb]) {
      for (final key in messages(arb)) {
        expect((arb[key] as String).trim(), isNotEmpty, reason: key);
      }
    }
  });

  test('plural messages declare an "other" branch in both locales', () {
    for (final key in messages(idArb)) {
      for (final arb in [idArb, enArb]) {
        final value = arb[key] as String;
        if (!value.contains(', plural,')) continue;
        expect(value, contains('other{'), reason: '$key is missing "other"');
      }
    }
  });
}
