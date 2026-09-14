import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/settings_service.dart';
import 'storage_management_screen.dart';
import 'about_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final SettingsService _settings = SettingsService();
  Map<String, dynamic> _storageInfo = {};
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
    if (mounted) {
      setState(() {
        _storageInfo = info;
        _loadingStorage = false;
      });
    }
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
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        title: Text.rich(
          TextSpan(
            text: 'PENGATURAN',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: colors.onSurface,
            ),
            children: [
              TextSpan(
                text: '.',
                style: GoogleFonts.spaceGrotesk(color: colors.primary),
              ),
            ],
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _section(context, 'UMUM'),
          _card(
            context,
            children: [
              _tile(
                context,
                'Tema',
                _settings.themeMode == ThemeMode.light ? 'Terang' : 'Gelap',
                Icons.dark_mode_outlined,
                () => _showThemeDialog(context),
              ),
              _divider(context),
              _tile(
                context,
                'Terjemahan Default',
                _translationName(_settings.defaultTranslation),
                Icons.translate,
                () => _showTranslationDialog(context),
              ),
              _divider(context),
              SwitchListTile(
                title: Text(
                  'Angka Arab',
                  style: GoogleFonts.spaceGrotesk(
                    color: colors.onSurface,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                subtitle: Text(
                  'Gunakan ١٢٣ bukan 123',
                  style: GoogleFonts.spaceGrotesk(
                    color: colors.onSurface.withValues(alpha: 0.5),
                    fontSize: 12,
                  ),
                ),
                secondary: Icon(Icons.numbers, color: colors.primary),
                value: _settings.useArabicNumerals,
                onChanged: _settings.setUseArabicNumerals,
              ),
            ],
          ),
          const SizedBox(height: 32),
          _section(context, 'PENYIMPANAN'),
          _card(
            context,
            children: [
              _storageTile(
                context,
                'Bersihkan Cache',
                'Menghapus file sementara untuk mengosongkan ruang',
                _loadingStorage
                    ? '...'
                    : _settings.formatBytes(_storageInfo['cacheSize'] ?? 0),
                Icons.cleaning_services_outlined,
                () => _confirmClearCache(context),
              ),
              _storageTile(
                context,
                'Kelola Penyimpanan',
                '${_settings.formatBytes(_storageInfo['totalSize'] ?? 0)} digunakan',
                '',
                Icons.storage,
                () async {
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
          const SizedBox(height: 32),
          _section(context, 'TENTANG'),
          _card(
            context,
            children: [
              _tile(
                context,
                'Tentang Developer',
                'v3.0.0',
                Icons.info_outline,
                () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AboutScreen()),
                ),
              ),
            ],
          ),
          const SizedBox(height: 48),
          Center(
            child: Column(
              children: [
                Text(
                  'Dibuat dengan ❤️ untuk Umat',
                  style: GoogleFonts.spaceGrotesk(
                    color: colors.onSurface.withValues(alpha: 0.5),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Baca. Renungkan. Amalkan.',
                  style: GoogleFonts.spaceGrotesk(
                    color: colors.onSurface.withValues(alpha: 0.5),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '© ${DateTime.now().year} RAFDEV. Open Source.',
                  style: GoogleFonts.spaceGrotesk(
                    color: colors.onSurface.withValues(alpha: 0.5),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 96),
        ],
      ),
    );
  }

  Widget _section(BuildContext context, String title) => Padding(
        padding: const EdgeInsets.only(left: 8, bottom: 12),
        child: Text(
          title,
          style: GoogleFonts.spaceGrotesk(
            color: Theme.of(context).colorScheme.primary,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
      );

  Widget _card(BuildContext context, {required List<Widget> children}) =>
      Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          border: Border.all(color: Theme.of(context).colorScheme.outline),
        ),
        child: Column(children: children),
      );

  Widget _divider(BuildContext context) =>
      Divider(height: 1, color: Theme.of(context).colorScheme.outline);

  Widget _tile(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    VoidCallback onTap,
  ) {
    final colors = Theme.of(context).colorScheme;
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Icon(icon, color: colors.primary),
      title: Text(
        title,
        style: GoogleFonts.spaceGrotesk(
          color: colors.onSurface,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: GoogleFonts.spaceGrotesk(
          color: colors.onSurface.withValues(alpha: 0.5),
          fontSize: 12,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right,
        color: colors.onSurface.withValues(alpha: 0.5),
      ),
    );
  }

  Widget _storageTile(
    BuildContext context,
    String title,
    String subtitle,
    String value,
    IconData icon,
    VoidCallback onTap,
  ) {
    final colors = Theme.of(context).colorScheme;
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Icon(icon, color: colors.primary),
      title: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: GoogleFonts.spaceGrotesk(
                color: colors.onSurface,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (value.isNotEmpty)
            Text(
              value,
              style: GoogleFonts.spaceGrotesk(
                color: colors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
        ],
      ),
      subtitle: Text(
        subtitle,
        style: GoogleFonts.spaceGrotesk(
          color: colors.onSurface.withValues(alpha: 0.5),
          fontSize: 12,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right,
        color: colors.onSurface.withValues(alpha: 0.5),
      ),
    );
  }

  Future<void> _showThemeDialog(BuildContext context) async {
    final selected = await showDialog<ThemeMode>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Pilih Tema'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, ThemeMode.light),
            child: const Text('Terang'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, ThemeMode.dark),
            child: const Text('Gelap'),
          ),
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
      builder: (context) => SafeArea(
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: items.length,
          itemBuilder: (_, index) => RadioListTile<String>(
            value: items[index]['code']!,
            groupValue: _settings.defaultTranslation,
            title: Text(items[index]['name']!),
            onChanged: (value) => Navigator.pop(context, value),
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
        title: const Text('Bersihkan Semua Cache?'),
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
            child: const Text('Bersihkan Semua'),
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
