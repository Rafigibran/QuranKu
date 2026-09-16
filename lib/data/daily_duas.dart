import '../utils/localized.dart';

/// Localized text of one dua. Every language variant carries the same shape so
/// the UI never has to special-case a locale.
class DuaText {
  final String title;
  final String category;
  final String translation;
  final String source;
  const DuaText({
    required this.title,
    required this.category,
    required this.translation,
    required this.source,
  });
}

class DailyDua {
  /// Stable bookmark key. Never localized — see [DuaText].
  final String id;
  final String arabic;
  final String latin;

  /// Localized variants keyed by language code. Fallback order is
  /// requested language → `id` → first available.
  final Map<String, DuaText> texts;

  const DailyDua({
    required this.id,
    required this.arabic,
    required this.latin,
    required this.texts,
  });

  DuaText textFor(String languageCode) =>
      localizedValue(texts, languageCode);

  /// The Indonesian variant, used by the legacy bookmark migration.
  DuaText? get indonesianText => texts['id'];
}

/// Normalizes an arbitrary locale tag to one of the app's language codes.
String duaLanguageCode(String languageCode) =>
    languageCode.startsWith('en') ? 'en' : 'id';

// Short famous duas from Hisnul Muslim / sahih sources.
// Kept short to guarantee accuracy. Verify against mushaf if in doubt.
//
// English renderings are plain-language translations of the Indonesian text
// already shipped here; the Arabic is unchanged.
const List<DailyDua> dailyDuas = [
  DailyDua(
    id: 'bundled-1',
    arabic:
        'رَبَّنَا آتِنَا فِي الدُّنْيَا حَسَنَةً وَفِي الْآخِرَةِ حَسَنَةً وَقِنَا عَذَابَ النَّارِ',
    latin:
        'Rabbana atina fid-dunya hasanah, wa fil-akhirati hasanah, wa qina adzaban-nar',
    texts: {
      'id': DuaText(
        title: 'Kebaikan dunia akhirat',
        category: 'Pagi & Petang',
        translation:
            'Ya Tuhan kami, berilah kami kebaikan di dunia dan kebaikan di akhirat, dan lindungilah kami dari siksa neraka.',
        source: 'QS Al-Baqarah: 201',
      ),
      'en': DuaText(
        title: 'Good in this world and the Hereafter',
        category: 'Morning & Evening',
        translation:
            'Our Lord, give us good in this world and good in the Hereafter, and protect us from the punishment of the Fire.',
        source: 'Quran 2:201',
      ),
    },
  ),
  DailyDua(
    id: 'bundled-2',
    arabic:
        'اللَّهُمَّ إِنِّي أَسْأَلُكَ عِلْمًا نَافِعًا وَرِزْقًا طَيِّبًا وَعَمَلًا مُتَقَبَّلًا',
    latin:
        'Allahumma inni asaluka ilman nafian, wa rizqan thayyiban, wa amalan mutaqabbalan',
    texts: {
      'id': DuaText(
        title: 'Ilmu bermanfaat',
        category: 'Pagi',
        translation:
            'Ya Allah, aku memohon kepada-Mu ilmu yang bermanfaat, rezeki yang baik, dan amal yang diterima.',
        source: 'HR Ibnu Majah',
      ),
      'en': DuaText(
        title: 'Beneficial knowledge',
        category: 'Morning',
        translation:
            'O Allah, I ask You for beneficial knowledge, good provision, and accepted deeds.',
        source: 'Ibn Majah',
      ),
    },
  ),
  DailyDua(
    id: 'bundled-3',
    arabic:
        'اللَّهُمَّ بِكَ أَصْبَحْنَا وَبِكَ أَمْسَيْنَا وَبِكَ نَحْيَا وَبِكَ نَمُوتُ وَإِلَيْكَ النُّشُورُ',
    latin:
        'Allahumma bika ashbahna, wa bika amsaina, wa bika nahya, wa bika namut, wa ilaikan-nusyur',
    texts: {
      'id': DuaText(
        title: 'Dzikir pagi',
        category: 'Pagi',
        translation:
            'Ya Allah, dengan-Mu kami berpagi hari, dengan-Mu kami berpetang hari, dengan-Mu kami hidup dan mati, dan kepada-Mu kebangkitan.',
        source: 'HR Tirmidzi',
      ),
      'en': DuaText(
        title: 'Morning remembrance',
        category: 'Morning',
        translation:
            'O Allah, by You we enter the morning and by You we enter the evening, by You we live and by You we die, and to You is the resurrection.',
        source: 'Tirmidhi',
      ),
    },
  ),
  DailyDua(
    id: 'bundled-4',
    arabic:
        'اللَّهُمَّ بِكَ أَمْسَيْنَا وَبِكَ أَصْبَحْنَا وَبِكَ نَحْيَا وَبِكَ نَمُوتُ وَإِلَيْكَ الْمَصِيرُ',
    latin:
        'Allahumma bika amsaina, wa bika ashbahna, wa bika nahya, wa bika namut, wa ilaykal-mashir',
    texts: {
      'id': DuaText(
        title: 'Dzikir petang',
        category: 'Petang',
        translation:
            'Ya Allah, dengan-Mu kami berpetang hari, dengan-Mu kami berpagi hari, dengan-Mu kami hidup dan mati, dan kepada-Mu tempat kembali.',
        source: 'HR Tirmidzi',
      ),
      'en': DuaText(
        title: 'Evening remembrance',
        category: 'Evening',
        translation:
            'O Allah, by You we enter the evening and by You we enter the morning, by You we live and by You we die, and to You is the final destination.',
        source: 'Tirmidhi',
      ),
    },
  ),
  DailyDua(
    id: 'bundled-5',
    arabic: 'بِاسْمِكَ اللَّهُمَّ أَحْيَا وَبِاسْمِكَ أَمُوتُ',
    latin: 'Bismika Allahumma ahya, wa bismika amut',
    texts: {
      'id': DuaText(
        title: 'Sebelum tidur',
        category: 'Tidur',
        translation:
            'Dengan nama-Mu ya Allah aku hidup, dan dengan nama-Mu aku mati.',
        source: 'HR Bukhari',
      ),
      'en': DuaText(
        title: 'Before sleeping',
        category: 'Sleep',
        translation:
            'In Your name, O Allah, I live and in Your name I die.',
        source: 'Bukhari',
      ),
    },
  ),
  DailyDua(
    id: 'bundled-6',
    arabic:
        'الْحَمْدُ لِلَّهِ الَّذِي أَحْيَانَا بَعْدَ مَا أَمَاتَنَا وَإِلَيْهِ النُّشُورُ',
    latin: 'Alhamdulillahilladzi ahyana bada ma amatana, wa ilaihin-nusyur',
    texts: {
      'id': DuaText(
        title: 'Bangun tidur',
        category: 'Tidur',
        translation:
            'Segala puji bagi Allah yang menghidupkan kami setelah mematikan kami, dan kepada-Nya kebangkitan.',
        source: 'HR Bukhari',
      ),
      'en': DuaText(
        title: 'Upon waking up',
        category: 'Sleep',
        translation:
            'All praise is for Allah who gave us life after He had caused us to die, and to Him is the resurrection.',
        source: 'Bukhari',
      ),
    },
  ),
  DailyDua(
    id: 'bundled-7',
    arabic:
        'رَبَّنَا هَبْ لَنَا مِنْ أَزْوَاجِنَا وَذُرِّيَّاتِنَا قُرَّةَ أَعْيُنٍ وَاجْعَلْنَا لِلْمُتَّقِينَ إِمَامًا',
    latin:
        'Rabbana hab lana min azwajina wa dzurriyyatina qurrata ayun, wajalana lil-muttaqina imama',
    texts: {
      'id': DuaText(
        title: 'Keluarga saleh',
        category: 'Keluarga',
        translation:
            'Ya Tuhan kami, anugerahkanlah kepada kami pasangan dan keturunan sebagai penyejuk hati, dan jadikanlah kami pemimpin bagi orang-orang bertakwa.',
        source: 'QS Al-Furqan: 74',
      ),
      'en': DuaText(
        title: 'Righteous family',
        category: 'Family',
        translation:
            'Our Lord, grant us from among our spouses and offspring comfort to our eyes, and make us leaders of the righteous.',
        source: 'Quran 25:74',
      ),
    },
  ),
  DailyDua(
    id: 'bundled-8',
    arabic: 'اللَّهُمَّ افْتَحْ لِي أَبْوَابَ رَحْمَتِكَ',
    latin: 'Allahummaftah li abwaba rahmatik',
    texts: {
      'id': DuaText(
        title: 'Masuk masjid',
        category: 'Ibadah',
        translation: 'Ya Allah, bukakanlah untukku pintu-pintu rahmat-Mu.',
        source: 'HR Muslim',
      ),
      'en': DuaText(
        title: 'Entering the mosque',
        category: 'Worship',
        translation: 'O Allah, open for me the gates of Your mercy.',
        source: 'Muslim',
      ),
    },
  ),
  DailyDua(
    id: 'bundled-9',
    arabic: 'اللَّهُمَّ إِنِّي أَسْأَلُكَ مِنْ فَضْلِكَ',
    latin: 'Allahumma inni asaluka min fadlik',
    texts: {
      'id': DuaText(
        title: 'Keluar masjid',
        category: 'Ibadah',
        translation: 'Ya Allah, aku memohon karunia-Mu.',
        source: 'HR Muslim',
      ),
      'en': DuaText(
        title: 'Leaving the mosque',
        category: 'Worship',
        translation: 'O Allah, I ask You from Your bounty.',
        source: 'Muslim',
      ),
    },
  ),
  DailyDua(
    id: 'bundled-10',
    arabic: 'سُبْحَانَ الَّذِي سَخَّرَ لَنَا هَذَا وَمَا كُنَّا لَهُ مُقْرِنِينَ',
    latin: 'Subhanalladzi sakhkhara lana hadza, wa ma kunna lahu muqrinin',
    texts: {
      'id': DuaText(
        title: 'Naik kendaraan',
        category: 'Safar',
        translation:
            'Maha Suci (Allah) yang menundukkan kendaraan ini untuk kami, padahal kami tidak mampu menguasainya.',
        source: 'QS Az-Zukhruf: 13',
      ),
      'en': DuaText(
        title: 'Boarding a vehicle',
        category: 'Travel',
        translation:
            'Exalted is He who has subjected this to us, and we could not have subdued it.',
        source: 'Quran 43:13',
      ),
    },
  ),
];

/// Maps the pre-i18n bookmark keys (Indonesian dua titles) to the stable ids
/// introduced with [DailyDua.id]. Built from the data so it cannot drift.
Map<String, String> legacyDuaBookmarkIds() => {
  for (final dua in dailyDuas)
    if (dua.indonesianText != null) dua.indonesianText!.title: dua.id,
};
