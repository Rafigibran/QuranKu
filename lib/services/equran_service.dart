import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/ayah.dart';
import '../models/surah.dart';

/// Unified client for https://equran.id APIs (no key, CORS-enabled):
/// - Quran v2 (`/api/v2`): Kemenag source, Indonesian + Latin + audio
/// - English (`/api/en`): Muhammad Asad translation + transliteration
/// - Doa (`/api/doa`): 227+ doa with arab/latin/indonesian + source
/// - Vector (`POST /api/vector`): AI semantic search, 30 req/min per IP
/// - Shalat (`/api/v2/shalat`): monthly jadwal, 517 kab/kota (Bimas Islam)
///
/// All parse functions are pure and unit tested; HTTP wrappers add
/// timeout + cache-friendly error behavior (throw [EquranException]).
class EquranService {
  static const String base = 'https://equran.id';
  static const Duration timeout = Duration(seconds: 25);

  // ------------------------------------------------------------ Audio (v2)
  // 6 qari, per-ayah + full-surah MP3 on the equran CDN. `05` (Misyari) is
  // the default: it matches the voice of the legacy offline downloads.
  static const List<({String id, String slug, String name})> qaris = [
    (id: '01', slug: 'Abdullah-Al-Juhany', name: 'Abdullah Al-Juhany'),
    (id: '02', slug: 'Abdul-Muhsin-Al-Qasim', name: 'Abdul Muhsin Al-Qasim'),
    (id: '03', slug: 'Abdurrahman-as-Sudais', name: 'Abdurrahman As-Sudais'),
    (id: '04', slug: 'Ibrahim-Al-Dossari', name: 'Ibrahim Al-Dossari'),
    (id: '05', slug: 'Misyari-Rasyid-Al-Afasi', name: 'Misyari Rasyid Al-Afasy'),
    (id: '06', slug: 'Yasser-Al-Dosari', name: 'Yasser Al-Dosari'),
  ];

  static const String defaultQariId = '05';

  static String qariSlug(String id) {
    for (final q in qaris) {
      if (q.id == id) return q.slug;
    }
    return qaris[4].slug;
  }

  static String qariName(String id) {
    for (final q in qaris) {
      if (q.id == id) return q.name;
    }
    return qaris[4].name;
  }

  static String audioAyahUrl(String qariId, int surah, int ayah) {
    final s = '${surah.toString().padLeft(3, '0')}'
        '${ayah.toString().padLeft(3, '0')}';
    return 'https://cdn.equran.id/audio-partial/${qariSlug(qariId)}/$s.mp3';
  }

  static String audioFullUrl(String qariId, int surah) {
    return 'https://cdn.equran.id/audio-full/${qariSlug(qariId)}/'
        '${surah.toString().padLeft(3, '0')}.mp3';
  }

  // ---------------------------------------------------------------- Quran v2

  static Future<List<Surah>> fetchSurahs() async {
    final body = await _getJson('$base/api/v2/surat');
    final data = (body['data'] as List<dynamic>? ?? []);
    return [for (final e in data) parseSurah(e as Map<String, dynamic>)];
  }

  static Surah parseSurah(Map<String, dynamic> e) {
    return Surah(
      number: (e['nomor'] as num).toInt(),
      name: (e['namaLatin'] as String? ?? '').trim(),
      nameAr: (e['nama'] as String? ?? '').trim(),
      type: ((e['tempatTurun'] as String? ?? '').toLowerCase().startsWith(
        'mad',
      ))
          ? 'Madaniyah'
          : 'Makkiyah',
      totalAyahs: (e['jumlahAyat'] as num).toInt(),
    );
  }

  static String parseSurahArti(Map<String, dynamic> e) =>
      (e['arti'] as String? ?? '').trim();

  /// Returns (surah, ayahs) with Indonesian translation + Indonesian Latin.
  static Future<(Surah, List<Ayah>)> fetchSurahDetail(int number) async {
    final body = await _getJson('$base/api/v2/surat/$number');
    final data = body['data'] as Map<String, dynamic>;
    final surah = parseSurah(data);
    final ayahs = [
      for (final a in (data['ayat'] as List<dynamic>? ?? []))
        parseAyah(a as Map<String, dynamic>),
    ];
    return (surah, ayahs);
  }

  static Ayah parseAyah(Map<String, dynamic> a) {
    return Ayah(
      number: (a['nomorAyat'] as num).toInt(),
      arabic: (a['teksArab'] as String? ?? '').trim(),
      translation: (a['teksIndonesia'] as String? ?? '').trim(),
      transliteration: (a['teksLatin'] as String? ?? '').trim(),
    );
  }

  /// Per-ayah tafsir list: [{ayat, teks}].
  static Future<List<EquranTafsir>> fetchTafsir(int number) async {
    final body = await _getJson('$base/api/v2/tafsir/$number');
    final data = body['data'] as Map<String, dynamic>;
    return [
      for (final t in (data['tafsir'] as List<dynamic>? ?? []))
        EquranTafsir(
          ayah: ((t as Map<String, dynamic>)['ayat'] as num).toInt(),
          teks: (t['teks'] as String? ?? '').trim(),
        ),
    ];
  }

  // ----------------------------------------------------------------- English

  /// Muhammad Asad English translation per ayah (arabic preserved).
  static Future<List<Ayah>> fetchEnglish(int number) async {
    final body = await _getJson('$base/api/en/surah/$number');
    final data = body['data'] as Map<String, dynamic>;
    return [
      for (final a in (data['ayahs'] as List<dynamic>? ?? []))
        Ayah(
          number: ((a as Map<String, dynamic>)['numberInSurah'] as num).toInt(),
          arabic: (a['textArabic'] as String? ?? '').trim(),
          translation: (a['textEnglish'] as String? ?? '').trim(),
          transliteration: (a['textLatin'] as String? ?? '').trim(),
        ),
    ];
  }

  // --------------------------------------------------------------------- Doa

  static Future<List<EquranDoa>> fetchDoa({String? grup, String? tag}) async {
    final q = <String>[];
    if (grup != null && grup.isNotEmpty) {
      q.add('grup=${Uri.encodeQueryComponent(grup)}');
    }
    if (tag != null && tag.isNotEmpty) {
      q.add('tag=${Uri.encodeQueryComponent(tag)}');
    }
    final body = await _getJson('$base/api/doa${q.isEmpty ? '' : '?${q.join('&')}'}');
    final data = body['data'];
    final list = data is List
        ? data
        : (data is Map<String, dynamic> ? (data['data'] as List? ?? []) : []);
    return [for (final e in list) parseDoa(e as Map<String, dynamic>)];
  }

  static EquranDoa parseDoa(Map<String, dynamic> e) {
    return EquranDoa(
      id: (e['id'] as num).toInt(),
      grup: (e['grup'] as String? ?? '').trim(),
      nama: (e['nama'] as String? ?? '').trim(),
      arabic: (e['ar'] as String? ?? '').trim(),
      latin: (e['tr'] as String? ?? '').trim(),
      translation: (e['idn'] as String? ?? '').trim(),
      source: (e['tentang'] as String? ?? '').trim(),
    );
  }

  // ------------------------------------------------------------------ Vector

  static DateTime? _lastVectorCall;

  /// AI semantic search. Client-throttled to one call per 2.5s (30/min/IP).
  static Future<List<VectorHit>> vectorSearch({
    required String query,
    int limit = 10,
    List<String> types = const ['ayat', 'tafsir'],
    double minScore = 0,
  }) async {
    final q = query.trim();
    if (q.isEmpty) return const [];
    final last = _lastVectorCall;
    if (last != null) {
      final wait = Duration(milliseconds: 2500) - DateTime.now().difference(last);
      if (wait > Duration.zero) await Future.delayed(wait);
    }
    try {
      final res = await http
          .post(
            Uri.parse('$base/api/vector'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'cari': q,
              'batas': limit.clamp(1, 10),
              'tipe': types,
              'skorMin': minScore,
            }),
          )
          .timeout(timeout);
      if (res.statusCode != 200) {
        throw EquranException('vector ${res.statusCode}');
      }
      final body = json.decode(res.body) as Map<String, dynamic>;
      final hasil = (body['hasil'] as List<dynamic>? ?? []);
      return [for (final h in hasil) VectorHit.parse(h as Map<String, dynamic>)];
    } finally {
      _lastVectorCall = DateTime.now();
    }
  }

  // ------------------------------------------------------------------ Kajian

  /// Info kajian sunnah (Telegram aggregation). Paginated; `kota` filters
  /// server-side when provided. Thumbnails live on the kajian CDN; about
  /// 1 in 8 items has no image — UI must always render a designed fallback.
  static Future<KajianPage> fetchKajian({
    int page = 1,
    int limit = 24,
    String? kota,
  }) async {
    final q = <String>[
      'page=${page.clamp(1, 10000)}',
      'limit=${limit.clamp(1, 50)}',
    ];
    if (kota != null && kota.isNotEmpty && kota != 'Semua') {
      q.add('kota=${Uri.encodeQueryComponent(kota)}');
    }
    final body = await _getJson('$base/api/v2/kajian?${q.join('&')}');
    final items = (body['data'] as List<dynamic>? ?? []);
    final pg = (body['pagination'] as Map<String, dynamic>?) ?? const {};
    return KajianPage(
      items: [for (final e in items) KajianInfo.parse(e as Map<String, dynamic>)],
      page: ((pg['page'] as num?) ?? page).toInt(),
      totalPages: ((pg['totalPages'] as num?) ?? page).toInt(),
      total: ((pg['total'] as num?) ?? items.length).toInt(),
    );
  }

  // ------------------------------------------------------------------ Shalat

  static Future<List<String>> fetchProvinsi() async {
    final body = await _getJson('$base/api/v2/shalat/provinsi');
    return [(body['data'] as List<dynamic>? ?? []).map((e) => '$e').toList()]
        .first;
  }

  static Future<List<String>> fetchKabkota(String provinsi) async {
    final body = await _postJson('$base/api/v2/shalat/kabkota', {
      'provinsi': provinsi,
    });
    return [(body['data'] as List<dynamic>? ?? []).map((e) => '$e').toList()]
        .first;
  }

  static Future<ShalatMonth> fetchJadwal({
    required String provinsi,
    required String kabkota,
    int? bulan,
    int? tahun,
  }) async {
    final now = DateTime.now();
    final payload = <String, dynamic>{
      'provinsi': provinsi,
      'kabkota': kabkota,
      'bulan': bulan ?? now.month,
      'tahun': tahun ?? now.year,
    };
    final body = await _postJson('$base/api/v2/shalat', payload);
    if (body['code'] != 200 || body['data'] == null) {
      throw EquranException('${body['message'] ?? 'jadwal gagal'}');
    }
    return ShalatMonth.parse(body['data'] as Map<String, dynamic>);
  }

  // ------------------------------------------------------------------ helpers

  static Future<Map<String, dynamic>> _getJson(String url) async {
    try {
      final res = await http
          .get(Uri.parse(url), headers: {'Accept': 'application/json'})
          .timeout(timeout);
      if (res.statusCode != 200) throw EquranException('GET $url: ${res.statusCode}');
      return json.decode(res.body) as Map<String, dynamic>;
    } catch (e) {
      if (e is EquranException) rethrow;
      throw EquranException('GET $url gagal: $e');
    }
  }

  static Future<Map<String, dynamic>> _postJson(
    String url,
    Map<String, dynamic> payload,
  ) async {
    try {
      final res = await http
          .post(
            Uri.parse(url),
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: json.encode(payload),
          )
          .timeout(timeout);
      if (res.statusCode != 200) throw EquranException('POST $url: ${res.statusCode}');
      return json.decode(res.body) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('EquranService POST $url: $e');
      if (e is EquranException) rethrow;
      throw EquranException('POST $url gagal: $e');
    }
  }
}

class EquranException implements Exception {
  final String message;
  const EquranException(this.message);
  @override
  String toString() => 'EquranException: $message';
}

class EquranTafsir {
  final int ayah;
  final String teks;
  const EquranTafsir({required this.ayah, required this.teks});
}

/// One kajian event. `imageUrl` may be empty — UI renders a fallback.
class KajianInfo {
  final String id;
  final String tema;
  final String pemateri;
  final String tanggal;
  final String eventDate;
  final String hari;
  final String waktu;
  final String lokasi;
  final String kota;
  final String alamat;
  final String penyelenggara;
  final String imageUrl;
  final String sourceUrl;
  final String postedAt;
  const KajianInfo({
    required this.id,
    required this.tema,
    required this.pemateri,
    required this.tanggal,
    required this.eventDate,
    required this.hari,
    required this.waktu,
    required this.lokasi,
    required this.kota,
    required this.alamat,
    required this.penyelenggara,
    required this.imageUrl,
    required this.sourceUrl,
    this.postedAt = '',
  });

  factory KajianInfo.parse(Map<String, dynamic> e) {
    final img = e['image'];
    final url = img is Map ? '${img['url'] ?? ''}' : '';
    return KajianInfo(
      id: '${e['id'] ?? ''}',
      tema: ('${e['tema'] ?? ''}').trim(),
      pemateri: ('${e['pemateri'] ?? ''}').trim(),
      tanggal: ('${e['tanggal'] ?? ''}').trim(),
      eventDate: '${e['eventDate'] ?? ''}',
      hari: ('${e['hari'] ?? ''}').trim(),
      waktu: ('${e['waktu'] ?? ''}').trim(),
      lokasi: ('${e['lokasi'] ?? ''}').trim(),
      kota: ('${e['kota'] ?? ''}').trim(),
      alamat: ('${e['alamat'] ?? ''}').trim(),
      penyelenggara: ('${e['penyelenggara'] ?? ''}').trim(),
      imageUrl: url.trim(),
      sourceUrl: ('${e['sourceUrl'] ?? ''}').trim(),
      postedAt: ('${e['postedAt'] ?? ''}').trim(),
    );
  }

  bool get hasImage => imageUrl.isNotEmpty;
}

class KajianPage {
  final List<KajianInfo> items;
  final int page;
  final int totalPages;
  final int total;
  const KajianPage({
    required this.items,
    required this.page,
    required this.totalPages,
    required this.total,
  });

  bool get hasMore => page < totalPages;
}

/// Pure client-side kajian filters — unit tested.
/// Date modes: `semua`, `hariIni`, `tujuhHari`, `tigaPuluhHari`.
/// Sort modes: `terdekat` (eventDate asc), `terbaru` (postedAt desc).
class KajianFilter {
  static DateTime? _dateOf(KajianInfo e) {
    if (e.eventDate.isEmpty) return null;
    try {
      return DateTime.parse(e.eventDate);
    } catch (_) {
      return null;
    }
  }

  static List<KajianInfo> byDate(
    List<KajianInfo> items,
    String mode, {
    DateTime? today,
  }) {
    if (mode == 'semua') return items;
    final now = today ?? DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final int days;
    switch (mode) {
      case 'hariIni':
        days = 0;
        break;
      case 'tujuhHari':
        days = 6;
        break;
      case 'tigaPuluhHari':
        days = 29;
        break;
      default:
        return items;
    }
    final end = start.add(Duration(days: days + 1));
    return [
      for (final e in items)
        if (_dateOf(e) case final d?)
          if (!d.isBefore(start) && d.isBefore(end)) e,
    ];
  }

  static List<KajianInfo> sort(List<KajianInfo> items, String mode) {
    final list = List<KajianInfo>.from(items);
    if (mode == 'terbaru') {
      list.sort((a, b) => b.postedAt.compareTo(a.postedAt));
    } else {
      list.sort((a, b) => a.eventDate.compareTo(b.eventDate));
    }
    return list;
  }
}

class EquranDoa {
  final int id;
  final String grup;
  final String nama;
  final String arabic;
  final String latin;
  final String translation;
  final String source;
  const EquranDoa({
    required this.id,
    required this.grup,
    required this.nama,
    required this.arabic,
    required this.latin,
    required this.translation,
    required this.source,
  });
}

class VectorHit {
  final String tipe; // surat | ayat | tafsir | doa
  final double skor;
  final String relevansi;
  final Map<String, dynamic> data;
  const VectorHit({
    required this.tipe,
    required this.skor,
    required this.relevansi,
    required this.data,
  });

  factory VectorHit.parse(Map<String, dynamic> h) {
    return VectorHit(
      tipe: (h['tipe'] as String? ?? '').trim(),
      skor: ((h['skor'] as num?) ?? 0).toDouble(),
      relevansi: (h['relevansi'] as String? ?? '').trim(),
      data: (h['data'] as Map<String, dynamic>?) ?? const {},
    );
  }

  int? get surahNumber {
    final v = data['id_surat'];
    return v is num ? v.toInt() : int.tryParse('$v');
  }

  int? get ayahNumber {
    final v = data['nomor_ayat'];
    return v is num ? v.toInt() : int.tryParse('$v');
  }

  String get title {
    final s = data['nama_surat'];
    final a = ayahNumber;
    if (s == null) return tipe;
    return a == null ? '$s' : '$s : $a';
  }

  String get snippet {
    for (final k in const ['terjemahan_id', 'isi', 'teks_latin', 'idn', 'tr']) {
      final v = data[k];
      if (v is String && v.trim().isNotEmpty) return v.trim();
    }
    return '';
  }
}

class ShalatDay {
  final int tanggal;
  final String tanggalLengkap;
  final String hari;
  final Map<String, String> times; // imsak, subuh, terbit, dhuha, dzuhur, ashar, maghrib, isya
  const ShalatDay({
    required this.tanggal,
    required this.tanggalLengkap,
    required this.hari,
    required this.times,
  });

  factory ShalatDay.parse(Map<String, dynamic> e) {
    final times = <String, String>{};
    for (final k in const [
      'imsak',
      'subuh',
      'terbit',
      'dhuha',
      'dzuhur',
      'ashar',
      'maghrib',
      'isya',
    ]) {
      times[k] = '${e[k] ?? ''}';
    }
    return ShalatDay(
      tanggal: (e['tanggal'] as num).toInt(),
      tanggalLengkap: '${e['tanggal_lengkap'] ?? ''}',
      hari: '${e['hari'] ?? ''}',
      times: times,
    );
  }
}

class ShalatMonth {
  final String provinsi;
  final String kabkota;
  final int bulan;
  final int tahun;
  final String bulanNama;
  final List<ShalatDay> days;
  const ShalatMonth({
    required this.provinsi,
    required this.kabkota,
    required this.bulan,
    required this.tahun,
    required this.bulanNama,
    required this.days,
  });

  factory ShalatMonth.parse(Map<String, dynamic> d) {
    return ShalatMonth(
      provinsi: '${d['provinsi'] ?? ''}',
      kabkota: '${d['kabkota'] ?? ''}',
      bulan: (d['bulan'] as num).toInt(),
      tahun: (d['tahun'] as num).toInt(),
      bulanNama: '${d['bulan_nama'] ?? ''}',
      days: [
        for (final e in (d['jadwal'] as List<dynamic>? ?? []))
          ShalatDay.parse(e as Map<String, dynamic>),
      ],
    );
  }

  /// Times for a `yyyy-MM-dd` date, null when outside this month.
  Map<String, String>? timesFor(String tanggalLengkap) {
    for (final d in days) {
      if (d.tanggalLengkap == tanggalLengkap) return d.times;
    }
    return null;
  }
}
