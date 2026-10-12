import 'package:flutter_test/flutter_test.dart';
import 'package:quranku/screens/ayah_search_screen.dart';

void main() {
  group('parseAyahSearchResults', () {
    test('404 tanpa hasil -> list kosong (bukan error)', () {
      const body =
          '{"code":404,"status":"NOT FOUND","data":"Nothing matching your search was found.."}';
      expect(parseAyahSearchResults(404, body), isEmpty);
    });

    test('200 dengan hasil -> baris ter-parse', () {
      const body =
          '{"code":200,"status":"OK","data":{"count":1,"matches":['
          '{"number":30,"text":"contoh terjemahan",'
          '"edition":{"identifier":"id.indonesian"},'
          '"surah":{"number":2,"englishName":"Al-Baqara"},'
          '"numberInSurah":23}]}}';
      final results = parseAyahSearchResults(200, body);
      expect(results, hasLength(1));
      expect(results.first['surah'], 2);
      expect(results.first['numberInSurah'], 23);
      expect(results.first['surahName'], 'Al-Baqara');
      expect(results.first['text'], 'contoh terjemahan');
    });

    test('200 dengan matches kosong -> list kosong', () {
      const body = '{"code":200,"status":"OK","data":{"count":0,"matches":[]}}';
      expect(parseAyahSearchResults(200, body), isEmpty);
    });

    test('200 tanpa key matches -> list kosong', () {
      const body = '{"code":200,"status":"OK","data":{"count":0}}';
      expect(parseAyahSearchResults(200, body), isEmpty);
    });

    test('body bukan JSON -> throw FormatException', () {
      expect(
        () => parseAyahSearchResults(200, '<html>oops</html>'),
        throwsA(isA<FormatException>()),
      );
    });

    test('body JSON tapi bukan object -> throw FormatException', () {
      expect(
        () => parseAyahSearchResults(200, '["bukan","object"]'),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
