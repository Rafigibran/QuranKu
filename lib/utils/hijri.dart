import 'package:hijri/hijri_calendar.dart';

class HijriInfo {
  final int year;
  final int month;
  final int day;
  final String monthName;
  final String full;
  final bool isRamadan;
  final bool isEidFitr;
  final bool isEidAdha;
  final bool isArafah;
  HijriInfo({
    required this.year,
    required this.month,
    required this.day,
    required this.monthName,
    required this.full,
    required this.isRamadan,
    required this.isEidFitr,
    required this.isEidAdha,
    required this.isArafah,
  });
}

const List<String> hijriMonthsId = [
  'Muharram',
  'Safar',
  'Rabiul Awal',
  'Rabiul Akhir',
  'Jumadil Awal',
  'Jumadil Akhir',
  'Rajab',
  'Syakban',
  'Ramadan',
  'Syawal',
  'Zulkaidah',
  'Zulhijah',
];

const List<String> hijriMonthsEn = [
  'Muharram',
  'Safar',
  'Rabi al-Awwal',
  'Rabi al-Thani',
  'Jumada al-Awwal',
  'Jumada al-Thani',
  'Rajab',
  'Shaban',
  'Ramadan',
  'Shawwal',
  'Dhu al-Qadah',
  'Dhu al-Hijjah',
];

List<String> hijriMonthNames(String? languageCode) =>
    languageCode != null && languageCode.startsWith('en')
    ? hijriMonthsEn
    : hijriMonthsId;

HijriInfo hijriToday({DateTime? date, String languageCode = 'id'}) {
  final now = date ?? DateTime.now();
  final h = HijriCalendar.fromDate(now);
  final m = h.hMonth;
  final d = h.hDay;
  final y = h.hYear;
  final isEnglish = languageCode.startsWith('en');
  final months = hijriMonthNames(languageCode);
  final name = (m >= 1 && m <= 12)
      ? months[m - 1]
      : (isEnglish ? 'Hijri' : 'Hijriah');
  return HijriInfo(
    year: y,
    month: m,
    day: d,
    monthName: name,
    full: '$d $name $y ${isEnglish ? 'AH' : 'H'}',
    isRamadan: m == 9,
    isEidFitr: m == 10 && d == 1,
    isEidAdha: m == 12 && d == 10,
    isArafah: m == 12 && d == 9,
  );
}
