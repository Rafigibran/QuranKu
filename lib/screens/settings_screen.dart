import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/settings_service.dart';
import '../services/app_language_service.dart';
import 'storage_management_screen.dart';
import 'about_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final SettingsService _settings = SettingsService();
  final AppLanguageService _language = AppLanguageService();
  Map<String, dynamic> _storageInfo = {};
  bool _loadingStorage = true;

  @override
  void initState() {
    super.initState();
    _settings.addListener(_refresh);
    _language.addListener(_refresh);
    _loadStorageInfo();
  }

  @override
  void dispose() {
    _settings.removeListener(_refresh);
    _language.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _loadStorageInfo() async {
    setState(() => _loadingStorage = true);
    final info = await _settings.getStorageInfo();
    if (mounted) setState(() { _storageInfo = info; _loadingStorage = false; });
  }

  String _t(String key) => _language.t(key);

  String _translationName(String id) {
    final items = _settings.getAvailableTranslations();
    return items.firstWhere((item) => item['code'] == id, orElse: () => {'name': id})['name']!;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        title: Text.rich(
          TextSpan(
            text: _t('settings').toUpperCase(),
            style: GoogleFonts.spaceGrotesk(fontSize: 24, fontWeight: FontWeight.bold, color: colors.onSurface),
            children: [TextSpan(text: '.', style: GoogleFonts.spaceGrotesk(color: colors.primary))],
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _section(context, _t('general')),
          _card(context, children: [
            _tile(context, _t('language'), _language.languageName, Icons.language, () => _showLanguageDialog(context)),
            _divider(context),
            _tile(context, _t('theme'), _settings.themeMode == ThemeMode.light ? _t('light') : _t('dark'), Icons.dark_mode_outlined, () => _showThemeDialog(context)),
            _divider(context),
            _tile(context, _t('default_translation'), _translationName(_settings.defaultTranslation), Icons.translate, () => _showTranslationDialog(context)),
            _divider(context),
            SwitchListTile(
              title: Text(_t('arabic_numerals'), style: GoogleFonts.spaceGrotesk(color: colors.onSurface, fontWeight: FontWeight.w500)),
              subtitle: Text(_t('arabic_numerals_desc'), style: GoogleFonts.spaceGrotesk(color: colors.onSurface.withValues(alpha: 0.5), fontSize: 12)),
              secondary: Icon(Icons.numbers, color: colors.primary),
              value: _settings.useArabicNumerals,
              onChanged: _settings.setUseArabicNumerals,
            ),
          ]),
          const SizedBox(height: 32),
          _section(context, _t('storage')),
          _card(context, children: [
            _storageTile(context, _t('clear_cache'), _t('clear_cache_desc'), _loadingStorage ? '...' : _settings.formatBytes(_storageInfo['cacheSize'] ?? 0), Icons.cleaning_services_outlined, () => _confirmClearCache(context)),
            _storageTile(context, _t('manage_storage'), '${_settings.formatBytes(_storageInfo['totalSize'] ?? 0)} used', '', Icons.storage, () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => const StorageManagementScreen()));
              _loadStorageInfo();
            }),
          ]),
          const SizedBox(height: 32),
          _section(context, _t('about')),
          _card(context, children: [
            _tile(context, _t('about_developer'), 'v3.0.0', Icons.info_outline, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AboutScreen()))),
          ]),
          const SizedBox(height: 48),
          Center(child: Column(children: [
            Text(_t('built_for_ummah'), style: GoogleFonts.spaceGrotesk(color: colors.onSurface.withValues(alpha: 0.5), fontSize: 12)),
            const SizedBox(height: 4),
            Text(_t('read_reflect_act'), style: GoogleFonts.spaceGrotesk(color: colors.onSurface.withValues(alpha: 0.5), fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('© ${DateTime.now().year} RAFDEV. Open Source.', style: GoogleFonts.spaceGrotesk(color: colors.onSurface.withValues(alpha: 0.5), fontSize: 10)),
          ])),
          const SizedBox(height: 96),
        ],
      ),
    );
  }

  Widget _section(BuildContext context, String title) => Padding(
    padding: const EdgeInsets.only(left: 8, bottom: 12),
    child: Text(title.toUpperCase(), style: GoogleFonts.spaceGrotesk(color: Theme.of(context).colorScheme.primary, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
  );

  Widget _card(BuildContext context, {required List<Widget> children}) => Container(
    decoration: BoxDecoration(color: Theme.of(context).cardColor, border: Border.all(color: Theme.of(context).colorScheme.outline)),
    child: Column(children: children),
  );

  Widget _divider(BuildContext context) => Divider(height: 1, color: Theme.of(context).colorScheme.outline);

  Widget _tile(BuildContext context, String title, String subtitle, IconData icon, VoidCallback onTap) {
    final colors = Theme.of(context).colorScheme;
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Icon(icon, color: colors.primary),
      title: Text(title, style: GoogleFonts.spaceGrotesk(color: colors.onSurface, fontWeight: FontWeight.w500)),
      subtitle: Text(subtitle, style: GoogleFonts.spaceGrotesk(color: colors.onSurface.withValues(alpha: 0.5), fontSize: 12)),
      trailing: Icon(Icons.chevron_right, color: colors.onSurface.withValues(alpha: 0.5)),
    );
  }

  Widget _storageTile(BuildContext context, String title, String subtitle, String value, IconData icon, VoidCallback onTap) {
    final colors = Theme.of(context).colorScheme;
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Icon(icon, color: colors.primary),
      title: Row(children: [Expanded(child: Text(title, style: GoogleFonts.spaceGrotesk(color: colors.onSurface, fontWeight: FontWeight.w500))), if (value.isNotEmpty) Text(value, style: GoogleFonts.spaceGrotesk(color: colors.primary, fontWeight: FontWeight.bold))]),
      subtitle: Text(subtitle, style: GoogleFonts.spaceGrotesk(color: colors.onSurface.withValues(alpha: 0.5), fontSize: 12)),
      trailing: Icon(Icons.chevron_right, color: colors.onSurface.withValues(alpha: 0.5)),
    );
  }

  Future<void> _showLanguageDialog(BuildContext context) async {
    final selected = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(_t('select_language')),
        children: [
          SimpleDialogOption(onPressed: () => Navigator.pop(context, 'id'), child: const Text('Indonesia')),
          SimpleDialogOption(onPressed: () => Navigator.pop(context, 'en'), child: const Text('English')),
        ],
      ),
    );
    if (selected != null) await _language.setLanguage(selected);
  }

  Future<void> _showThemeDialog(BuildContext context) async {
    final selected = await showDialog<ThemeMode>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(_t('select_theme')),
        children: [
          SimpleDialogOption(onPressed: () => Navigator.pop(context, ThemeMode.light), child: Text(_t('light'))),
          SimpleDialogOption(onPressed: () => Navigator.pop(context, ThemeMode.dark), child: Text(_t('dark'))),
        ],
      ),
    );
    if (selected != null) await _settings.setThemeMode(selected);
  }

  Future<void> _showTranslationDialog(BuildContext context) async {
    final items = _settings.getAvailableTranslations();
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(child: ListView.builder(
        shrinkWrap: true,
        itemCount: items.length,
        itemBuilder: (_, index) => RadioListTile<String>(
          value: items[index]['code']!,
          groupValue: _settings.defaultTranslation,
          title: Text(items[index]['name']!),
          onChanged: (value) => Navigator.pop(context, value),
        ),
      )),
    );
    if (selected != null) await _settings.setDefaultTranslation(selected);
  }

  Future<void> _confirmClearCache(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_t('clear_all_cache')),
        content: Text(_t('clear_all_cache_desc')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(_t('cancel'))),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: Text(_t('clear_all'))),
        ],
      ),
    );
    if (confirmed == true) {
      await _settings.clearAllCache();
      await _loadStorageInfo();
    }
  }
}
