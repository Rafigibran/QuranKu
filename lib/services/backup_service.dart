import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BackupService {
  static const _prefixes = <String>[
    'settings_',
    'playlist_',
    'tasbih_',
    'last_reading_',
    'reading_',
    'bookmark_',
    'last_read_history',
  ];

  Future<Map<String, dynamic>> _collect() async {
    final prefs = await SharedPreferences.getInstance();
    final data = <String, dynamic>{};
    for (final key in prefs.getKeys()) {
      if (!_prefixes.any(key.startsWith)) continue;
      final value = prefs.get(key);
      if (value != null) data[key] = value;
    }
    return {
      'format': 'quranku-backup',
      'version': 1,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'data': data,
    };
  }

  Future<Uri?> exportToDrive() async {
    final payload = jsonEncode(await _collect());
    return FilePicker.saveFile(
      dialogTitle: 'Simpan backup QuranKu',
      fileName: 'QuranKu-backup.json',
      bytes: Uint8List.fromList(utf8.encode(payload)),
      mimeType: 'application/json',
      allowedExtensions: const ['json'],
    );
  }

  Future<BackupRestoreResult> importFromDrive() async {
    final file = await FilePicker.pickFile(
      dialogTitle: 'Pilih backup QuranKu',
      type: FileType.custom,
      allowedExtensions: const ['json'],
    );
    if (file == null) return BackupRestoreResult.cancelled;

    final bytes = await file.readAsBytes();
    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is! Map<String, dynamic> || decoded['format'] != 'quranku-backup') {
      throw const FormatException('File bukan backup QuranKu yang valid.');
    }
    final rawData = decoded['data'];
    if (rawData is! Map<String, dynamic>) {
      throw const FormatException('Struktur backup tidak valid.');
    }

    final prefs = await SharedPreferences.getInstance();
    for (final entry in rawData.entries) {
      final key = entry.key;
      if (!_prefixes.any(key.startsWith)) continue;
      await _writeValue(prefs, key, entry.value);
    }
    return BackupRestoreResult.restored;
  }

  Future<void> _writeValue(SharedPreferences prefs, String key, dynamic value) async {
    if (value is bool) {
      await prefs.setBool(key, value);
    } else if (value is int) {
      await prefs.setInt(key, value);
    } else if (value is double) {
      await prefs.setDouble(key, value);
    } else if (value is String) {
      await prefs.setString(key, value);
    } else if (value is List) {
      await prefs.setStringList(key, value.map((e) => e.toString()).toList());
    }
  }
}

enum BackupRestoreResult { cancelled, restored }
