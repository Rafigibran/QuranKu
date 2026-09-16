import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';

/// Per-prayer notification style. `off` disables that prayer (Muslim Pro
/// pattern: each of Subuh/Dzuhur/Ashar/Maghrib/Isya has its own mode).
enum AdhanMode { fullAdhan, simple, vibration, silent, off }

enum Muezzin { makkah, madinah }

class AdhanService extends ChangeNotifier {
  static final AdhanService _instance = AdhanService._internal();
  factory AdhanService() => _instance;
  AdhanService._internal();

  static const _keyMuezzin = 'adhan_muezzin';
  static const _keyVolume = 'adhan_volume';
  static const _keyEnabled = 'adhan_enabled';
  static const _keyPrayerModes = 'adhan_prayer_modes';
  // Legacy (migrated): single global mode + per-prayer on/off.
  static const _keyModeLegacy = 'adhan_mode';
  static const _keyPerPrayerLegacy = 'adhan_per_prayer';

  final FlutterLocalNotificationsPlugin _notifs =
      FlutterLocalNotificationsPlugin();
  final AudioPlayer _player = AudioPlayer();
  bool _tzInit = false;

  Muezzin muezzin = Muezzin.makkah;
  double volume = 0.9;
  bool enabled = true;
  Map<String, AdhanMode> prayerModes = {
    'Subuh': AdhanMode.fullAdhan,
    'Dzuhur': AdhanMode.fullAdhan,
    'Ashar': AdhanMode.fullAdhan,
    'Maghrib': AdhanMode.fullAdhan,
    'Isya': AdhanMode.fullAdhan,
  };

  static const Map<Muezzin, String> assetPath = {
    Muezzin.makkah: 'assets/adhan/makkah.mp3',
    Muezzin.madinah: 'assets/adhan/madinah.mp3',
  };

  /// Fajr adzan differs (contains as-salatu khayrun min an-nawm) — bundled
  /// per muezzin (Internet Archive, Makkah/Madinah recordings).
  static const Map<Muezzin, String> assetPathFajr = {
    Muezzin.makkah: 'assets/adhan/makkah_fajr.mp3',
    Muezzin.madinah: 'assets/adhan/madinah_fajr.mp3',
  };

  static const Map<Muezzin, String> streamUrl = {
    // Configurable public streams. Replace with licensed files for production.
    Muezzin.makkah: 'https://www.islamcan.com/audio/adhan/azan1.mp3',
    Muezzin.madinah: 'https://www.islamcan.com/audio/adhan/azan2.mp3',
  };

  String get muezzinLabel => muezzin == Muezzin.makkah ? 'Makkah' : 'Madinah';

  static String modeLabel(AdhanMode mode) {
    switch (mode) {
      case AdhanMode.fullAdhan:
        return 'Adzan penuh';
      case AdhanMode.simple:
        return 'Nada dering';
      case AdhanMode.vibration:
        return 'Getar saja';
      case AdhanMode.silent:
        return 'Notifikasi saja';
      case AdhanMode.off:
        return 'Mati';
    }
  }

  static IconData modeIcon(AdhanMode mode) {
    switch (mode) {
      case AdhanMode.fullAdhan:
        return Icons.mosque_rounded;
      case AdhanMode.simple:
        return Icons.notifications_active_rounded;
      case AdhanMode.vibration:
        return Icons.vibration_rounded;
      case AdhanMode.silent:
        return Icons.notifications_rounded;
      case AdhanMode.off:
        return Icons.notifications_off_rounded;
    }
  }

  /// Pure helpers for prefs encode/decode — unit tested.
  static String encodeModes(Map<String, AdhanMode> modes) {
    return modes.entries.map((e) => '${e.key}:${e.value.name}').join(',');
  }

  static Map<String, AdhanMode> decodeModes(
    String? raw,
    Map<String, AdhanMode> fallback,
  ) {
    final out = Map<String, AdhanMode>.from(fallback);
    if (raw == null || raw.isEmpty) return out;
    for (final part in raw.split(',')) {
      final kv = part.split(':');
      if (kv.length == 2 && out.containsKey(kv[0])) {
        for (final m in AdhanMode.values) {
          if (m.name == kv[1]) {
            out[kv[0]] = m;
            break;
          }
        }
      }
    }
    return out;
  }

  Future<void> init() async {
    final p = await SharedPreferences.getInstance();
    final m = p.getString(_keyMuezzin);
    if (m == 'madinah') muezzin = Muezzin.madinah;
    volume = p.getDouble(_keyVolume) ?? 0.9;
    enabled = p.getBool(_keyEnabled) ?? true;
    final stored = p.getString(_keyPrayerModes);
    if (stored != null) {
      prayerModes = decodeModes(stored, prayerModes);
    } else {
      // One-time migration from legacy global mode + per-prayer bools.
      prayerModes = _migrateLegacy(p);
      await p.setString(_keyPrayerModes, encodeModes(prayerModes));
    }
    await p.remove(_keyModeLegacy);
    await p.remove(_keyPerPrayerLegacy);
    await _initTimezone();
    const android = AndroidInitializationSettings('@mipmap/launcher_icon');
    const linux = LinuxInitializationSettings(defaultActionName: 'Buka');
    const settings = InitializationSettings(android: android, linux: linux);
    try {
      await _notifs.initialize(settings: settings);
    } catch (e) {
      debugPrint('Adhan notif init failed: $e');
    }
    try {
      await _player.setVolume(volume);
    } catch (_) {}
    notifyListeners();
  }

  Future<void> _initTimezone() async {
    if (_tzInit) return;
    try {
      tzdata.initializeTimeZones();
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('Asia/Jakarta'));
    }
    _tzInit = true;
  }

  /// Legacy prefs (global mode name + `Subuh:1,...` bools) become per-prayer
  /// modes: disabled prayers turn `off`, enabled ones inherit global mode.
  Map<String, AdhanMode> _migrateLegacy(SharedPreferences p) {
    var global = AdhanMode.fullAdhan;
    final md = p.getString(_keyModeLegacy);
    if (md != null) {
      for (final e in AdhanMode.values) {
        if (e.name == md) {
          global = e;
          break;
        }
      }
    }
    final out = Map<String, AdhanMode>.from(prayerModes);
    final pp = p.getString(_keyPerPrayerLegacy);
    if (pp != null && pp.isNotEmpty) {
      for (final part in pp.split(',')) {
        final kv = part.split(':');
        if (kv.length == 2 && out.containsKey(kv[0])) {
          out[kv[0]] = kv[1] == '1' ? global : AdhanMode.off;
        }
      }
    }
    return out;
  }

  Future<void> _persist() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_keyMuezzin, muezzin.name);
    await p.setDouble(_keyVolume, volume);
    await p.setBool(_keyEnabled, enabled);
    await p.setString(_keyPrayerModes, encodeModes(prayerModes));
  }

  Future<void> setMuezzin(Muezzin m) async {
    muezzin = m;
    await _persist();
    notifyListeners();
  }

  Future<void> setPrayerMode(String name, AdhanMode m) async {
    if (!prayerModes.containsKey(name)) return;
    prayerModes[name] = m;
    await _persist();
    notifyListeners();
  }

  Future<void> setVolume(double v) async {
    volume = v.clamp(0.0, 1.0);
    try {
      await _player.setVolume(volume);
    } catch (_) {}
    await _persist();
    notifyListeners();
  }

  Future<void> setEnabled(bool v) async {
    enabled = v;
    await _persist();
    notifyListeners();
    if (!v) await cancelAll();
  }

  AdhanMode prayerMode(String name) => prayerModes[name] ?? AdhanMode.off;

  tz.TZDateTime _todayAt(String hhmm) {
    final now = tz.TZDateTime.now(tz.local);
    final parts = hhmm.split(':');
    final h = int.tryParse(parts[0]) ?? 0;
    final m = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    var dt = tz.TZDateTime(tz.local, now.year, now.month, now.day, h, m);
    if (dt.isBefore(now)) dt = dt.add(const Duration(days: 1));
    return dt;
  }

  Future<void> schedulePrayers(Map<String, String> times) async {
    await _initTimezone();
    await cancelAll();
    if (!enabled) return;
    const names = ['Subuh', 'Dzuhur', 'Ashar', 'Maghrib', 'Isya'];
    const keys = ['subuh', 'dzuhur', 'ashar', 'maghrib', 'isya'];
    for (var i = 0; i < names.length; i++) {
      final label = names[i];
      final m = prayerModes[label] ?? AdhanMode.off;
      if (m == AdhanMode.off) continue;
      final t = times[keys[i]] ?? '';
      if (t.isEmpty) continue;
      final when = _todayAt(t);
      await _scheduleOne(i + 1, label, when, m);
    }
  }

  Future<void> _scheduleOne(
    int id,
    String label,
    tz.TZDateTime when,
    AdhanMode m,
  ) async {
    final android = AndroidNotificationDetails(
      'adhan_channel',
      'Adzan',
      channelDescription: 'Pengingat waktu sholat',
      importance: Importance.max,
      priority: Priority.high,
      playSound: m == AdhanMode.simple,
      enableVibration:
          m == AdhanMode.vibration || m == AdhanMode.fullAdhan,
      onlyAlertOnce: false,
    );
    final details = NotificationDetails(android: android);
    try {
      await _notifs.zonedSchedule(
        id: id,
        title: 'Waktu $label',
        body: m == AdhanMode.silent
            ? 'Waktunya sholat $label'
            : 'Waktunya sholat $label ($muezzinLabel)',
        scheduledDate: when,
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (e) {
      debugPrint('Adhan schedule failed $label: $e');
    }
  }

  Future<void> cancelAll() async {
    try {
      await _notifs.cancelAll();
    } catch (_) {}
  }

  /// Bundled asset for a muezzin, Fajr-aware. Single selection point so
  /// Subuh always uses the Fajr version for both Makkah and Madinah.
  String adhanAsset({bool fajr = false}) {
    return fajr ? assetPathFajr[muezzin]! : assetPath[muezzin]!;
  }

  Future<void> preview([AdhanMode? m, bool fajr = false]) async {
    final use = m ?? AdhanMode.fullAdhan;
    switch (use) {
      case AdhanMode.silent:
        await _notifs.show(
          id: 999,
          title: 'Tes notifikasi',
          body: 'Notifikasi adzan ($muezzinLabel)',
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails('adhan_channel', 'Adzan'),
          ),
        );
        break;
      case AdhanMode.vibration:
        HapticFeedback.heavyImpact();
        break;
      case AdhanMode.simple:
        HapticFeedback.selectionClick();
        await _notifs.show(
          id: 999,
          title: 'Tes nada',
          body: 'Nada pengingat ($muezzinLabel)',
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails('adhan_channel', 'Adzan'),
          ),
        );
        break;
      case AdhanMode.fullAdhan:
        await playAdhan(fajr: fajr);
        break;
      case AdhanMode.off:
        break;
    }
  }

  Future<void> playAdhan({bool fajr = false}) async {
    try {
      await _player.stop();
    } catch (_) {}
    try {
      await _player.setVolume(volume);
    } catch (_) {}
    // Bundled offline assets (Makkah/Madinah x regular/Fajr).
    try {
      await _player.setAudioSource(AudioSource.asset(adhanAsset(fajr: fajr)));
      await _player.play();
      return;
    } catch (_) {}
    // Fallback to configurable stream.
    try {
      await _player.setAudioSource(
        AudioSource.uri(Uri.parse(streamUrl[muezzin]!)),
      );
      await _player.play();
    } catch (e) {
      debugPrint('Adhan playback failed: $e');
      HapticFeedback.heavyImpact();
    }
  }

  Future<void> stopAdhan() async {
    try {
      await _player.stop();
    } catch (_) {}
  }
}
