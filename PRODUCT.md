# Product

<!-- impeccable:product-schema 1 -->

## Platform

adaptive

## Users

Practicing Indonesian Muslims integrating Quran reading and daily worship in one place. Core daily jobs: read 114 Surahs with translation, listen to continuous murotal with mini/full player, check prayer times and qibla. Extended jobs visible in code: khatam progress tracking, tasbih/dhikr, zakat calculation, hajj/umrah guide, daily duas, Asmaul Husna, Ramadan imsakiyah, playlist management, offline downloads and storage.

All ages, including older users who need large touch targets, readable Arabic/Latin type, and adjustable font scales. Indonesian-first; English translation available as secondary option.

Open: user selected "Refine audience" without specifics — if primary shifts (e.g. youth vs elders, learners vs hafiz, Indonesia-only vs global), update this section before surface strategy.

## Product Purpose

QuranKu is a calm, focused Quran companion for Android and iOS: read, listen, and keep daily worship on track without clutter. Success means a user can open daily, continue last-read in one tap, read or listen with accurate text/audio, and reach prayer, qibla, dhikr, or khatam tools in seconds — online or offline.

## Positioning

Indonesian-first accuracy stance: no guessed per-word translation (removed for Quran accuracy), opt-in tajwid coloring, Kemenag-style transliteration default, continuous ayah-by-ayah audio progression with persistent player, per-ayah read tracking tied to khatam, and full offline caching for text and murotal. A neighboring app could copy features; it could not truthfully copy this accuracy + offline + older-inclusive simplicity combination.

## Operating Context

Daily use at home, mosque, and travel; low-light reading (dark theme is current default in SettingsService); intermittent network (offline cache required); prayer-time use with GPS, notifications, and adhan audio; audio use with background playback, separate Quran/ambient volumes, and rain ambient option. Workflows: search surah by name/number/Arabic, jump to ayah, bookmark, mark read, resume last-read, build playlists, download for offline, manage storage.

## Capabilities and Constraints

Confirmed functionality: 114 Surahs Arabic + Indonesian (default) / English translations, transliteration with edition choice, optional tajwid, Arabic/translation/transliteration toggles + independent font scales, Arabic-numeral toggle, global search, jump-to-ayah, bookmarks + last-read + per-ayah read marks, surah/juz views, offline text cache, murotal continuous playback with prev/next, repeat/order controls, mini + full player, progress seeking, murotal downloads, playlists (create/rename/reorder/delete), rain background sound with independent volume, GPS prayer times + hijri date + adhan + notifications, Ramadan imsakiyah, qibla compass, tasbih counter, khatam planner/tracker, zakat calculator, hajj guide, Asmaul Husna, daily duas, storage management, light + dark themes, Indonesian/English app content.

Technical constraints: Flutter (Android + iOS, single codebase); local persistence via shared_preferences + path_provider; audio via just_audio + background service; must remain fully usable offline once downloaded; must not invent Quran text, translations, timings, or commercial claims; 48–52dp minimum touch targets preserved; 21 screens in lib/screens must all migrate to the new world.

Explicitly undecided: detailed audience refinement beyond above.

## Brand Commitments

Name QuranKu by QuranKu Community stays. Green accent #2E9D6B stays as identity anchor (user vote: "Keep name + green, replace rest"). Indonesian voice. Everything else — Liquid Glass treatment, Space Grotesk/Amiri pairing, translucency/blur language, card radii, navigation pattern — is free to replace. No donation channel. MIT license.

## Evidence on Hand

Real content and paths future work must use, not fabricate: lib/screens (21 screens), lib/services (settings, api, audio, downloads, khatam, tasbih, adhan, gps prayer), lib/models, lib/data (asmaul_husna, daily_duas, hajj_guide), lib/utils (hijri, tajwid), lib/widgets (liquid_glass, mini_player, full_player_view), assets/editions.json, assets/surah_list.json, assets/loc_indonesian.json, assets/mushaf_pages.json, assets/quran/, assets/adhan/, assets/splash.png, assets/icon_with_background.png, docs/screenshot/ (6 current captures showing home, murotal, prayer, surah detail, settings, playlist). No invented testimonials, benchmarks, or pricing — none exist.

## Product Principles

1. Accuracy before decoration — never guess sacred text or timings.
2. Calm focus — reading and listening lead; tools recede until needed.
3. Older-inclusive by default — size, contrast, and one-tap resume are non-negotiable.
4. Offline-reliable — downloaded truth works with no network.
5. Indonesian-first clarity — plain labels, no hype, no gamification.

## Accessibility & Inclusion

Known needs: older users, low vision, low-light reading; adjustable Arabic/translation/transliteration scales; large 48–52dp targets; high-contrast light + dark themes; semantic labels on icon buttons; compass, audio, and prayer-time states must remain perceivable without color alone. No formal WCAG certification requirement established.
