import 'package:flutter_test/flutter_test.dart';
import 'package:quranku/services/equran_service.dart';

void main() {
  group('parseSurah', () {
    test('maps equran v2 fields', () {
      final s = EquranService.parseSurah({
        'nomor': 1,
        'nama': 'الفاتحة',
        'namaLatin': 'Al-Fatihah',
        'jumlahAyat': 7,
        'tempatTurun': 'Mekah',
        'arti': 'Pembukaan',
      });
      expect(s.number, 1);
      expect(s.name, 'Al-Fatihah');
      expect(s.nameAr, 'الفاتحة');
      expect(s.type, 'Makkiyah');
      expect(s.totalAyahs, 7);
    });

    test('detects Madaniyah', () {
      final s = EquranService.parseSurah({
        'nomor': 2,
        'nama': 'البقرة',
        'namaLatin': 'Al-Baqarah',
        'jumlahAyat': 286,
        'tempatTurun': 'Madinah',
        'arti': 'Sapi Betina',
      });
      expect(s.type, 'Madaniyah');
    });
  });

  group('parseAyah', () {
    test('maps Indonesian + Latin', () {
      final a = EquranService.parseAyah({
        'nomorAyat': 1,
        'teksArab': 'بِسْمِ',
        'teksLatin': 'Bismillāhir-raḥmānir-raḥīm(i).',
        'teksIndonesia': 'Dengan nama Allah',
      });
      expect(a.number, 1);
      expect(a.translation, 'Dengan nama Allah');
      expect(a.transliteration, contains('Bismillāhir'));
    });
  });

  group('parseDoa', () {
    test('maps doa fields', () {
      final d = EquranService.parseDoa({
        'id': 1,
        'grup': 'Doa Tidur',
        'nama': 'Doa Sebelum Tidur 1',
        'ar': 'بِاسْمِكَ',
        'tr': 'Bismika',
        'idn': 'Dengan nama Engkau',
        'tentang': 'HR. Bukhari',
      });
      expect(d.id, 1);
      expect(d.latin, 'Bismika');
      expect(d.source, 'HR. Bukhari');
    });
  });

  group('VectorHit', () {
    test('title/snippet/numbers', () {
      final h = VectorHit.parse({
        'tipe': 'ayat',
        'skor': 0.8542,
        'relevansi': 'tinggi',
        'data': {
          'id_surat': 2,
          'nama_surat': 'Al-Baqarah',
          'nomor_ayat': 153,
          'terjemahan_id': 'Mohonlah pertolongan dengan sabar',
        },
      });
      expect(h.surahNumber, 2);
      expect(h.ayahNumber, 153);
      expect(h.title, 'Al-Baqarah : 153');
      expect(h.snippet, contains('sabar'));
    });
  });

  group('qari audio', () {
    test('six qari with Misyari default', () {
      expect(EquranService.qaris.length, 6);
      expect(EquranService.defaultQariId, '05');
      expect(EquranService.qariName('03'), 'Abdurrahman As-Sudais');
      expect(EquranService.qariSlug('99'), 'Misyari-Rasyid-Al-Afasi');
    });

    test('CDN URL shapes', () {
      expect(
        EquranService.audioAyahUrl('05', 1, 1),
        'https://cdn.equran.id/audio-partial/Misyari-Rasyid-Al-Afasi/001001.mp3',
      );
      expect(
        EquranService.audioAyahUrl('03', 2, 255),
        'https://cdn.equran.id/audio-partial/Abdurrahman-as-Sudais/002255.mp3',
      );
      expect(
        EquranService.audioFullUrl('01', 114),
        'https://cdn.equran.id/audio-full/Abdullah-Al-Juhany/114.mp3',
      );
    });
  });

  group('KajianInfo', () {
    test('parses full item with image', () {
      final k = KajianInfo.parse({
        'id': '7839',
        'tema': 'Islam & Kesehatan',
        'pemateri': 'Ustadz Khalid Basalamah',
        'tanggal': 'Kamis, 17 September 2026',
        'eventDate': '2026-09-17',
        'hari': 'Kamis',
        'waktu': '19:00 - Selesai WIB',
        'lokasi': 'Auditorium Graha Widyatama',
        'kota': 'Purwokerto',
        'alamat': 'Purwokerto, Jawa Tengah',
        'penyelenggara': 'Fakultas Kedokteran',
        'image': {'url': 'https://cdn-infokajian.equran.id/kajian/x/21642.jpg'},
        'sourceUrl': 'https://t.me/khalidbasalamahofficial/21642',
      });
      expect(k.id, '7839');
      expect(k.hasImage, isTrue);
      expect(k.eventDate, '2026-09-17');
    });

    test('missing image flags fallback', () {
      final k = KajianInfo.parse({
        'id': '1',
        'tema': 'Kajian Rutin',
        'image': null,
      });
      expect(k.hasImage, isFalse);
      expect(k.imageUrl, isEmpty);
      expect(k.pemateri, isEmpty);
    });
  });

  group('KajianFilter', () {
    KajianInfo k(String date, [String posted = '']) => KajianInfo(
      id: date,
      tema: 't',
      pemateri: '',
      tanggal: '',
      eventDate: date,
      hari: '',
      waktu: '',
      lokasi: '',
      kota: '',
      alamat: '',
      penyelenggara: '',
      imageUrl: '',
      sourceUrl: '',
      postedAt: posted,
    );

    final items = [k('2026-09-15'), k('2026-09-18'), k('2026-10-20'), k('')];
    final today = DateTime(2026, 9, 15);

    test('semua passes through', () {
      expect(KajianFilter.byDate(items, 'semua', today: today).length, 4);
    });

    test('hariIni / tujuhHari / tigaPuluhHari windows', () {
      expect(
        KajianFilter.byDate(items, 'hariIni', today: today).length,
        1,
      );
      expect(
        KajianFilter.byDate(items, 'tujuhHari', today: today).length,
        2,
      );
      expect(
        KajianFilter.byDate(items, 'tigaPuluhHari', today: today).length,
        2,
      );
    });

    test('sort terdekat asc, terbaru by postedAt desc', () {
      final dated = items.where((e) => e.eventDate.isNotEmpty).toList();
      final asc = KajianFilter.sort(dated, 'terdekat');
      expect(asc.first.eventDate, '2026-09-15');
      expect(asc.last.eventDate, '2026-10-20');
      final withPosted = [
        k('2026-09-18', '2026-09-10T00:00:00Z'),
        k('2026-09-15', '2026-09-14T00:00:00Z'),
      ];
      final desc = KajianFilter.sort(withPosted, 'terbaru');
      expect(desc.first.eventDate, '2026-09-15');
    });
  });

  group('ShalatMonth', () {
    test('parses monthly jadwal', () {
      final m = ShalatMonth.parse({
        'provinsi': 'DKI Jakarta',
        'kabkota': 'Kota Jakarta',
        'bulan': 9,
        'tahun': 2026,
        'bulan_nama': 'September',
        'jadwal': [
          {
            'tanggal': 1,
            'tanggal_lengkap': '2026-09-01',
            'hari': 'Selasa',
            'imsak': '04:28',
            'subuh': '04:38',
            'terbit': '05:50',
            'dhuha': '06:17',
            'dzuhur': '11:56',
            'ashar': '15:14',
            'maghrib': '17:56',
            'isya': '19:05',
          },
        ],
      });
      expect(m.days.length, 1);
      expect(m.timesFor('2026-09-01')!['subuh'], '04:38');
      expect(m.timesFor('2026-09-02'), isNull);
    });
  });
}
