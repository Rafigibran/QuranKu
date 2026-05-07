import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';
import '../services/audio_service.dart';

@pragma('vm:entry-point')
Future<void> backgroundCallback(Uri? uri) async {
  if (uri?.host == 'murotal_play_pause') {
    final audioService = AudioService();
    if (audioService.isPlaying) {
      await audioService.pause();
    } else {
      await audioService.resume();
    }
  } else if (uri?.host == 'murotal_prev') {
    AudioService().playPrevSurah();
  } else if (uri?.host == 'murotal_next') {
    AudioService().playNextSurah();
  }
}

class WidgetService {
  static const String _androidWidgetPrayerLocation = 'PrayerLocationWidgetReceiver';

  static Future<void> init() async {
    await HomeWidget.registerBackgroundCallback(backgroundCallback);
  }

  static Future<void> updatePrayerWidgets({
    required String location,
    required Map<String, String> prayerTimes,
    required String nextPrayerName,
    required String nextPrayerTime,
  }) async {
    try {
      await HomeWidget.saveWidgetData('location_name', location);
      await HomeWidget.saveWidgetData('date_str', DateFormat('d MMM').format(DateTime.now()));

      await HomeWidget.saveWidgetData('fajr_time', prayerTimes['Subuh'] ?? '--:--');
      await HomeWidget.saveWidgetData('dhuhr_time', prayerTimes['Dzuhur'] ?? '--:--');
      await HomeWidget.saveWidgetData('asr_time', prayerTimes['Ashar'] ?? '--:--');
      await HomeWidget.saveWidgetData('maghrib_time', prayerTimes['Maghrib'] ?? '--:--');
      await HomeWidget.saveWidgetData('isha_time', prayerTimes['Isya'] ?? '--:--');

      await HomeWidget.saveWidgetData('next_prayer_name', nextPrayerName);
      await HomeWidget.saveWidgetData('next_prayer_time', nextPrayerTime);

      await HomeWidget.updateWidget(name: _androidWidgetPrayerLocation);
    } catch (e) {
      print('Error updating prayer widgets: $e');
    }
  }
}
