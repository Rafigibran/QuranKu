import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quranku/services/settings_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('saved collections', () {
    test('asmaul toggle persists round-trip', () async {
      SharedPreferences.setMockInitialValues(const {});
      final s = SettingsService();
      expect(s.isAsmaulSaved(5), isFalse);
      await s.toggleAsmaulSaved(5);
      expect(s.isAsmaulSaved(5), isTrue);
      expect(s.savedAsmaul, contains('5'));
      await s.toggleAsmaulSaved(5);
      expect(s.isAsmaulSaved(5), isFalse);
    });

    test('dua toggle trims and ignores empty', () async {
      SharedPreferences.setMockInitialValues(const {});
      final s = SettingsService();
      await s.toggleDuaSaved('  ');
      expect(s.savedDuas, isEmpty);
      await s.toggleDuaSaved('Doa Tidur ');
      expect(s.isDuaSaved('Doa Tidur'), isTrue);
      await s.toggleDuaSaved('Doa Tidur');
      expect(s.isDuaSaved('Doa Tidur'), isFalse);
    });
  });
}
