import '../utils/localized.dart';

/// A titled reference list inside a section, for example Rukun or Larangan.
class GuideList {
  final String title;
  final List<String> items;
  const GuideList({required this.title, required this.items});
}

/// Localized text of one manasik step.
class GuideStepText {
  final String title;
  final String place;
  final String description;

  /// The sunnah acts at this step, in order. Empty when the step has none.
  final List<String> sunnah;

  /// A short note. Use it where the schools of law differ, or where a ruling
  /// needs a qualifier that does not fit the description.
  final String? note;

  /// The supplication for this step, named and explained. The Arabic text is
  /// deliberately absent: a mistyped sacred formula is worse than none, and
  /// the reader takes the wording from a printed manasik guide.
  final String? dua;

  const GuideStepText({
    required this.title,
    required this.place,
    required this.description,
    this.sunnah = const [],
    this.note,
    this.dua,
  });
}

/// Localized text of one manasik section.
class GuideSectionText {
  final String title;
  final String intro;

  /// Reference lists for the section: pillars, obligations, sunnah, and so on.
  final List<GuideList> lists;

  const GuideSectionText({
    required this.title,
    required this.intro,
    this.lists = const [],
  });
}

class GuideStep {
  final int order;
  final Map<String, GuideStepText> texts;
  const GuideStep({required this.order, required this.texts});

  GuideStepText textFor(String languageCode) =>
      localizedValue(texts, languageCode);
}

class GuideSection {
  final Map<String, GuideSectionText> texts;
  final List<GuideStep> steps;
  const GuideSection({required this.texts, required this.steps});

  GuideSectionText textFor(String languageCode) =>
      localizedValue(texts, languageCode);
}

// Manasik summary following the Indonesian mainstream. For practice, follow the
// guidance of a KBIHU or the Ministry of Religious Affairs.
//
// The English text is a plain-language rendering of the Indonesian original.
// The sequence, the place names, and the rulings are unchanged. The Arabic text
// of the supplications is not reproduced here.
const List<GuideSection> hajjUmrahGuides = [
  GuideSection(
    texts: {
      'id': GuideSectionText(
        title: 'Haji',
        intro:
            'Rukun Islam kelima. Wajib sekali seumur hidup bagi yang mampu, dan hanya pada waktu yang telah ditetapkan. Pelaksanaannya berurutan: ihram pada bulan haji, wukuf di Arafah, lalu rangkaian mabit, melempar jumrah, dan tawaf.',
        lists: [
          GuideList(
            title: 'Rukun haji',
            items: [
              'Ihram, yaitu niat masuk ke dalam ibadah haji.',
              'Wukuf di Arafah pada 9 Zulhijah.',
              'Tawaf ifadhah, tujuh putaran mengelilingi Kakbah.',
              'Sai, tujuh kali antara Safa dan Marwah.',
              'Tahalul, memotong rambut.',
              'Tertib, yaitu berurutan sesuai urutan di atas.',
            ],
          ),
          GuideList(
            title: 'Wajib haji',
            items: [
              'Ihram dari miqat, tidak melewatinya tanpa ihram.',
              'Mabit di Muzdalifah pada malam 10 Zulhijah.',
              'Mabit di Mina pada hari tasyrik.',
              'Melempar tiga jumrah pada waktunya.',
              'Tawaf wada sebelum meninggalkan Makkah.',
              'Menjauhi larangan ihram.',
            ],
          ),
          GuideList(
            title: 'Sunah haji',
            items: [
              'Mandi dan bersuci sebelum memakai ihram.',
              'Memotong kuku dan merapikan rambut sebelum ihram.',
              'Memakai wangi-wangian pada badan sebelum niat, bukan pada kain ihram.',
              'Salat dua rakaat sebelum niat ihram.',
              'Membaca talbiyah sejak ihram sampai mulai melempar jumrah aqabah.',
              'Tawaf qudum saat pertama kali tiba di Masjidil Haram.',
              'Mabit di Mina pada 8 Zulhijah, hari tarwiyah.',
              'Berjalan menuju Arafah setelah matahari terbit pada 9 Zulhijah.',
              'Memperbanyak doa, zikir, dan membaca Al-Quran saat wukuf.',
              'Bertakbir pada setiap lemparan jumrah.',
              'Menginap di Mina pada malam 10 Zulhijah bagi yang tidak ke Muzdalifah.',
              'Tawaf sunah dan salat di Masjidil Haram selama di Makkah.',
            ],
          ),
          GuideList(
            title: 'Larangan ihram',
            items: [
              'Memotong rambut atau kuku.',
              'Memakai wangi-wangian pada badan atau pakaian.',
              'Bersetubuh dan segala pendahuluannya.',
              'Menikah atau menikahkan orang lain.',
              'Berburu atau membunuh binatang darat yang halal dimakan.',
              'Menebang atau mencabut tanaman di tanah haram.',
              'Bagi laki-laki: memakai pakaian berjahit yang membentuk badan, dan menutup kepala.',
              'Bagi perempuan: menutup wajah dan memakai sarung tangan.',
            ],
          ),
          GuideList(
            title: 'Jenis dam',
            items: [
              'Dam tamattu dan qiran: seekor kambing, atau sepertujuh sapi, atau sepertujuh unta.',
              'Bila tidak mampu: puasa tiga hari di tanah haram dan tujuh hari setelah kembali.',
              'Dam karena meninggalkan wajib haji: seekor kambing.',
              'Dam karena melanggar larangan ihram: seekor kambing, atau puasa tiga hari, atau sedekah makanan senilai kambing.',
              'Dam karena berburu binatang darat: dinilai oleh dua orang adil, sepadan dengan hewan yang dibunuh.',
              'Dam karena bersetubuh sebelum tahalul: seekor unta, dan hajinya tetap dilanjutkan lalu diulang pada tahun berikutnya.',
            ],
          ),
          GuideList(
            title: 'Kesalahan yang sering terjadi',
            items: [
              'Melewati miqat tanpa ihram, lalu baru berniat di Jeddah.',
              'Menganggap wukuf harus sampai malam, padahal cukup sampai terbenam matahari.',
              'Meninggalkan mabit di Mina tanpa uzur.',
              'Melempar jumrah dengan sandal atau barang, bukan batu.',
              'Berdesakan hingga membahayakan orang lain saat melempar.',
              'Melakukan tawaf ifadhah sebelum tahalul.',
              'Meninggalkan tawaf wada karena tergesa-gesa ke bandara.',
              'Menganggap sunah sebagai rukun, sehingga ibadah terasa batal padahal tidak.',
            ],
          ),
        ],
      ),
      'en': GuideSectionText(
        title: 'Hajj',
        intro:
            'The fifth pillar of Islam. Obligatory once in a lifetime for those who are able, and only at the appointed time. The rites follow in order: ihram in the months of Hajj, standing at Arafah, then the nights at Mina, the stoning, and the tawaf.',
        lists: [
          GuideList(
            title: 'Pillars of Hajj',
            items: [
              'Ihram, that is the intention to enter the Hajj rites.',
              'Standing at Arafah on 9 Dhul-Hijjah.',
              'Tawaf al-ifadah, seven circuits around the Kaaba.',
              'Sa\'i, seven times between Safa and Marwah.',
              'Tahallul, cutting the hair.',
              'Observing the proper order of the rites above.',
            ],
          ),
          GuideList(
            title: 'Obligations of Hajj',
            items: [
              'Ihram from the miqat. Do not pass it without ihram.',
              'The night at Muzdalifah, on the night of 10 Dhul-Hijjah.',
              'The nights at Mina during the days of tashriq.',
              'Stoning the three jamrahs at the proper time.',
              'The farewell tawaf before leaving Makkah.',
              'Keeping clear of the prohibitions of ihram.',
            ],
          ),
          GuideList(
            title: 'Sunnah of Hajj',
            items: [
              'Bathe and cleanse before putting on the ihram garments.',
              'Cut the nails and tidy the hair before ihram.',
              'Apply perfume to the body before the intention, not to the ihram cloth.',
              'Pray two rak\'ah before the intention for ihram.',
              'Recite the talbiyah from ihram until the stoning of Jamrat al-Aqabah begins.',
              'Perform tawaf al-qudum on first arrival at Masjid al-Haram.',
              'Stay at Mina on 8 Dhul-Hijjah, the day of tarwiyah.',
              'Set out for Arafah after sunrise on 9 Dhul-Hijjah.',
              'Increase in supplication, remembrance, and recitation while at Arafah.',
              'Say the takbir at each stoning.',
              'Spend the night of 10 Dhul-Hijjah at Mina if you do not stay at Muzdalifah.',
              'Perform voluntary tawaf and pray in Masjid al-Haram while in Makkah.',
            ],
          ),
          GuideList(
            title: 'Prohibitions of ihram',
            items: [
              'Cutting the hair or the nails.',
              'Applying perfume to the body or the clothing.',
              'Sexual intercourse and everything that leads to it.',
              'Marrying, or marrying others to each other.',
              'Hunting, or killing land game that is lawful to eat.',
              'Cutting or uprooting plants inside the sacred area.',
              'For men: wearing stitched clothing that shapes the body, and covering the head.',
              'For women: covering the face and wearing gloves.',
            ],
          ),
          GuideList(
            title: 'Types of dam',
            items: [
              'The dam for tamattu and qiran: one sheep, or one seventh of a cow, or one seventh of a camel.',
              'If unable: fast three days in the sacred area and seven after returning home.',
              'The dam for leaving an obligation of Hajj: one sheep.',
              'The dam for breaking a prohibition of ihram: one sheep, or three days of fasting, or food charity equal to a sheep.',
              'The dam for hunting land game: valued by two just persons, equal to the animal killed.',
              'The dam for intercourse before tahallul: one camel. The Hajj continues, and the pilgrim repeats it the following year.',
            ],
          ),
          GuideList(
            title: 'Common mistakes',
            items: [
              'Passing the miqat without ihram, then making the intention at Jeddah.',
              'Thinking the stay at Arafah must last into the night, when sunset is enough.',
              'Leaving the nights at Mina without a valid excuse.',
              'Stoning with a sandal or another object instead of a pebble.',
              'Crowding so hard that others are put in danger during the stoning.',
              'Performing tawaf al-ifadah before tahallul.',
              'Skipping the farewell tawaf because of a rush to the airport.',
              'Treating a sunnah as a pillar, so the pilgrimage feels invalid when it is not.',
            ],
          ),
        ],
      ),
    },
    steps: [
      GuideStep(
        order: 1,
        texts: {
          'id': GuideStepText(
            title: 'Ihram',
            place: 'Miqat, bulan haji',
            description:
                'Niat masuk ke dalam ibadah haji, dilakukan di miqat. Bagi yang datang dari Indonesia, miqat dimulai saat pesawat sejajar dengan titik miqat, biasanya diumumkan kru.',
            sunnah: [
              'Mandi, berwudu, dan memotong kuku sebelum memakai ihram.',
              'Memakai wangi-wangian pada badan sebelum niat, bukan pada kain ihram.',
              'Salat dua rakaat, lalu berniat.',
              'Membaca talbiyah dengan suara jelas bagi laki-laki, dan pelan bagi perempuan.',
            ],
            dua:
                'Talbiyah. Dibaca terus sejak niat sampai mulai melempar jumrah aqabah.',
          ),
          'en': GuideStepText(
            title: 'Ihram',
            place: 'The miqat, in the months of Hajj',
            description:
                'The intention to enter the Hajj rites, made at the miqat. Pilgrims arriving from Indonesia reach the miqat in the air, and the crew usually announces it.',
            sunnah: [
              'Bathe, perform ablution, and cut the nails before putting on the ihram.',
              'Apply perfume to the body before the intention, not to the ihram cloth.',
              'Pray two rak\'ah, then make the intention.',
              'Recite the talbiyah aloud for men, and quietly for women.',
            ],
            dua:
                'The talbiyah. Recite it from the intention until the stoning of Jamrat al-Aqabah begins.',
          ),
        },
      ),
      GuideStep(
        order: 2,
        texts: {
          'id': GuideStepText(
            title: 'Tarwiyah',
            place: 'Mina, 8 Zulhijah',
            description:
                'Bergerak ke Mina dan bermalam di sana. Salat lima waktu dikerjakan dengan qasar, tanpa jamak.',
            sunnah: [
              'Berangkat ke Mina pada pagi hari 8 Zulhijah.',
              'Bermalam di Mina, karena ini sunah yang ditinggalkan Nabi.',
              'Memperbanyak talbiyah, zikir, dan membaca Al-Quran.',
            ],
            note:
                'Mabit di Mina pada malam 10 Zulhijah hukumnya wajib, sedangkan malam 8 Zulhijah hanya sunah.',
          ),
          'en': GuideStepText(
            title: 'Tarwiyah',
            place: 'Mina, 8 Dhul-Hijjah',
            description:
                'Move to Mina and spend the night there. Pray the five prayers shortened, but not combined.',
            sunnah: [
              'Set out for Mina on the morning of 8 Dhul-Hijjah.',
              'Spend the night at Mina, a sunnah the Prophet kept.',
              'Increase in the talbiyah, remembrance, and recitation.',
            ],
            note:
                'The night at Mina before 10 Dhul-Hijjah is obligatory. The night of 8 Dhul-Hijjah is only a sunnah.',
          ),
        },
      ),
      GuideStep(
        order: 3,
        texts: {
          'id': GuideStepText(
            title: 'Wukuf',
            place: 'Arafah, 9 Zulhijah',
            description:
                'Puncak haji. Berada di Arafah sejak matahari tergelincir sampai terbenam. Tanpa wukuf, haji tidak sah dan tidak bisa diganti dengan dam.',
            sunnah: [
              'Mendengarkan khutbah Arafah sebelum salat jamak.',
              'Salat Zuhur dan Asar dijamak takdim dengan qasar.',
              'Menghadap kiblat dan memperbanyak doa sampai matahari terbenam.',
              'Tidak berpuasa bagi jamaah haji, karena Nabi tidak berpuasa pada hari Arafah saat wukuf.',
            ],
            dua:
                'Doa hari Arafah. Dipanjatkan dari tergelincir matahari sampai terbenam.',
            note:
                'Sebagian ulama menyatakan wukuf cukup dengan hadir walau sejenak di area Arafah. Ikuti jadwal rombongan Anda, dan jangan meninggalkan Arafah sebelum matahari terbenam.',
          ),
          'en': GuideStepText(
            title: 'Standing at Arafah',
            place: 'Arafah, 9 Dhul-Hijjah',
            description:
                'The peak of Hajj. Remain at Arafah from just after midday until sunset. Without it the Hajj is invalid, and no dam can replace it.',
            sunnah: [
              'Listen to the Arafah sermon before the combined prayer.',
              'Pray Dhuhr and Asr combined at Dhuhr time, shortened.',
              'Face the qiblah and increase in supplication until sunset.',
              'Do not fast, for the Prophet did not fast on the day of Arafah while standing there.',
            ],
            dua:
                'The supplication of the day of Arafah, from just after midday until sunset.',
            note:
                'Some scholars hold that a brief presence inside the Arafah area is enough. Follow your group schedule, and do not leave Arafah before sunset.',
          ),
        },
      ),
      GuideStep(
        order: 4,
        texts: {
          'id': GuideStepText(
            title: 'Mabit Muzdalifah',
            place: 'Muzdalifah, malam 10 Zulhijah',
            description:
                'Bergerak dari Arafah setelah terbenam, lalu bermalam di Muzdalifah. Salat Magrib dan Isya dijamak takhir.',
            sunnah: [
              'Berangkat dari Arafah dengan tenang, tanpa berdesakan.',
              'Salat Magrib dan Isya dijamak takhir sesampai di Muzdalifah.',
              'Mengambil kerikil untuk melempar jumrah.',
              'Bermalam sampai terbit fajar, lalu salat Subuh di Muzdalifah.',
            ],
            note:
                'Mabit di Muzdalifah wajib. Bagi yang lemah, seperti lansia atau perempuan, sebagian ulama memberi keringanan berangkat ke Mina lebih awal.',
          ),
          'en': GuideStepText(
            title: 'The night at Muzdalifah',
            place: 'Muzdalifah, the night of 10 Dhul-Hijjah',
            description:
                'Leave Arafah after sunset and spend the night at Muzdalifah. Pray Maghrib and Isha combined at Isha time.',
            sunnah: [
              'Leave Arafah calmly, without pushing.',
              'Pray Maghrib and Isha combined at Isha time on arrival.',
              'Collect pebbles for the stoning.',
              'Stay until dawn, then pray Fajr at Muzdalifah.',
            ],
            note:
                'The night at Muzdalifah is obligatory. For the weak, such as the elderly or women, some scholars permit leaving for Mina earlier.',
          ),
        },
      ),
      GuideStep(
        order: 5,
        texts: {
          'id': GuideStepText(
            title: 'Jumrah Aqabah dan tahalul awal',
            place: 'Mina, 10 Zulhijah',
            description:
                'Melempar tujuh kerikil ke jumrah aqabah, lalu menyembelih hadyu bagi haji tamattu dan qiran, kemudian tahalul awal dengan memotong rambut.',
            sunnah: [
              'Berhenti membaca talbiyah saat mulai melempar.',
              'Bertakbir pada setiap lemparan.',
              'Melempar dengan kerikil sebesar kacang, bukan dengan sandal atau barang.',
              'Memotong rambut, dan bagi laki-laki lebih utama dicukur habis.',
              'Menyembelih hadyu setelah melempar, lalu makan sebagian dagingnya.',
            ],
            note:
                'Setelah tahalul awal, semua larangan ihram menjadi halal kembali kecuali bersetubuh. Bersih dari hadas tidak menjadi syarat sah melempar menurut jumhur.',
          ),
          'en': GuideStepText(
            title: 'Jamrat al-Aqabah and the first tahallul',
            place: 'Mina, 10 Dhul-Hijjah',
            description:
                'Throw seven pebbles at Jamrat al-Aqabah, then slaughter the hadyu for tamattu and qiran pilgrims, then perform the first tahallul by cutting the hair.',
            sunnah: [
              'Stop the talbiyah when the stoning begins.',
              'Say the takbir at each throw.',
              'Throw pebbles the size of a bean, not a sandal or another object.',
              'Cut the hair. For men, shaving it off is better.',
              'Slaughter the hadyu after the stoning, and eat part of the meat.',
            ],
            note:
                'After the first tahallul every prohibition of ihram becomes lawful again except intercourse. Most scholars do not make ritual purity a condition for a valid stoning.',
          ),
        },
      ),
      GuideStep(
        order: 6,
        texts: {
          'id': GuideStepText(
            title: 'Mabit Mina dan melempar tiga jumrah',
            place: 'Mina, 11 sampai 13 Zulhijah',
            description:
                'Bermalam di Mina pada hari tasyrik, dan setiap hari melempar tiga jumrah: ula, wusta, lalu aqabah, masing-masing tujuh kerikil.',
            sunnah: [
              'Melempar setelah matahari tergelincir.',
              'Berdoa setelah jumrah ula dan jumrah wusta.',
              'Tidak berdoa setelah jumrah aqabah.',
              'Mabit pada malam 11 dan 12 bagi yang mengambil nafar awal.',
            ],
            note:
                'Nafar awal berarti meninggalkan Mina pada 12 Zulhijah setelah melempar, dan itu dibolehkan. Nafar tsani berarti tinggal sampai 13 Zulhijah, dan itu lebih utama.',
          ),
          'en': GuideStepText(
            title: 'The nights at Mina and the three stonings',
            place: 'Mina, 11 to 13 Dhul-Hijjah',
            description:
                'Spend the nights at Mina during the days of tashriq. Each day, stone the three jamrahs: ula, wusta, then aqabah, seven pebbles each.',
            sunnah: [
              'Stone after midday.',
              'Make supplication after the ula and wusta stonings.',
              'Make no supplication after the aqabah stoning.',
              'Stay the nights of 11 and 12 for the earlier departure.',
            ],
            note:
                'The earlier departure means leaving Mina on 12 Dhul-Hijjah after the stoning, and it is permitted. The later departure means staying until 13 Dhul-Hijjah, and it is better.',
          ),
        },
      ),
      GuideStep(
        order: 7,
        texts: {
          'id': GuideStepText(
            title: 'Tawaf ifadhah dan sai',
            place: 'Masjidil Haram',
            description:
                'Tawaf tujuh putaran mengelilingi Kakbah sebagai rukun haji, lalu sai tujuh kali antara Safa dan Marwah bila belum melakukannya.',
            sunnah: [
              'Tawaf dalam keadaan bersuci.',
              'Mencium Hajar Aswad bila memungkinkan, atau memberi isyarat dari jauh.',
              'Laki-laki: idhtiba, yaitu meletakkan kain ihram di bawah ketiak kanan, dan berlari kecil pada tiga putaran pertama.',
              'Berdoa di antara Rukun Yamani dan Hajar Aswad.',
              'Salat dua rakaat setelah tawaf di dekat Makam Ibrahim bila memungkinkan.',
            ],
            dua:
                'Doa antara Rukun Yamani dan Hajar Aswad, dan doa di Safa serta Marwah.',
            note:
                'Wudu saat tawaf menurut jumhur adalah syarat sah, sehingga tawaf tanpa wudu harus diulang. Idhtiba dan ramal hanya untuk laki-laki.',
          ),
          'en': GuideStepText(
            title: 'Tawaf al-ifadah and sa\'i',
            place: 'Masjid al-Haram',
            description:
                'Seven circuits around the Kaaba as a pillar of Hajj, then seven times between Safa and Marwah if you have not yet performed sa\'i.',
            sunnah: [
              'Perform the tawaf in a state of ritual purity.',
              'Kiss the Black Stone if you can reach it, or point to it from a distance.',
              'For men: idhtiba, the ihram cloth under the right armpit, and a brisk pace on the first three circuits.',
              'Make supplication between the Yemeni Corner and the Black Stone.',
              'Pray two rak\'ah after the tawaf near the Station of Ibrahim if you can.',
            ],
            dua:
                'The supplication between the Yemeni Corner and the Black Stone, and at Safa and Marwah.',
            note:
                'Most scholars make ablution a condition for a valid tawaf, so a tawaf without it must be repeated. Idhtiba and the brisk pace apply to men only.',
          ),
        },
      ),
      GuideStep(
        order: 8,
        texts: {
          'id': GuideStepText(
            title: 'Tawaf wada',
            place: 'Masjidil Haram',
            description:
                'Tawaf perpisahan sebelum meninggalkan Makkah, dan tidak berlama-lama di Makkah setelahnya.',
            sunnah: [
              'Melakukan tawaf wada setelah semua urusan selesai.',
              'Langsung menuju perjalanan pulang setelah tawaf.',
            ],
            note:
                'Mazhab Syafii, Maliki, dan Hambali menyatakan tawaf wada wajib, dan yang meninggalkannya terkena dam. Mazhab Hanafi menyatakannya sunah. Wanita yang sedang haid atau nifas dibebaskan.',
          ),
          'en': GuideStepText(
            title: 'The farewell tawaf',
            place: 'Masjid al-Haram',
            description:
                'The farewell tawaf before leaving Makkah, with no long stay in Makkah afterwards.',
            sunnah: [
              'Perform it after all other business is finished.',
              'Head for the journey home directly after the tawaf.',
            ],
            note:
                'The Shafi\'i, Maliki, and Hanbali schools hold the farewell tawaf obligatory, and the one who leaves it owes a dam. The Hanafi school holds it a sunnah. A woman menstruating or in post-natal bleeding is excused.',
          ),
        },
      ),
    ],
  ),
  GuideSection(
    texts: {
      'id': GuideSectionText(
        title: 'Umrah',
        intro:
            'Dapat dikerjakan kapan saja sepanjang tahun. Rangkaiannya lebih pendek daripada haji, yaitu ihram, tawaf, sai, dan tahalul.',
        lists: [
          GuideList(
            title: 'Rukun umrah',
            items: [
              'Ihram, yaitu niat masuk ke dalam ibadah umrah.',
              'Tawaf, tujuh putaran mengelilingi Kakbah.',
              'Sai, tujuh kali antara Safa dan Marwah.',
              'Tahalul, memotong rambut.',
              'Tertib, yaitu berurutan sesuai urutan di atas.',
            ],
          ),
          GuideList(
            title: 'Wajib umrah',
            items: [
              'Ihram dari miqat, tidak melewatinya tanpa ihram.',
              'Menjauhi larangan ihram.',
            ],
          ),
          GuideList(
            title: 'Sunah umrah',
            items: [
              'Mandi dan bersuci sebelum memakai ihram.',
              'Memakai wangi-wangian pada badan sebelum niat.',
              'Salat dua rakaat sebelum niat ihram.',
              'Membaca talbiyah sejak niat sampai mulai tawaf.',
              'Idhtiba dan berlari kecil pada tiga putaran pertama tawaf bagi laki-laki.',
              'Mencium Hajar Aswad bila memungkinkan.',
              'Berdoa di Safa dan Marwah.',
              'Mencukur habis rambut bagi laki-laki.',
            ],
          ),
          GuideList(
            title: 'Larangan ihram',
            items: [
              'Memotong rambut atau kuku.',
              'Memakai wangi-wangian pada badan atau pakaian.',
              'Bersetubuh dan segala pendahuluannya.',
              'Menikah atau menikahkan orang lain.',
              'Berburu atau membunuh binatang darat yang halal dimakan.',
              'Menebang atau mencabut tanaman di tanah haram.',
              'Bagi laki-laki: memakai pakaian berjahit yang membentuk badan, dan menutup kepala.',
              'Bagi perempuan: menutup wajah dan memakai sarung tangan.',
            ],
          ),
          GuideList(
            title: 'Dam umrah',
            items: [
              'Umrah wajib dikerjakan dengan ihram dari miqat. Melewatinya tanpa ihram menuntut dam.',
              'Melanggar larangan ihram menuntut dam, atau puasa tiga hari, atau sedekah makanan.',
              'Haji tamattu, yaitu haji yang disertai umrah dalam satu perjalanan, menuntut hadyu.',
            ],
          ),
          GuideList(
            title: 'Kesalahan yang sering terjadi',
            items: [
              'Berniat umrah dari Jeddah, padahal sudah melewati miqat.',
              'Menganggap sai harus diulang bila berhenti di tengah.',
              'Menganggap potong rambut harus di Makkah, padahal sah dikerjakan di mana saja setelah tahalul.',
              'Melakukan tawaf tanpa wudu lalu tidak mengulanginya.',
              'Berdesakan untuk mencium Hajar Aswad sampai mengganggu jamaah lain.',
            ],
          ),
        ],
      ),
      'en': GuideSectionText(
        title: 'Umrah',
        intro:
            'May be performed at any time of the year. It is shorter than the Hajj: ihram, tawaf, sa\'i, and tahallul.',
        lists: [
          GuideList(
            title: 'Pillars of Umrah',
            items: [
              'Ihram, that is the intention to enter the Umrah rites.',
              'Tawaf, seven circuits around the Kaaba.',
              'Sa\'i, seven times between Safa and Marwah.',
              'Tahallul, cutting the hair.',
              'Observing the proper order of the rites above.',
            ],
          ),
          GuideList(
            title: 'Obligations of Umrah',
            items: [
              'Ihram from the miqat. Do not pass it without ihram.',
              'Keeping clear of the prohibitions of ihram.',
            ],
          ),
          GuideList(
            title: 'Sunnah of Umrah',
            items: [
              'Bathe and cleanse before putting on the ihram.',
              'Apply perfume to the body before the intention.',
              'Pray two rak\'ah before the intention for ihram.',
              'Recite the talbiyah from the intention until the tawaf begins.',
              'Idhtiba and a brisk pace on the first three circuits, for men.',
              'Kiss the Black Stone if you can reach it.',
              'Make supplication at Safa and Marwah.',
              'Shave the hair off, for men.',
            ],
          ),
          GuideList(
            title: 'Prohibitions of ihram',
            items: [
              'Cutting the hair or the nails.',
              'Applying perfume to the body or the clothing.',
              'Sexual intercourse and everything that leads to it.',
              'Marrying, or marrying others to each other.',
              'Hunting, or killing land game that is lawful to eat.',
              'Cutting or uprooting plants inside the sacred area.',
              'For men: wearing stitched clothing that shapes the body, and covering the head.',
              'For women: covering the face and wearing gloves.',
            ],
          ),
          GuideList(
            title: 'Dam for Umrah',
            items: [
              'The Umrah requires ihram from the miqat. Passing the miqat without ihram owes a dam.',
              'Breaking a prohibition of ihram owes a dam, or three days of fasting, or food charity.',
              'The tamattu Hajj, which combines the Umrah and the Hajj in one journey, requires a hadyu.',
            ],
          ),
          GuideList(
            title: 'Common mistakes',
            items: [
              'Making the intention for Umrah at Jeddah after passing the miqat.',
              'Thinking that sa\'i must be restarted after a pause in the middle.',
              'Thinking the hair must be cut in Makkah, when it is valid anywhere after tahallul.',
              'Performing a tawaf without ablution and not repeating it.',
              'Crowding to kiss the Black Stone and disturbing other pilgrims.',
            ],
          ),
        ],
      ),
    },
    steps: [
      GuideStep(
        order: 1,
        texts: {
          'id': GuideStepText(
            title: 'Ihram',
            place: 'Miqat',
            description:
                'Niat umrah di miqat. Bagi yang datang dari Indonesia, miqat dilewati di udara atau di bandara transit seperti Jeddah bagi yang berniat dari sana.',
            sunnah: [
              'Mandi, berwudu, dan memotong kuku sebelum memakai ihram.',
              'Memakai wangi-wangian pada badan sebelum niat.',
              'Salat dua rakaat, lalu berniat.',
              'Membaca talbiyah sampai mulai tawaf.',
            ],
            dua:
                'Talbiyah. Dibaca sejak niat sampai mulai tawaf.',
            note:
                'Miqat bagi jamaah dari Indonesia umumnya Yalamlam, dan bagi yang sudah di Jeddah dapat mengambil ihram dari Ji\'ranah atau Tan\'im.',
          ),
          'en': GuideStepText(
            title: 'Ihram',
            place: 'The miqat',
            description:
                'The intention for Umrah at the miqat. Pilgrims from Indonesia pass the miqat in the air, or at a transit airport such as Jeddah for those who intend from there.',
            sunnah: [
              'Bathe, perform ablution, and cut the nails before putting on the ihram.',
              'Apply perfume to the body before the intention.',
              'Pray two rak\'ah, then make the intention.',
              'Recite the talbiyah until the tawaf begins.',
            ],
            dua: 'The talbiyah, from the intention until the tawaf begins.',
            note:
                'Pilgrims from Indonesia usually take the miqat at Yalamlam. Those already in Jeddah may enter ihram at Ji\'ranah or Tan\'im.',
          ),
        },
      ),
      GuideStep(
        order: 2,
        texts: {
          'id': GuideStepText(
            title: 'Tawaf',
            place: 'Masjidil Haram',
            description:
                'Tujuh putaran mengelilingi Kakbah berlawanan arah jarum jam, dimulai dan diakhiri di Hajar Aswad.',
            sunnah: [
              'Tawaf dalam keadaan bersuci.',
              'Laki-laki: idhtiba, lalu berlari kecil pada tiga putaran pertama.',
              'Mencium Hajar Aswad bila memungkinkan, atau memberi isyarat.',
              'Berdoa di antara Rukun Yamani dan Hajar Aswad.',
              'Salat dua rakaat setelah tawaf.',
            ],
            dua:
                'Doa antara Rukun Yamani dan Hajar Aswad.',
            note:
                'Tawaf berhenti pada putaran tujuh di Hajar Aswad. Bila ragu jumlahnya, ambil yang lebih sedikit, lalu lanjutkan sampai yakin tujuh.',
          ),
          'en': GuideStepText(
            title: 'Tawaf',
            place: 'Masjid al-Haram',
            description:
                'Seven circuits around the Kaaba anticlockwise, beginning and ending at the Black Stone.',
            sunnah: [
              'Perform the tawaf in a state of ritual purity.',
              'For men: idhtiba, then a brisk pace on the first three circuits.',
              'Kiss the Black Stone if you can reach it, or point to it.',
              'Make supplication between the Yemeni Corner and the Black Stone.',
              'Pray two rak\'ah after the tawaf.',
            ],
            dua:
                'The supplication between the Yemeni Corner and the Black Stone.',
            note:
                'The tawaf ends at the Black Stone on the seventh circuit. If you lose count, take the lower number and continue until you are sure of seven.',
          ),
        },
      ),
      GuideStep(
        order: 3,
        texts: {
          'id': GuideStepText(
            title: 'Sai',
            place: 'Safa dan Marwah',
            description:
                'Berjalan tujuh kali antara Safa dan Marwah, dimulai dari Safa dan berakhir di Marwah. Perjalanan Safa ke Marwah dihitung satu, dan sebaliknya satu.',
            sunnah: [
              'Menaiki bukit Safa, lalu menghadap kiblat dan berdoa.',
              'Membaca talbiyah di awal sai.',
              'Berlari kecil antara dua tanda hijau, bagi laki-laki.',
              'Berdoa di Marwah pada setiap putaran.',
              'Bersuci, meskipun sai tetap sah tanpa wudu.',
            ],
            dua:
                'Doa di Safa dan Marwah, termasuk doa memohon ampunan dan rezeki.',
            note:
                'Keluar sedikit dari area Safa dan Marwah termasuk bagian dari sai. Yang berjalan di lantai atas tetap sah.',
          ),
          'en': GuideStepText(
            title: 'Sa\'i',
            place: 'Safa and Marwah',
            description:
                'Walk seven times between Safa and Marwah, beginning at Safa and ending at Marwah. Safa to Marwah counts as one, and the return counts as one.',
            sunnah: [
              'Climb Safa, face the qiblah, and make supplication.',
              'Recite the talbiyah at the start of sa\'i.',
              'Run briskly between the two green markers, for men.',
              'Make supplication at Marwah on each lap.',
              'Perform it in a state of purity, though sa\'i is valid without ablution.',
            ],
            dua:
                'The supplication at Safa and Marwah, asking forgiveness and provision.',
            note:
                'Stepping slightly beyond the Safa and Marwah area still counts as part of the sa\'i. Walking on the upper level is valid.',
          ),
        },
      ),
      GuideStep(
        order: 4,
        texts: {
          'id': GuideStepText(
            title: 'Tahalul',
            place: 'Makkah atau di luar Makkah',
            description:
                'Memotong rambut sebagai penutup umrah. Setelah itu semua larangan ihram kembali halal.',
            sunnah: [
              'Mencukur habis bagi laki-laki, dan itu lebih utama.',
              'Memotong sepanjang ujung jari bagi perempuan.',
              'Memulai potongan dari sisi kanan.',
            ],
            note:
                'Tahalul tidak harus dikerjakan di Makkah. Selesai memotong rambut, umrah selesai dan ihram berakhir.',
          ),
          'en': GuideStepText(
            title: 'Tahallul',
            place: 'Makkah, or anywhere outside it',
            description:
                'Cut the hair to close the Umrah. Every prohibition of ihram becomes lawful after it.',
            sunnah: [
              'Shave the hair off, for men, which is better.',
              'Cut about a fingertip\'s length, for women.',
              'Begin cutting on the right side.',
            ],
            note:
                'The tahallul need not be performed inside Makkah. Once the hair is cut, the Umrah is complete and the ihram ends.',
          ),
        },
      ),
    ],
  ),
];
