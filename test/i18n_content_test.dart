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

    test('every section and step carries both languages', () {
      for (final section in hajjUmrahGuides) {
        expect(section.texts.keys, containsAll(<String>['id', 'en']));
        for (final text in section.texts.values) {
          expect(text.title.trim(), isNotEmpty);
          expect(text.intro.trim(), isNotEmpty);
        }
        for (final step in section.steps) {
          expect(step.texts.keys, containsAll(<String>['id', 'en']));
          for (final text in step.texts.values) {
            expect(text.title.trim(), isNotEmpty);
            expect(text.place.trim(), isNotEmpty);
            expect(text.description.trim(), isNotEmpty);
          }
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

    test('id and en step counts match', () {
      final total = hajjUmrahGuides.fold<int>(
        0,
        (sum, section) => sum + section.steps.length,
      );
      expect(total, 12);
    });

    test('resolver returns language-appropriate text', () {
      final hajj = hajjUmrahGuides.first;
      expect(hajj.steps.first.textFor('id').place, 'Miqat');
      expect(hajj.steps.first.textFor('en').description, contains('miqat'));
      expect(hajj.steps[2].textFor('en').title, 'Wukuf at Arafah');
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
