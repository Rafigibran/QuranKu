import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:quranku/l10n/app_localizations_en.dart';
import 'package:quranku/l10n/tafsir_labels.dart';
import 'package:quranku/services/settings_service.dart';
import 'package:quranku/services/tafsir_api_service.dart';
import 'package:quranku/services/tafsir_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _jsonHeaders = {'content-type': 'application/json; charset=utf-8'};

http.Response _catalogue(List<Map<String, dynamic>> editions) =>
    http.Response(json.encode(editions), 200, headers: _jsonHeaders);

Map<String, dynamic> _edition(String slug, String name, String language) => {
  'slug': slug,
  'name': name,
  'author_name': 'Someone',
  'language_name': language,
  'source': 'https://example.test',
};

TafsirService _serviceWith(MockClient client) =>
    TafsirService(api: TafsirApiService(client: client));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('TafsirService.availableEditions', () {
    test('always puts the built-in Kemenag edition first', () async {
      final service = _serviceWith(
        MockClient(
          (request) async => _catalogue([
            _edition('en-al-jalalayn', 'Al-Jalalayn', 'english'),
          ]),
        ),
      );

      final editions = await service.availableEditions();
      expect(editions.first.slug, SettingsService.kemenagTafsirId);
      expect(editions.first.name, 'Tafsir Kemenag');
      expect(editions.first.languageName, 'indonesian');
    });

    test('orders curated editions before the rest of the catalogue', () async {
      final service = _serviceWith(
        MockClient(
          (request) async => _catalogue([
            _edition('ur-tafsir-bayan-ul-quran', 'Bayan ul Quran', 'urdu'),
            _edition('en-al-jalalayn', 'Al-Jalalayn', 'english'),
            _edition('indonesian-mokhtasar', 'Al-Mukhtasar', 'indonesian'),
            _edition('ar-tafsir-muyassar', 'Muyassar', 'arabic'),
          ]),
        ),
      );

      final slugs = (await service.availableEditions())
          .map((e) => e.slug)
          .toList();
      expect(slugs, [
        SettingsService.kemenagTafsirId,
        'indonesian-mokhtasar',
        'en-al-jalalayn',
        'ar-tafsir-muyassar',
        'ur-tafsir-bayan-ul-quran',
      ]);
    });

    test('does not duplicate an edition that is both curated and in the catalogue',
        () async {
      final service = _serviceWith(
        MockClient(
          (request) async => _catalogue([
            _edition('en-al-jalalayn', 'Al-Jalalayn', 'english'),
          ]),
        ),
      );

      final slugs = (await service.availableEditions())
          .map((e) => e.slug)
          .toList();
      expect(slugs.where((s) => s == 'en-al-jalalayn'), hasLength(1));
    });

    test('degrades to the built-in edition when the catalogue is offline',
        () async {
      final service = _serviceWith(
        MockClient((request) async => throw http.ClientException('offline')),
      );

      final editions = await service.availableEditions();
      expect(editions, hasLength(1));
      expect(editions.single.slug, SettingsService.kemenagTafsirId);
      expect(TafsirService.isCatalogueMissing(editions), isTrue);
    });

    test('flags a populated catalogue as present', () async {
      final service = _serviceWith(
        MockClient(
          (request) async =>
              _catalogue([_edition('en-al-jalalayn', 'Al-Jalalayn', 'english')]),
        ),
      );

      expect(
        TafsirService.isCatalogueMissing(await service.availableEditions()),
        isFalse,
      );
    });
  });

  group('TafsirService.editionName', () {
    test('resolves the built-in edition without any network call', () async {
      final service = _serviceWith(
        MockClient((request) async => throw StateError('should not be called')),
      );
      expect(
        await service.editionName(SettingsService.kemenagTafsirId),
        'Tafsir Kemenag',
      );
    });

    test('resolves a catalogue edition by slug', () async {
      final service = _serviceWith(
        MockClient(
          (request) async => _catalogue([
            _edition('en-al-jalalayn', 'Al-Jalalayn', 'english'),
          ]),
        ),
      );
      expect(await service.editionName('en-al-jalalayn'), 'Al-Jalalayn');
    });

    test('falls back to the slug when the catalogue is unavailable', () async {
      final service = _serviceWith(
        MockClient((request) async => throw http.ClientException('offline')),
      );
      expect(await service.editionName('en-al-jalalayn'), 'en-al-jalalayn');
    });
  });

  group('tafsirLanguageLabel', () {
    final l = AppLocalizationsEn();

    test('maps the languages the picker groups by', () {
      expect(tafsirLanguageLabel(l, 'indonesian'), 'Indonesian');
      expect(tafsirLanguageLabel(l, 'english'), 'English');
      expect(tafsirLanguageLabel(l, 'arabic'), 'Arabic');
    });

    test('is case and whitespace insensitive', () {
      expect(tafsirLanguageLabel(l, 'Arabic'), 'Arabic');
      expect(tafsirLanguageLabel(l, '  english '), 'English');
    });

    test('sentence-cases unknown languages instead of hiding them', () {
      expect(tafsirLanguageLabel(l, 'urdu'), 'Urdu');
      expect(tafsirLanguageLabel(l, 'central khmer'), 'Central khmer');
    });

    test('labels an empty language name', () {
      expect(tafsirLanguageLabel(l, ''), 'Other language');
    });
  });
}
