import 'package:flutter/material.dart';
import '../models/surah.dart';
import '../models/tafsir_edition.dart';
import '../services/api_service.dart';
import '../services/equran_service.dart';
import '../services/settings_service.dart';
import '../services/tafsir_service.dart';
import '../l10n/app_localizations.dart';
import '../l10n/tafsir_labels.dart';
import '../widgets/liquid_glass.dart';
import 'storage_management_screen.dart';
import 'about_screen.dart';
import 'privacy_screen.dart';
import 'download_screen.dart';
import 'surah_detail_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final SettingsService _settings = SettingsService();
  final TafsirService _tafsirService = TafsirService();
  Map<String, dynamic> _storageInfo = <String, dynamic>{};
  bool _loadingStorage = true;
  List<TafsirEdition> _tafsirEditions = const [];
  bool _loadingTafsir = false;

  @override
  void initState() {
    super.initState();
    _settings.addListener(_refresh);
    _loadStorageInfo();
    _loadTafsirEditions();
  }

  @override
  void dispose() {
    _settings.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _loadStorageInfo() async {
    setState(() => _loadingStorage = true);
    final info = await _settings.getStorageInfo();
    if (!mounted) return;
    setState(() {
      _storageInfo = info;
      _loadingStorage = false;
    });
  }

  String _translationName(String id) {
    final items = _settings.getAvailableTranslations();
    return items.firstWhere(
      (item) => item['code'] == id,
      orElse: () => {'name': id},
    )['name']!;
  }

  Future<void> _loadTafsirEditions() async {
    setState(() => _loadingTafsir = true);
    final editions = await _tafsirService.availableEditions();
    if (!mounted) return;
    setState(() {
      _tafsirEditions = editions;
      _loadingTafsir = false;
    });
  }

  String _tafsirSubtitle(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final id = _settings.tafsirEditionId;
    for (final edition in _tafsirEditions) {
      if (edition.slug == id) {
        return '${edition.name} • '
            '${tafsirLanguageLabel(l, edition.languageName)}';
      }
    }
    return _loadingTafsir ? l.settingsTafsirLoading : id;
  }

  /// Edition picker. The catalogue is 122 entries, so it gets a search field and
  /// is split into the curated shortlist and everything else.
  Future<void> _showTafsirDialog(BuildContext context) async {
    final l = AppLocalizations.of(context)!;
    if (_tafsirEditions.isEmpty && !_loadingTafsir) {
      await _loadTafsirEditions();
      if (!mounted) return;
    }
    final all = _tafsirEditions;
    final catalogueMissing = TafsirService.isCatalogueMissing(all);
    String filter = '';

    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (ctx, setSheet) {
          bool isRecommended(TafsirEdition e) =>
              e.slug == SettingsService.kemenagTafsirId ||
              TafsirService.curatedSlugs.contains(e.slug);

          final query = filter.trim().toLowerCase();
          final matching = query.isEmpty
              ? all
              : all
                    .where(
                      (e) =>
                          e.name.toLowerCase().contains(query) ||
                          e.authorName.toLowerCase().contains(query) ||
                          e.slug.toLowerCase().contains(query) ||
                          tafsirLanguageLabel(
                            l,
                            e.languageName,
                          ).toLowerCase().contains(query),
                    )
                    .toList();

          Widget header(String text) => Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 6),
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          );

          Widget tile(TafsirEdition edition) {
            final isSelected = edition.slug == _settings.tafsirEditionId;
            final language = tafsirLanguageLabel(l, edition.languageName);
            final subtitle = edition.authorName.isEmpty
                ? language
                : '$language • ${edition.authorName}';
            return ListTile(
              title: Text(edition.name),
              subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: isSelected
                  ? Icon(
                      Icons.check_rounded,
                      color: Theme.of(context).colorScheme.primary,
                    )
                  : null,
              onTap: () => Navigator.pop(context, edition.slug),
            );
          }

          final recommended = matching.where(isRecommended).toList();
          final rest = matching.where((e) => !isRecommended(e)).toList();

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: LiquidGlassCard(
                padding: const EdgeInsets.only(top: 8, bottom: 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                      child: TextField(
                        autofocus: false,
                        onChanged: (v) => setSheet(() => filter = v),
                        decoration: InputDecoration(
                          hintText: l.settingsTafsirSearchHint,
                          prefixIcon: const Icon(Icons.search_rounded),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                    if (catalogueMissing)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
                        child: Text(
                          l.settingsTafsirUnavailable,
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: .72),
                          ),
                        ),
                      ),
                    Flexible(
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (recommended.isNotEmpty) ...[
                              header(l.settingsTafsirRecommended),
                              ...recommended.map(tile),
                            ],
                            if (rest.isNotEmpty) ...[
                              header(l.settingsTafsirAllEditions),
                              ...rest.map(tile),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
    if (selected != null) await _settings.setTafsirEdition(selected);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppLocalizations.of(context)!.settingsTitle),
            Text(
              AppLocalizations.of(context)!.settingsSubtitle,
              style: TextStyle(
                color: scheme.onSurface.withValues(alpha: 0.72),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
        children: [
          LiquidGlassSectionTitle(
            title: AppLocalizations.of(context)!.settingsAppearance,
            subtitle: AppLocalizations.of(context)!.settingsAppearanceSubtitle,
          ),
          LiquidGlassCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _settingTile(
                  icon: _settings.themeMode == ThemeMode.light
                      ? Icons.light_mode_outlined
                      : Icons.dark_mode_outlined,
                  title: AppLocalizations.of(context)!.settingsTheme,
                  subtitle: _settings.themeMode == ThemeMode.light
                      ? AppLocalizations.of(context)!.settingsThemeLight
                      : AppLocalizations.of(context)!.settingsThemeDark,
                  onTap: () => _showThemeDialog(context),
                ),
                _divider(),
                _settingTile(
                  icon: Icons.translate_rounded,
                  title: AppLocalizations.of(context)!.settingsTranslation,
                  subtitle: _translationName(_settings.defaultTranslation),
                  onTap: () => _showTranslationDialog(context),
                ),
                _divider(),
                _settingTile(
                  icon: Icons.menu_book_outlined,
                  title: AppLocalizations.of(context)!.settingsTafsir,
                  subtitle: _tafsirSubtitle(context),
                  onTap: () => _showTafsirDialog(context),
                ),
                _divider(),
                _settingTile(
                  icon: Icons.text_fields_rounded,
                  title: AppLocalizations.of(context)!.settingsLatinType,
                  subtitle: _settings.transliterationName(
                    _settings.transliterationEdition,
                  ),
                  onTap: () => _showTransliterationDialog(context),
                ),
                _divider(),
                _settingTile(
                  icon: Icons.record_voice_over_rounded,
                  title: AppLocalizations.of(context)!.settingsQari,
                  subtitle: AppLocalizations.of(context)!
                      .settingsQariAlsoInMurotal(
                        EquranService.qariName(_settings.qariId),
                      ),
                  onTap: () => _showQariDialog(context),
                ),
                _divider(),
                _settingTile(
                  icon: Icons.language_rounded,
                  title: AppLocalizations.of(context)!.settingsLanguage,
                  subtitle: _languageSubtitle(context),
                  onTap: () => _showLanguageDialog(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Display toggles — global, persisted, with 44px targets and visible focus
          LiquidGlassCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                SwitchListTile.adaptive(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 4,
                  ),
                  secondary: Icon(
                    Icons.auto_stories_rounded,
                    color: scheme.primary,
                  ),
                  title: Text(
                    AppLocalizations.of(context)!.settingsShowArabic,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    AppLocalizations.of(context)!.settingsShowArabicSubtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurface.withValues(alpha: 0.72),
                    ),
                  ),
                  value: _settings.showArabic,
                  onChanged: (v) => _settings.setShowArabic(v),
                ),
                _divider(),
                SwitchListTile.adaptive(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 4,
                  ),
                  secondary: Icon(
                    Icons.spellcheck_rounded,
                    color: scheme.primary,
                  ),
                  title: Text(
                    AppLocalizations.of(context)!.settingsShowLatin,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    AppLocalizations.of(context)!.settingsShowLatinSubtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurface.withValues(alpha: 0.72),
                    ),
                  ),
                  value: _settings.showTransliteration,
                  onChanged: (v) => _settings.setShowTransliteration(v),
                ),
                _divider(),
                SwitchListTile.adaptive(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 4,
                  ),
                  secondary: Icon(
                    Icons.menu_book_outlined,
                    color: scheme.primary,
                  ),
                  title: Text(
                    AppLocalizations.of(context)!.settingsShowTranslation,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    AppLocalizations.of(
                      context,
                    )!.settingsShowTranslationSubtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurface.withValues(alpha: 0.72),
                    ),
                  ),
                  value: _settings.showTranslation,
                  onChanged: (v) => _settings.setShowTranslation(v),
                ),
                _divider(),
                SwitchListTile.adaptive(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 6,
                  ),
                  secondary: Icon(
                    Icons.format_list_numbered_rounded,
                    color: scheme.primary,
                  ),
                  title: Text(
                    AppLocalizations.of(context)!.settingsArabicNumerals,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    AppLocalizations.of(
                      context,
                    )!.settingsArabicNumeralsSubtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurface.withValues(alpha: 0.72),
                    ),
                  ),
                  value: _settings.useArabicNumerals,
                  onChanged: _settings.setUseArabicNumerals,
                ),
                _divider(),
                SwitchListTile.adaptive(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 4,
                  ),
                  secondary: Icon(
                    Icons.palette_outlined,
                    color: scheme.primary,
                  ),
                  title: Text(
                    AppLocalizations.of(context)!.settingsTajwid,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    AppLocalizations.of(context)!.settingsTajwidSubtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurface.withValues(alpha: 0.72),
                    ),
                  ),
                  value: _settings.showTajwid,
                  onChanged: (v) => _settings.setShowTajwid(v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          LiquidGlassCard(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context)!.settingsFontSize,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: scheme.onSurface.withValues(alpha: .72),
                  ),
                ),
                const SizedBox(height: 6),
                _fontRow(
                  AppLocalizations.of(context)!.readerFontArabic,
                  _settings.arabicFontScale,
                  0.85,
                  1.4,
                  (v) => _settings.setArabicFontScale(v),
                ),
                _fontRow(
                  'Latin',
                  _settings.transliterationFontScale,
                  0.85,
                  1.3,
                  (v) => _settings.setTransliterationFontScale(v),
                ),
                _fontRow(
                  AppLocalizations.of(context)!.readerShowTranslation,
                  _settings.translationFontScale,
                  0.85,
                  1.3,
                  (v) => _settings.setTranslationFontScale(v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
          LiquidGlassSectionTitle(
            title: AppLocalizations.of(context)!.settingsContinueReading,
            subtitle: AppLocalizations.of(
              context,
            )!.settingsContinueReadingSubtitle,
          ),
          LiquidGlassCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                if (_settings.lastSurah != null)
                  _settingTile(
                    icon: Icons.history_rounded,
                    title: AppLocalizations.of(context)!.homeLastReadEmpty,
                    subtitle: AppLocalizations.of(context)!.settingsLastReadSubtitle(
                      _settings.lastSurah!,
                      _settings.lastAyah ?? 1,
                    ),
                    onTap: () async {
                      try {
                        final surahs = await ApiService().fetchSurahs();
                        final s = surahs.firstWhere(
                          (e) => e.number == _settings.lastSurah!,
                          orElse: () => Surah(
                            number: _settings.lastSurah!,
                            name: 'Surah ${_settings.lastSurah}',
                            nameAr: '',
                            type: '',
                            totalAyahs: 0,
                          ),
                        );
                        if (!context.mounted) return;
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => SurahDetailScreen(
                              surah: s,
                              initialAyah: _settings.lastAyah,
                            ),
                          ),
                        );
                      } catch (_) {}
                    },
                    trailing: TextButton(
                      onPressed: () => _settings.clearLastRead(),
                      child: Text(AppLocalizations.of(context)!.actionClear),
                    ),
                    showArrow: true,
                  )
                else
                  _settingTile(
                    icon: Icons.history_rounded,
                    title: AppLocalizations.of(context)!.settingsNoReading,
                    subtitle: AppLocalizations.of(context)!.settingsNoReadingHint,
                    showArrow: false,
                  ),
                _divider(),
                _settingTile(
                  icon: Icons.bookmark_rounded,
                  title: AppLocalizations.of(context)!.bookmarksTitle,
                  subtitle: AppLocalizations.of(
                    context,
                  )!.settingsBookmarkCount(_settings.bookmarks.length),
                  onTap: () {
                    if (_settings.bookmarks.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            AppLocalizations.of(context)!.settingsNoBookmarks,
                          ),
                        ),
                      );
                    } else {
                      _showBookmarksSheet();
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
          LiquidGlassSectionTitle(
            title: AppLocalizations.of(context)!.settingsStorage,
            subtitle: AppLocalizations.of(context)!.settingsStorageSubtitle,
          ),
          LiquidGlassCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _settingTile(
                  icon: Icons.cleaning_services_outlined,
                  title: AppLocalizations.of(context)!.settingsClearCache,
                  subtitle: _loadingStorage
                      ? AppLocalizations.of(context)!.settingsCalculating
                      : AppLocalizations.of(context)!.settingsCacheCleanable(
                          _settings.formatBytes(_storageInfo['cacheSize'] ?? 0),
                        ),
                  onTap: () => _confirmClearCache(context),
                  showArrow: false,
                  trailing: _loadingStorage
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          Icons.chevron_right_rounded,
                          color: scheme.onSurface.withValues(alpha: 0.72),
                        ),
                ),
                _divider(),
                _settingTile(
                  icon: Icons.download_outlined,
                  title: AppLocalizations.of(context)!.settingsQuranDownloads,
                  subtitle: AppLocalizations.of(
                    context,
                  )!.settingsQuranDownloadsSubtitle,
                  onTap: () => _openDownloadManager(context),
                ),
                _divider(),
                _settingTile(
                  icon: Icons.storage_outlined,
                  title: AppLocalizations.of(context)!.settingsManageStorage,
                  subtitle: AppLocalizations.of(context)!.settingsStorageUsed(
                    _settings.formatBytes(_storageInfo['totalSize'] ?? 0),
                  ),
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const StorageManagementScreen(),
                      ),
                    );
                    _loadStorageInfo();
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
          LiquidGlassSectionTitle(
            title: AppLocalizations.of(context)!.settingsAbout,
            subtitle: AppLocalizations.of(context)!.settingsAboutSubtitle,
          ),
          LiquidGlassCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _settingTile(
                  icon: Icons.auto_awesome_outlined,
                  title: AppLocalizations.of(context)!.settingsAboutQuranKu,
                  subtitle: 'QuranKu',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AboutScreen()),
                  ),
                ),
                _divider(),
                _settingTile(
                  icon: Icons.privacy_tip_outlined,
                  title: AppLocalizations.of(context)!.settingsPrivacy,
                  subtitle: AppLocalizations.of(
                    context,
                  )!.settingsPrivacySubtitle,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const PrivacyScreen()),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 36),
          Center(
            child: Column(
              children: [
                Text(
                  AppLocalizations.of(context)!.settingsMadeWithHeart,
                  style: TextStyle(
                    color: scheme.onSurface.withValues(alpha: 0.72),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  AppLocalizations.of(context)!.settingsTagline,
                  style: TextStyle(
                    color: scheme.onSurface.withValues(alpha: 0.72),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '© ${DateTime.now().year} QuranKu',
                  style: TextStyle(
                    color: scheme.onSurface.withValues(alpha: 0.72),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _fontRow(
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged,
  ) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 86,
            child: Text(
              label,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Slider(
              value: value,
              min: min,
              max: max,
              divisions: 6,
              label: '${(value * 100).round()}%',
              activeColor: scheme.primary,
              onChanged: onChanged,
            ),
          ),
          SizedBox(
            width: 42,
            child: Text(
              '${(value * 100).round()}%',
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: scheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() => Divider(
    height: 1,
    color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.18),
  );

  /// Settings row. Pass a null [onTap] for an informational row: it renders
  /// without a tap target or ripple, so it cannot read as a dead control.
  Widget _settingTile({
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
    bool showArrow = true,
    Widget? trailing,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final interactive = onTap != null;
    return Semantics(
      button: interactive,
      label: '$title. $subtitle',
      child: ListTile(
        minVerticalPadding: 12,
        onTap: onTap,
        leading: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: scheme.primary.withValues(alpha: 0.10),
            shape: BoxShape.circle,
            border: Border.all(color: scheme.primary.withValues(alpha: 0.14)),
          ),
          alignment: Alignment.center,
          child: Icon(icon, color: scheme.primary, size: 22),
        ),
        title: Text(
          title,
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Text(
            subtitle,
            style: TextStyle(
              fontSize: 12.5,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
        trailing:
            trailing ??
            (interactive && showArrow
                ? Icon(
                    Icons.chevron_right_rounded,
                    color: scheme.onSurfaceVariant,
                  )
                : null),
      ),
    );
  }

  Future<void> _showThemeDialog(BuildContext context) async {
    final selected = await showModalBottomSheet<ThemeMode>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: LiquidGlassCard(
            padding: const EdgeInsets.all(8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.light_mode_outlined),
                  title: const Text('Terang'),
                  onTap: () => Navigator.pop(context, ThemeMode.light),
                ),
                ListTile(
                  leading: const Icon(Icons.dark_mode_outlined),
                  title: const Text('Gelap'),
                  onTap: () => Navigator.pop(context, ThemeMode.dark),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (selected != null) await _settings.setThemeMode(selected);
  }

  Future<void> _showTranslationDialog(BuildContext context) async {
    final allItems = _settings.getAvailableTranslations();
    String filter = '';
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (ctx, setSheet) {
          final filtered = filter.isEmpty
              ? allItems
              : allItems
                    .where(
                      (e) =>
                          e['name']!.toLowerCase().contains(
                            filter.toLowerCase(),
                          ) ||
                          e['code']!.toLowerCase().contains(
                            filter.toLowerCase(),
                          ),
                    )
                    .toList();
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: LiquidGlassCard(
                padding: const EdgeInsets.only(top: 8, bottom: 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                      child: TextField(
                        autofocus: true,
                        decoration: InputDecoration(
                          hintText: AppLocalizations.of(
                            context,
                          )!.settingsSearchLanguage,
                          prefixIcon: const Icon(Icons.search_rounded),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          isDense: true,
                        ),
                        onChanged: (v) => setSheet(() => filter = v),
                      ),
                    ),
                    Flexible(
                      child: filtered.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(
                                AppLocalizations.of(context)!.commonNoResults,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              itemCount: filtered.length,
                              itemBuilder: (_, index) => RadioListTile<String>(
                                value: filtered[index]['code']!,
                                groupValue: _settings.defaultTranslation,
                                title: Text(
                                  filtered[index]['name']!,
                                  style: const TextStyle(fontSize: 15),
                                ),
                                onChanged: (value) =>
                                    Navigator.pop(context, value),
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
    if (selected != null) await _settings.setDefaultTranslation(selected);
  }

  Future<void> _showTransliterationDialog(BuildContext context) async {
    final items = _settings.getTransliterationEditions();
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: LiquidGlassCard(
            padding: const EdgeInsets.all(8),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: items
                    .map(
                      (m) => RadioListTile<String>(
                        value: m['code']!,
                        groupValue: _settings.transliterationEdition,
                        title: Text(m['name']!),
                        onChanged: (v) => Navigator.pop(context, v),
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
        ),
      ),
    );
    if (selected != null) await _settings.setTransliterationEdition(selected);
  }

  Future<void> _showQariDialog(BuildContext context) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: LiquidGlassCard(
            padding: const EdgeInsets.all(8),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: EquranService.qaris
                    .map(
                      (q) => RadioListTile<String>(
                        value: q.id,
                        groupValue: _settings.qariId,
                        title: Text(q.name),
                        subtitle: q.id == EquranService.defaultQariId
                            ? Text(
                                AppLocalizations.of(
                                  context,
                                )!.settingsQariOfflineVoice,
                              )
                            : null,
                        onChanged: (v) => Navigator.pop(context, v),
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
        ),
      ),
    );
    if (selected != null) await _settings.setQariId(selected);
  }

  String _languageSubtitle(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    if (_settings.isFollowingSystem) {
      final sys = WidgetsBinding.instance.platformDispatcher.locale.languageCode == 'en' ? l.settingsLanguageEnglish : l.settingsLanguageIndonesian;
      return '${l.settingsLanguage} • Sistem ($sys)';
    }
    final code = _settings.appLocale?.languageCode;
    if (code == 'en') return l.settingsLanguageEnglish;
    return l.settingsLanguageIndonesian;
  }

  Future<void> _showLanguageDialog(BuildContext context) async {
    final l = AppLocalizations.of(context)!;
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: LiquidGlassCard(
            padding: const EdgeInsets.all(8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RadioListTile<String>(
                  value: 'system',
                  groupValue: _settings.isFollowingSystem ? 'system' : _settings.appLocale?.languageCode,
                  title: Text(l.settingsLanguage + ' • Sistem'),
                  subtitle: Text(
                    AppLocalizations.of(context)!.settingsFollowSystem,
                  ),
                  onChanged: (v) => Navigator.pop(context, v),
                ),
                RadioListTile<String>(
                  value: 'id',
                  groupValue: _settings.isFollowingSystem ? 'system' : _settings.appLocale?.languageCode,
                  title: Text(l.settingsLanguageIndonesian),
                  subtitle: Text(
                    AppLocalizations.of(
                      context,
                    )!.settingsLanguageIndonesianSubtitle,
                  ),
                  onChanged: (v) => Navigator.pop(context, v),
                ),
                RadioListTile<String>(
                  value: 'en',
                  groupValue: _settings.isFollowingSystem ? 'system' : _settings.appLocale?.languageCode,
                  title: Text(l.settingsLanguageEnglish),
                  subtitle: Text(
                    AppLocalizations.of(
                      context,
                    )!.settingsLanguageEnglishSubtitle,
                  ),
                  onChanged: (v) => Navigator.pop(context, v),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (selected == null) return;
    if (selected == 'system') {
      await _settings.setAppLocale(null);
    } else if (selected == 'id') {
      await _settings.setAppLocale(const Locale('id', 'ID'));
    } else if (selected == 'en') {
      await _settings.setAppLocale(const Locale('en', 'US'));
    }
  }

  void _showBookmarksSheet() async {
    final raw = _settings.bookmarks.toList();
    // Numeric sort: surah asc then ayah asc
    raw.sort((a, b) {
      final pa = a.split('_');
      final pb = b.split('_');
      final sa = int.tryParse(pa[0]) ?? 0;
      final sb = int.tryParse(pb[0]) ?? 0;
      if (sa != sb) return sa.compareTo(sb);
      final aa = int.tryParse(pa[1]) ?? 0;
      final ab = int.tryParse(pb[1]) ?? 0;
      return aa.compareTo(ab);
    });
    // Load surah names for display
    Map<int, String> names = {};
    try {
      final surahs = await ApiService().fetchSurahs();
      names = {for (var s in surahs) s.number: s.name};
    } catch (_) {}
    if (!mounted) return;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: LiquidGlassCard(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Bookmark',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${raw.length} ayat',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: raw.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(24),
                          child: Center(
                            child: Text(
                              AppLocalizations.of(context)!.settingsNoBookmarks,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          itemCount: raw.length,
                          separatorBuilder: (_, __) => Divider(
                            height: 1,
                            color: Theme.of(
                              context,
                            ).colorScheme.outline.withValues(alpha: .12),
                          ),
                          itemBuilder: (_, i) {
                            final k = raw[i];
                            final parts = k.split('_');
                            final sNum = int.tryParse(parts[0]) ?? 0;
                            final aNum = int.tryParse(parts[1]) ?? 0;
                            final sName = names[sNum] ?? 'Surah $sNum';
                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 2,
                              ),
                              leading: Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.primary.withValues(alpha: .12),
                                ),
                                child: Icon(
                                  Icons.bookmark_rounded,
                                  size: 18,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                              title: Text(
                                '$sName • QS $sNum:$aNum',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                              subtitle: Text(
                                AppLocalizations.of(context)!.settingsTapToOpen,
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withValues(alpha: .72),
                                    ),
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline_rounded),
                                tooltip: AppLocalizations.of(context)!.commonDelete,
                                onPressed: () async {
                                  Navigator.pop(context);
                                  await _settings.toggleBookmark(sNum, aNum);
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          AppLocalizations.of(context)!
                                              .settingsBookmarkRemoved(
                                                sNum,
                                                aNum,
                                              ),
                                        ),
                                        action: SnackBarAction(
                                          label: AppLocalizations.of(
                                            context,
                                          )!.commonUndo,
                                          onPressed: () => _settings
                                              .toggleBookmark(sNum, aNum),
                                        ),
                                      ),
                                    );
                                    if (_settings.bookmarks.isNotEmpty)
                                      _showBookmarksSheet();
                                  }
                                },
                              ),
                              onTap: () {
                                Navigator.pop(context);
                                final surah = Surah(
                                  number: sNum,
                                  name: sName,
                                  nameAr: '',
                                  type: '',
                                  totalAyahs: 0,
                                );
                                // Try to get real totalAyahs if available
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => SurahDetailScreen(
                                      surah: surah,
                                      initialAyah: aNum,
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Tutup'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openDownloadManager(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.18),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.72,
        minChildSize: 0.50,
        maxChildSize: 0.94,
        expand: false,
        builder: (context, scrollController) =>
            DownloadScreen(scrollController: scrollController),
      ),
    );
    _loadStorageInfo();
  }

  Future<void> _confirmClearCache(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          AppLocalizations.of(context)!.settingsClearCacheConfirmTitle,
        ),
        content: Text(
          AppLocalizations.of(context)!.settingsClearCacheConfirmBody,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Bersihkan'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _settings.clearAllCache();
      await _loadStorageInfo();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!.settingsCacheCleared,
          ),
        ),
      );
    }
  }
}
