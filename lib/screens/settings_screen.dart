import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/settings_service.dart';
import '../widgets/liquid_glass.dart';
import 'storage_management_screen.dart';
import 'about_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final SettingsService _settings = SettingsService();
  Map<String, dynamic> _storageInfo = <String, dynamic>{};
  bool _loadingStorage = true;

  @override
  void initState() {
    super.initState();
    _settings.addListener(_refresh);
    _loadStorageInfo();
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

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Pengaturan'),
            Text(
              'Sesuaikan QuranKu agar nyaman digunakan.',
              style: GoogleFonts.spaceGrotesk(
                color: scheme.onSurface.withValues(alpha: 0.55),
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
          const LiquidGlassSectionTitle(
            title: 'Tampilan & bacaan',
            subtitle: 'Semua pilihan dibuat sederhana dan mudah dipahami.',
          ),
          LiquidGlassCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _settingTile(
                  icon: _settings.themeMode == ThemeMode.light
                      ? Icons.light_mode_outlined
                      : Icons.dark_mode_outlined,
                  title: 'Tema aplikasi',
                  subtitle: _settings.themeMode == ThemeMode.light ? 'Terang' : 'Gelap',
                  onTap: () => _showThemeDialog(context),
                ),
                _divider(),
                _settingTile(
                  icon: Icons.translate_rounded,
                  title: 'Terjemahan default',
                  subtitle: _translationName(_settings.defaultTranslation),
                  onTap: () => _showTranslationDialog(context),
                ),
                _divider(),
                SwitchListTile.adaptive(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                  secondary: Icon(Icons.format_list_numbered_rounded, color: scheme.primary),
                  title: Text(
                    'Angka Arab',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: Text(
                    'Tampilkan ١٢٣ menggantikan 123',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 13,
                      color: scheme.onSurface.withValues(alpha: 0.55),
                    ),
                  ),
                  value: _settings.useArabicNumerals,
                  onChanged: _settings.setUseArabicNumerals,
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
          const LiquidGlassSectionTitle(
            title: 'Penyimpanan',
            subtitle: 'Kelola cache dan file Al-Quran yang tersimpan di perangkat.',
          ),
          LiquidGlassCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _settingTile(
                  icon: Icons.cleaning_services_outlined,
                  title: 'Bersihkan cache',
                  subtitle: _loadingStorage
                      ? 'Menghitung penggunaan…'
                      : '${_settings.formatBytes(_storageInfo['cacheSize'] ?? 0)} dapat dibersihkan',
                  onTap: () => _confirmClearCache(context),
                  showArrow: false,
                  trailing: _loadingStorage
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(Icons.chevron_right_rounded, color: scheme.onSurface.withValues(alpha: 0.42)),
                ),
                _divider(),
                _settingTile(
                  icon: Icons.storage_outlined,
                  title: 'Kelola penyimpanan',
                  subtitle: '${_settings.formatBytes(_storageInfo['totalSize'] ?? 0)} digunakan',
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const StorageManagementScreen()),
                    );
                    _loadStorageInfo();
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
          const LiquidGlassSectionTitle(
            title: 'Tentang',
            subtitle: 'Informasi aplikasi dan developer.',
          ),
          LiquidGlassCard(
            padding: EdgeInsets.zero,
            child: _settingTile(
              icon: Icons.auto_awesome_outlined,
              title: 'Tentang QuranKu',
              subtitle: "'v3.0.0' • RAFDEV",
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AboutScreen()),
              ),
            ),
          ),
          const SizedBox(height: 36),
          Center(
            child: Column(
              children: [
                Text(
                  'Dibuat dengan hati untuk umat.',
                  style: GoogleFonts.spaceGrotesk(
                    color: scheme.onSurface.withValues(alpha: 0.50),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Baca • Renungkan • Amalkan',
                  style: GoogleFonts.spaceGrotesk(
                    color: scheme.onSurface.withValues(alpha: 0.48),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '© ${DateTime.now().year} RAFDEV',
                  style: GoogleFonts.spaceGrotesk(
                    color: scheme.onSurface.withValues(alpha: 0.35),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() => Divider(
        height: 1,
        color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.55),
      );

  Widget _settingTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool showArrow = true,
    Widget? trailing,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
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
          child: Icon(icon, color: scheme.primary, size: 23),
        ),
        title: Text(
          title,
          style: GoogleFonts.spaceGrotesk(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Text(
            subtitle,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 13,
              color: scheme.onSurface.withValues(alpha: 0.56),
            ),
          ),
        ),
        trailing: trailing ??
            (showArrow
                ? Icon(Icons.chevron_right_rounded, color: scheme.onSurface.withValues(alpha: 0.40))
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
    final items = _settings.getAvailableTranslations();
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: LiquidGlassCard(
            padding: const EdgeInsets.only(top: 8, bottom: 8),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: items.length,
              itemBuilder: (_, index) => RadioListTile<String>(
                value: items[index]['code']!,
                groupValue: _settings.defaultTranslation,
                title: Text(items[index]['name']!, style: const TextStyle(fontSize: 16)),
                onChanged: (value) => Navigator.pop(context, value),
              ),
            ),
          ),
        ),
      ),
    );
    if (selected != null) await _settings.setDefaultTranslation(selected);
  }

  Future<void> _confirmClearCache(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Bersihkan cache?'),
        content: const Text(
          'Teks Al-Quran, terjemahan, jadwal salat, dan file audio yang diunduh akan dihapus.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Bersihkan'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _settings.clearAllCache();
      await _loadStorageInfo();
    }
  }
}
