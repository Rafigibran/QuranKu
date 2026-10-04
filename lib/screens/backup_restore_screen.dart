import 'package:flutter/material.dart';

import '../services/backup_service.dart';
import '../widgets/liquid_glass.dart';

class BackupRestoreScreen extends StatefulWidget {
  const BackupRestoreScreen({super.key});

  @override
  State<BackupRestoreScreen> createState() => _BackupRestoreScreenState();
}

class _BackupRestoreScreenState extends State<BackupRestoreScreen> {
  final BackupService _service = BackupService();
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Backup & pulihkan')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          LiquidGlassCard(
            padding: const EdgeInsets.all(22),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.cloud_sync_rounded, color: scheme.primary, size: 38),
              const SizedBox(height: 14),
              Text('Bawa data penting QuranKu', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text('Backup mencakup pengaturan, playlist, tasbih, dan posisi bacaan terakhir. Cache Al-Quran dan file audio tidak ikut agar ukuran file tetap kecil.'),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: _busy ? null : () async {
                  if (_busy) return;
                  setState(() => _busy = true);
                  try {
                    final uri = await _service.exportToDrive();
                    if (!mounted || uri == null) return;
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Backup berhasil disimpan.')));
                  } catch (e) {
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal membuat backup: $e')));
                  } finally {
                    if (mounted) setState(() => _busy = false);
                  }
                },
                icon: const Icon(Icons.upload_rounded),
                label: const Text('Simpan backup'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _busy ? null : () async {
                  if (_busy) return;
                  setState(() => _busy = true);
                  try {
                    final restored = await _service.importFromDrive();
                    if (!mounted) return;
                    if (restored == BackupRestoreResult.restored) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Backup dipulihkan. Tutup dan buka ulang layar agar semua pengaturan termuat.')));
                    }
                  } catch (e) {
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal memulihkan backup: $e')));
                  } finally {
                    if (mounted) setState(() => _busy = false);
                  }
                },
                icon: const Icon(Icons.download_rounded),
                label: const Text('Pulihkan backup'),
              ),
            ]),
          ),
          const SizedBox(height: 14),
          LiquidGlassCard(
            padding: const EdgeInsets.all(18),
            child: Text('Google Drive muncul sebagai lokasi cloud di pemilih file Android saat aplikasi Google Drive tersedia dan login. QuranKu tidak meminta kredensial Google secara langsung.', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onSurface.withValues(alpha: .65))),
          ),
        ],
      ),
    );
  }
}
