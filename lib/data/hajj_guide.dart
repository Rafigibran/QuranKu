import '../utils/localized.dart';

/// Localized text of one manasik step.
class GuideStepText {
  final String title;
  final String place;
  final String description;
  const GuideStepText({
    required this.title,
    required this.place,
    required this.description,
  });
}

/// Localized text of one manasik section.
class GuideSectionText {
  final String title;
  final String intro;
  const GuideSectionText({required this.title, required this.intro});
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

// Ringkasan umum manasik. Untuk praktik, ikuti bimbingan KBIHU / Kemenag.
//
// The English text is a plain-language rendering of the Indonesian original;
// the sequence and place names are unchanged.
const List<GuideSection> hajjUmrahGuides = [
  GuideSection(
    texts: {
      'id': GuideSectionText(
        title: 'Haji',
        intro:
            'Rukun Islam kelima, wajib sekali seumur hidup bagi yang mampu. Rukun haji: ihram, wukuf di Arafah, tawaf ifadhah, sai, tahalul, dan tertib.',
      ),
      'en': GuideSectionText(
        title: 'Hajj',
        intro:
            'The fifth pillar of Islam, obligatory once in a lifetime for those who are able. Its pillars are ihram, standing at Arafah, tawaf al-ifadah, sa\'i, tahallul, and observing the proper order.',
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
                'Niat haji dari miqat, memakai kain ihram (laki-laki), membaca talbiyah, menjauhi larangan ihram.',
          ),
          'en': GuideStepText(
            title: 'Ihram',
            place: 'Miqat',
            description:
                'Make the intention for Hajj at the miqat, wear the ihram garments (for men), recite the talbiyah, and avoid the prohibitions of ihram.',
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
                'Bermalam di Mina pada 8 Zulhijah (sunah), salat lima waktu dengan qasar tanpa jamak.',
          ),
          'en': GuideStepText(
            title: 'Tarwiyah',
            place: 'Mina, 8 Dhul-Hijjah',
            description:
                'Spend the night at Mina on 8 Dhul-Hijjah (a sunnah), praying the five prayers shortened but not combined.',
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
                'Puncak haji. Berada di Arafah dari tergelincir matahari hingga terbenam, memperbanyak doa dan zikir.',
          ),
          'en': GuideStepText(
            title: 'Wukuf at Arafah',
            place: 'Arafah, 9 Dhul-Hijjah',
            description:
                'The peak of Hajj. Remain at Arafah from just after midday until sunset, increasing in supplication and remembrance.',
          ),
        },
      ),
      GuideStep(
        order: 4,
        texts: {
          'id': GuideStepText(
            title: 'Mabit Muzdalifah',
            place: 'Muzdalifah',
            description:
                'Bermalam di Muzdalifah setelah magrib, mengumpulkan kerikil untuk jumrah, salat magrib-isya jamak takhir.',
          ),
          'en': GuideStepText(
            title: 'Night at Muzdalifah',
            place: 'Muzdalifah',
            description:
                'Spend the night at Muzdalifah after maghrib, collect pebbles for the stoning, and pray maghrib and isha combined at isha time.',
          ),
        },
      ),
      GuideStep(
        order: 5,
        texts: {
          'id': GuideStepText(
            title: 'Jumrah Aqabah',
            place: 'Mina, 10 Zulhijah',
            description:
                'Melempar 7 kerikil ke jumrah aqabah, lalu qurban (bagi haji tamattu/qiran), tahalul awal, dan tawaf ifadhah.',
          ),
          'en': GuideStepText(
            title: 'Stoning Jamrat al-Aqabah',
            place: 'Mina, 10 Dhul-Hijjah',
            description:
                'Throw seven pebbles at Jamrat al-Aqabah, then offer the sacrifice (for tamattu and qiran pilgrims), perform the first tahallul, and tawaf al-ifadah.',
          ),
        },
      ),
      GuideStep(
        order: 6,
        texts: {
          'id': GuideStepText(
            title: 'Mabit Mina',
            place: 'Mina, 11-13 Zulhijah',
            description:
                'Bermalam di Mina pada hari tasyrik, melempar tiga jumrah (ula, wusta, aqabah) tiap hari. Nafar awal boleh pulang 12 Zulhijah.',
          ),
          'en': GuideStepText(
            title: 'Nights at Mina',
            place: 'Mina, 11-13 Dhul-Hijjah',
            description:
                'Spend the nights at Mina during the days of tashriq, stoning all three jamrahs (ula, wusta, aqabah) each day. Leaving on 12 Dhul-Hijjah is the earlier, permitted option.',
          ),
        },
      ),
      GuideStep(
        order: 7,
        texts: {
          'id': GuideStepText(
            title: 'Tawaf Ifadhah',
            place: 'Masjidil Haram',
            description:
                'Tawaf 7 putaran mengelilingi Kakbah sebagai rukun haji, dilanjutkan sai bila belum sai.',
          ),
          'en': GuideStepText(
            title: 'Tawaf al-Ifadah',
            place: 'Masjid al-Haram',
            description:
                'Seven circuits around the Kaaba as a pillar of Hajj, followed by sa\'i if it has not yet been performed.',
          ),
        },
      ),
      GuideStep(
        order: 8,
        texts: {
          'id': GuideStepText(
            title: 'Tawaf Wada',
            place: 'Masjidil Haram',
            description:
                'Tawaf perpisahan sebelum meninggalkan Makkah (wajib menurut jumhur, kecuali haid/nifas).',
          ),
          'en': GuideStepText(
            title: 'Farewell tawaf',
            place: 'Masjid al-Haram',
            description:
                'The farewell tawaf before leaving Makkah (obligatory according to the majority, except for menstruating or post-natal women).',
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
            'Dapat dikerjakan kapan saja. Rukun umrah: ihram, tawaf, sai, tahalul, dan tertib.',
      ),
      'en': GuideSectionText(
        title: 'Umrah',
        intro:
            'May be performed at any time. Its pillars are ihram, tawaf, sa\'i, tahallul, and observing the proper order.',
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
                'Niat umrah dari miqat (misal Tan\'im, Ji\'ranah, atau Yalamlam bagi dari Indonesia), membaca talbiyah.',
          ),
          'en': GuideStepText(
            title: 'Ihram',
            place: 'Miqat',
            description:
                'Make the intention for Umrah at the miqat (for example Tan\'im, Ji\'ranah, or Yalamlam for those arriving from Indonesia), and recite the talbiyah.',
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
                'Mengelilingi Kakbah 7 putaran berlawanan arah jarum jam, dimulai dari Hajar Aswad, dengan wudu.',
          ),
          'en': GuideStepText(
            title: 'Tawaf',
            place: 'Masjid al-Haram',
            description:
                'Seven circuits around the Kaaba anticlockwise, starting from the Black Stone, in a state of ablution.',
          ),
        },
      ),
      GuideStep(
        order: 3,
        texts: {
          'id': GuideStepText(
            title: 'Sai',
            place: 'Safa - Marwah',
            description:
                'Berjalan/berlari kecil 7 kali antara bukit Safa dan Marwah, dimulai dari Safa.',
          ),
          'en': GuideStepText(
            title: 'Sa\'i',
            place: 'Safa - Marwah',
            description:
                'Walk or jog seven times between the hills of Safa and Marwah, starting from Safa.',
          ),
        },
      ),
      GuideStep(
        order: 4,
        texts: {
          'id': GuideStepText(
            title: 'Tahalul',
            place: 'Makkah',
            description: 'Mencukur/memendekkan rambut sebagai tanda selesai umrah.',
          ),
          'en': GuideStepText(
            title: 'Tahallul',
            place: 'Makkah',
            description:
                'Shave or trim the hair to mark the completion of Umrah.',
          ),
        },
      ),
    ],
  ),
];
