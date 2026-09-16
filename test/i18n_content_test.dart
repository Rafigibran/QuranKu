import 'package:flutter_test/flutter_test.dart';
import 'package:quranku/data/asmaul_husna.dart';
import 'package:quranku/data/hajj_guide.dart';
import 'package:quranku/models/dhikr.dart';
import 'package:quranku/services/tasbih_service.dart';
import 'package:quranku/utils/localized.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('Asmaul Husna', () {
    test('has 99 names numbered 1..99 without gaps', () {
      expect(asmaulHusna, hasLength(99));
      expect(
        asmaulHusna.map((a) => a.number).toList(),
        List.generate(99, (i) => i + 1),
      );
    });

    test('id and en meanings cover exactly the same numbers', () {
      final numbers = asmaulHusna.map((a) => a.number).toSet();
      expect(asmaulMeaningId.keys.toSet(), numbers);
      expect(asmaulMeaningEn.keys.toSet(), numbers);
    });

    test('no empty meanings in either language', () {
      for (final map in [asmaulMeaningId, asmaulMeaningEn]) {
        for (final entry in map.entries) {
          expect(entry.value.trim(), isNotEmpty, reason: '${entry.key}');
        }
      }
    });

    test('resolver picks the language and falls back to Indonesian', () {
      expect(asmaulMeaning(1, 'id'), 'Maha Pengasih');
      expect(asmaulMeaning(1, 'en'), 'The Most Compassionate');
      expect(asmaulMeaning(1, 'en_US'), 'The Most Compassionate');
      expect(asmaulMeaning(1, 'fr'), 'Maha Pengasih');
      expect(asmaulMeaning(999, 'en'), isEmpty);
    });

    test('every name carries Arabic text and a transliteration', () {
      for (final name in asmaulHusna) {
        expect(name.arabic.trim(), isNotEmpty, reason: '${name.number}');
        expect(name.latin.trim(), isNotEmpty, reason: '${name.number}');
      }
    });

    test('arabic texts are unique — the real identity of each name', () {
      // The transliterations are NOT unique: Al-Majid (48) and Al-Majid (65)
      // both romanize to "Al-Majid" in this data set, which is expected.
      final arabic = asmaulHusna.map((a) => a.arabic).toList();
      expect(arabic.toSet(), hasLength(arabic.length));
    });
  });

  group('localizedValue', () {
    test('picks the exact language, then the language prefix', () {
      const map = {'id': 'satu', 'en': 'one'};
      expect(localizedValue(map, 'id'), 'satu');
      expect(localizedValue(map, 'en'), 'one');
      expect(localizedValue(map, 'en_US'), 'one');
      expect(localizedValue(map, 'id-ID'), 'satu');
    });

    test('falls back to id, then to any entry', () {
      const withId = {'id': 'satu', 'en': 'one'};
      expect(localizedValue(withId, 'fr'), 'satu');

      const enOnly = {'en': 'one'};
      expect(localizedValue(enOnly, 'fr'), 'one');
    });
  });

  group('Hajj & Umrah guide', () {
    test('ships two sections: Hajj and Umrah', () {
      expect(hajjUmrahGuides, hasLength(2));
      expect(
        hajjUmrahGuides.map((s) => s.textFor('id').title).toList(),
        ['Haji', 'Umrah'],
      );
      expect(
        hajjUmrahGuides.map((s) => s.textFor('en').title).toList(),
        ['Hajj', 'Umrah'],
      );
    });

    test('every section, list, and step carries both languages', () {
      for (final section in hajjUmrahGuides) {
        expect(section.texts.keys, containsAll(<String>['id', 'en']));
        for (final text in section.texts.values) {
          expect(text.title.trim(), isNotEmpty);
          expect(text.intro.trim(), isNotEmpty);
          // The reference lists are the reason this guide is not a summary.
          expect(text.lists, isNotEmpty, reason: text.title);
          for (final list in text.lists) {
            expect(list.title.trim(), isNotEmpty);
            expect(list.items, isNotEmpty, reason: list.title);
            for (final item in list.items) {
              expect(item.trim(), isNotEmpty, reason: list.title);
            }
          }
        }
        for (final step in section.steps) {
          expect(step.texts.keys, containsAll(<String>['id', 'en']));
          for (final text in step.texts.values) {
            expect(text.title.trim(), isNotEmpty);
            expect(text.place.trim(), isNotEmpty);
            expect(text.description.trim(), isNotEmpty);
            for (final item in text.sunnah) {
              expect(item.trim(), isNotEmpty, reason: text.title);
            }
          }
        }
      }
    });

    test('both languages carry the same structure', () {
      for (final section in hajjUmrahGuides) {
        final id = section.textFor('id');
        final en = section.textFor('en');
        expect(
          en.lists.length,
          id.lists.length,
          reason: '${id.title}: reference list count',
        );
        for (var i = 0; i < id.lists.length; i++) {
          expect(
            en.lists[i].items.length,
            id.lists[i].items.length,
            reason: '${id.lists[i].title}: item count',
          );
        }
        for (final step in section.steps) {
          final stepId = step.textFor('id');
          final stepEn = step.textFor('en');
          expect(
            stepEn.sunnah.length,
            stepId.sunnah.length,
            reason: '${stepId.title}: sunnah count',
          );
          expect(
            stepEn.note == null,
            stepId.note == null,
            reason: '${stepId.title}: note presence',
          );
          expect(
            stepEn.dua == null,
            stepId.dua == null,
            reason: '${stepId.title}: dua presence',
          );
        }
      }
    });

    test('steps are ordered 1..n inside each section', () {
      for (final section in hajjUmrahGuides) {
        expect(
          section.steps.map((s) => s.order).toList(),
          List.generate(section.steps.length, (i) => i + 1),
        );
      }
    });

    test('covers the rites of Hajj and Umrah', () {
      final total = hajjUmrahGuides.fold<int>(
        0,
        (sum, section) => sum + section.steps.length,
      );
      expect(total, 12);
    });

    test('records more than ten sunnah acts across the guide', () {
      final sunnah = [
        for (final section in hajjUmrahGuides)
          for (final step in section.steps) ...step.textFor('id').sunnah,
      ];
      expect(sunnah.length, greaterThan(10));
    });

    test('records where the schools of law differ', () {
      final notes = [
        for (final section in hajjUmrahGuides)
          for (final step in section.steps)
            if (step.textFor('id').note != null) step.textFor('id').note!,
      ];
      expect(notes.length, greaterThanOrEqualTo(5));
      expect(
        notes.any((n) => n.toLowerCase().contains('hanafi')),
        isTrue,
        reason: 'the farewell tawaf is the clearest difference to record',
      );
    });

    test('carries no Arabic script, by design', () {
      // PRODUCT.md forbids guessing sacred text. A mistyped Arabic formula is
      // worse than none, so the guide names each supplication and explains it.
      bool hasArabic(String value) => value.runes.any(
        (r) =>
            (r >= 0x0600 && r <= 0x06FF) ||
            (r >= 0x0750 && r <= 0x077F) ||
            (r >= 0xFB50 && r <= 0xFDFF) ||
            (r >= 0xFE70 && r <= 0xFEFF),
      );

      for (final section in hajjUmrahGuides) {
        for (final text in section.texts.values) {
          expect(hasArabic(text.title), isFalse);
          expect(hasArabic(text.intro), isFalse);
          for (final list in text.lists) {
            expect(hasArabic(list.title), isFalse);
            for (final item in list.items) {
              expect(hasArabic(item), isFalse);
            }
          }
        }
        for (final step in section.steps) {
          for (final text in step.texts.values) {
            expect(hasArabic(text.description), isFalse, reason: text.title);
            for (final item in text.sunnah) {
              expect(hasArabic(item), isFalse, reason: text.title);
            }
            if (text.dua != null) {
              expect(hasArabic(text.dua!), isFalse, reason: text.title);
            }
            if (text.note != null) {
              expect(hasArabic(text.note!), isFalse, reason: text.title);
            }
          }
        }
      }
    });

    test('resolver returns language-appropriate text', () {
      final hajj = hajjUmrahGuides.first;
      expect(hajj.steps.first.textFor('id').place, 'Miqat, bulan haji');
      expect(hajj.steps.first.textFor('id').title, 'Ihram');
      expect(hajj.steps.first.textFor('en').description, contains('miqat'));
      expect(hajj.steps[2].textFor('en').title, 'Standing at Arafah');
      expect(hajj.steps[2].textFor('id').title, 'Wukuf');
    });
  });

  group('Dhikr', () {
    test('translationFor prefers English, falling back to the source', () {
      final dhikr = Dhikr(
        id: 'x',
        arabic: 'سُبْحَانَ اللهِ',
        translation: 'Maha Suci Allah',
        translationEn: 'Glory be to Allah',
      );
      expect(dhikr.translationFor('id'), 'Maha Suci Allah');
      expect(dhikr.translationFor('en'), 'Glory be to Allah');
      expect(dhikr.translationFor('en_GB'), 'Glory be to Allah');
      expect(dhikr.translationFor('fr'), 'Maha Suci Allah');
    });

    test('user-authored dhikr falls back to its own translation', () {
      final dhikr = Dhikr(
        id: 'x',
        arabic: 'ذكر',
        translation: 'Dzikir buatan saya',
      );
      expect(dhikr.translationFor('en'), 'Dzikir buatan saya');
    });

    test('translationEn survives a json round trip', () {
      final dhikr = Dhikr(
        id: '1',
        arabic: 'سُبْحَانَ اللهِ',
        latin: 'Subhanallah',
        translation: 'Maha Suci Allah',
        translationEn: 'Glory be to Allah',
        category: 'dzikir',
      );
      final restored = Dhikr.decodeList(Dhikr.encodeList([dhikr])).single;
      expect(restored.translationEn, 'Glory be to Allah');
      expect(restored.translation, 'Maha Suci Allah');
    });

    test('copyWith can clear translationEn for edited presets', () {
      final dhikr = Dhikr(
        id: '1',
        arabic: 'a',
        translation: 'id',
        translationEn: 'en',
      );
      final edited = dhikr.copyWith(translation: 'baru', translationEn: '');
      expect(edited.translation, 'baru');
      expect(edited.translationEn, isEmpty);
      expect(edited.translationFor('en'), 'baru');
    });

    test('missing translationEn in stored json decodes to empty, not null', () {
      final legacy = Dhikr.decodeList(
        '[{"id":"1","arabic":"a","translation":"lama"}]',
      ).single;
      expect(legacy.translationEn, isEmpty);
      expect(legacy.translationFor('en'), 'lama');
    });
  });

  group('Tasbih presets', () {
    test('the eight seeded presets carry both languages', () async {
      SharedPreferences.setMockInitialValues({});
      final service = TasbihService();
      await service.init();

      expect(service.items, hasLength(8));
      for (final dhikr in service.items) {
        expect(dhikr.translation.trim(), isNotEmpty, reason: dhikr.id);
        expect(dhikr.translationEn.trim(), isNotEmpty, reason: dhikr.id);
        expect(dhikr.category, isNotEmpty, reason: dhikr.id);
      }
    });
  });
}
