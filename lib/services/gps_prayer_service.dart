import 'dart:convert';
import 'package:adhan/adhan.dart' as adhan;
import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart' show Geocoding;
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../models/prayer_times.dart';

/// GPS-based prayer calculation for anywhere on earth (offline, no API).
/// Indonesia region uses Singapore params (Fajr 20, Isha 18, = Kemenag),
/// elsewhere Muslim World League. Madhab Shafi.
class GpsPrayerService {
  static bool isInIndonesia(double lat, double lon) {
    return lat >= -11.5 && lat <= 6.5 && lon >= 94.5 && lon <= 141.5;
  }

  static String methodLabel(double lat, double lon) {
    return isInIndonesia(lat, lon) ? 'Kemenag 20/18 (GPS)' : 'MWL 18/17 (GPS)';
  }

  static adhan.CalculationParameters _params(double lat, double lon) {
    final p =
        (isInIndonesia(lat, lon)
                ? adhan.CalculationMethod.singapore
                : adhan.CalculationMethod.muslim_world_league)
            .getParameters();
    p.madhab = adhan.Madhab.shafi;
    return p;
  }

  static String _fmt(DateTime t) => DateFormat('HH:mm').format(t);

  static PrayerTimes daily(double lat, double lon, DateTime date) {
    final coords = adhan.Coordinates(lat, lon);
    final params = _params(lat, lon);
    final pt = adhan.PrayerTimes(
      coords,
      adhan.DateComponents.from(date),
      params,
    );
    final fajr = pt.fajr;
    final sunrise = pt.sunrise;
    final imsak = fajr.subtract(const Duration(minutes: 10));
    final dhuha = sunrise.add(const Duration(minutes: 30));
    return PrayerTimes(
      date: DateFormat('yyyy-MM-dd').format(date),
      subuh: _fmt(fajr),
      dzuhur: _fmt(pt.dhuhr),
      ashar: _fmt(pt.asr),
      maghrib: _fmt(pt.maghrib),
      isya: _fmt(pt.isha),
      imsak: _fmt(imsak),
      dhuha: _fmt(dhuha),
    );
  }

  static List<Map<String, dynamic>> monthly(
    double lat,
    double lon,
    int year,
    int month,
  ) {
    final lastDay = DateTime(year, month + 1, 0).day;
    final out = <Map<String, dynamic>>[];
    for (var d = 1; d <= lastDay; d++) {
      final t = daily(lat, lon, DateTime(year, month, d));
      out.add({
        'tanggal_lengkap': t.date,
        'subuh': t.subuh,
        'dzuhur': t.dzuhur,
        'ashar': t.ashar,
        'maghrib': t.maghrib,
        'isya': t.isya,
        'imsak': t.imsak,
        'dhuha': t.dhuha,
      });
    }
    return out;
  }

  /// Nearest place name for coords. Returns "City, Country" or null.
  /// Never throws; null means show coords fallback.
  static Future<String?> placeName(double lat, double lon) async {
    try {
      final marks = await Geocoding().placemarkFromCoordinates(lat, lon);
      if (marks.isEmpty) return null;
      final m = marks.first;
      final String locality = m.locality ?? '';
      final String subAdmin = m.subAdministrativeArea ?? '';
      final String admin = m.administrativeArea ?? '';
      final String country = m.country ?? '';
      final String city = locality.isNotEmpty
          ? locality
          : (subAdmin.isNotEmpty ? subAdmin : admin);
      final name = [city, country].where((s) => s.isNotEmpty).join(', ');
      return name.isEmpty ? null : name;
    } catch (e) {
      debugPrint('Reverse geocode failed: $e');
      return null;
    }
  }

  static String coordsLabel(double lat, double lon) {
    return '${lat.toStringAsFixed(4)}, ${lon.toStringAsFixed(4)}';
  }

  /// Worldwide city search (free Open-Meteo geocoding, no key).
  /// Returns up to 8 matches with name/region/country/lat/lon.
  static Future<List<Map<String, dynamic>>> searchCity(String query) async {
    final q = query.trim();
    if (q.length < 2) return [];
    final uri = Uri.parse(
      'https://geocoding-api.open-meteo.com/v1/search?name=${Uri.encodeComponent(q)}&count=8&language=id&format=json',
    );
    final res = await http.get(uri).timeout(const Duration(seconds: 12));
    if (res.statusCode != 200)
      throw Exception('Pencarian gagal (${res.statusCode})');
    final body = json.decode(res.body) as Map<String, dynamic>;
    final list = (body['results'] as List<dynamic>? ?? []);
    return list.map((e) {
      final m = e as Map<String, dynamic>;
      return {
        'name': m['name'] ?? '',
        'region': m['admin1'] ?? '',
        'country': m['country'] ?? '',
        'lat': (m['latitude'] as num).toDouble(),
        'lon': (m['longitude'] as num).toDouble(),
      };
    }).toList();
  }

  static String worldLabel(Map<String, dynamic> m) {
    final parts = [
      m['name'] as String,
      m['region'] as String,
      m['country'] as String,
    ].where((s) => s.isNotEmpty).toList();
    // Deduplicate consecutive repeats
    final dedup = <String>[];
    for (final p in parts) {
      if (dedup.isEmpty || dedup.last != p) dedup.add(p);
    }
    return dedup.join(', ');
  }

  static Future<Position> currentPosition() async {
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      throw Exception(
        'Izin lokasi ditolak. Aktifkan izin lokasi di pengaturan.',
      );
    }
    final service = await Geolocator.isLocationServiceEnabled();
    if (!service) {
      throw Exception('GPS mati. Nyalakan layanan lokasi.');
    }
    return Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
      timeLimit: const Duration(seconds: 20),
    );
  }
}
