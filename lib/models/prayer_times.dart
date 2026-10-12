class PrayerTimes {
  final String date;
  final String subuh;
  final String dzuhur;
  final String ashar;
  final String maghrib;
  final String isya;
  final String imsak;
  final String dhuha;

  PrayerTimes({
    required this.date,
    required this.subuh,
    required this.dzuhur,
    required this.ashar,
    required this.maghrib,
    required this.isya,
    required this.imsak,
    required this.dhuha,
  });

  factory PrayerTimes.fromJson(Map<String, dynamic> json) {
    return PrayerTimes(
      date: json['tanggal_lengkap']?.toString() ?? '',
      subuh: json['subuh']?.toString() ?? '',
      dzuhur: json['dzuhur']?.toString() ?? '',
      ashar: json['ashar']?.toString() ?? '',
      maghrib: json['maghrib']?.toString() ?? '',
      isya: json['isya']?.toString() ?? '',
      imsak: json['imsak']?.toString() ?? '', // Imsak might not be in all responses
      dhuha: json['dhuha']?.toString() ?? '',
    );
  }
}
