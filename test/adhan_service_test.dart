import 'package:flutter_test/flutter_test.dart';
import 'package:quranku/services/adhan_service.dart';

void main() {
  const fallback = {
    'Subuh': AdhanMode.fullAdhan,
    'Dzuhur': AdhanMode.fullAdhan,
    'Ashar': AdhanMode.fullAdhan,
    'Maghrib': AdhanMode.fullAdhan,
    'Isya': AdhanMode.fullAdhan,
  };

  group('encode/decode prayer modes', () {
    test('round-trips all modes', () {
      const modes = {
        'Subuh': AdhanMode.vibration,
        'Dzuhur': AdhanMode.fullAdhan,
        'Ashar': AdhanMode.simple,
        'Maghrib': AdhanMode.silent,
        'Isya': AdhanMode.off,
      };
      final raw = AdhanService.encodeModes(modes);
      expect(raw, contains('Subuh:vibration'));
      expect(raw, contains('Isya:off'));
      final back = AdhanService.decodeModes(raw, fallback);
      expect(back, modes);
    });

    test('ignores unknown prayers and modes', () {
      final back = AdhanService.decodeModes(
        'Subuh:getar,Fajr:fullAdhan,Imsak:simple',
        fallback,
      );
      expect(back['Subuh'], AdhanMode.fullAdhan);
      expect(back.keys, hasLength(5));
    });

    test('null/empty returns fallback copy', () {
      expect(AdhanService.decodeModes(null, fallback), fallback);
      expect(AdhanService.decodeModes('', fallback), fallback);
    });
  });

  group('fajr asset selection', () {
    test('bundled assets cover both muezzins x regular/fajr', () {
      TestWidgetsFlutterBinding.ensureInitialized();
      final svc = AdhanService();
      expect(svc.adhanAsset(), 'assets/adhan/makkah.mp3');
      expect(svc.adhanAsset(fajr: true), 'assets/adhan/makkah_fajr.mp3');
      expect(AdhanService.assetPathFajr[Muezzin.madinah],
          'assets/adhan/madinah_fajr.mp3');
    });
  });

  group('labels', () {    test('all five modes labeled', () {
      expect(AdhanService.modeLabel(AdhanMode.fullAdhan), 'Adzan penuh');
      expect(AdhanService.modeLabel(AdhanMode.simple), 'Nada dering');
      expect(AdhanService.modeLabel(AdhanMode.vibration), 'Getar saja');
      expect(AdhanService.modeLabel(AdhanMode.silent), 'Notifikasi saja');
      expect(AdhanService.modeLabel(AdhanMode.off), 'Mati');
    });
  });
}
