import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BookmarkFolder {
  final String id;
  final String name;
  const BookmarkFolder({required this.id, required this.name});
  Map<String, dynamic> toJson() => {'id': id, 'name': name};
  factory BookmarkFolder.fromJson(Map<String, dynamic> json) =>
      BookmarkFolder(id: json['id'].toString(), name: json['name'].toString());
}

class BookmarkItem {
  final String id;
  final int surahNumber;
  final int ayahNumber;
  final String folderId;
  final DateTime createdAt;
  const BookmarkItem({required this.id, required this.surahNumber, required this.ayahNumber, required this.folderId, required this.createdAt});
  Map<String, dynamic> toJson() => {'id': id, 'surahNumber': surahNumber, 'ayahNumber': ayahNumber, 'folderId': folderId, 'createdAt': createdAt.toIso8601String()};
  factory BookmarkItem.fromJson(Map<String, dynamic> json) => BookmarkItem(
    id: json['id'].toString(),
    surahNumber: (json['surahNumber'] as num).toInt(),
    ayahNumber: (json['ayahNumber'] as num).toInt(),
    folderId: json['folderId'].toString(),
    createdAt: DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now(),
  );
}

class LastReadEntry {
  final int surahNumber;
  final int ayahNumber;
  final DateTime timestamp;
  const LastReadEntry({required this.surahNumber, required this.ayahNumber, required this.timestamp});
  Map<String, dynamic> toJson() => {'surahNumber': surahNumber, 'ayahNumber': ayahNumber, 'timestamp': timestamp.toIso8601String()};
  factory LastReadEntry.fromJson(Map<String, dynamic> json) => LastReadEntry(
    surahNumber: (json['surahNumber'] as num).toInt(),
    ayahNumber: (json['ayahNumber'] as num).toInt(),
    timestamp: DateTime.tryParse(json['timestamp'].toString()) ?? DateTime.now(),
  );
}

class BookmarkService extends ChangeNotifier {
  static final BookmarkService _instance = BookmarkService._internal();
  factory BookmarkService() => _instance;
  BookmarkService._internal();

  static const _foldersKey = 'bookmark_folders_v1';
  static const _itemsKey = 'bookmark_items_v1';
  static const _historyKey = 'last_read_history_v1';

  final List<BookmarkFolder> _folders = [];
  final List<BookmarkItem> _items = [];
  final List<LastReadEntry> _history = [];
  bool _initialized = false;

  List<BookmarkFolder> get folders => List.unmodifiable(_folders);
  List<BookmarkItem> get items => List.unmodifiable(_items);
  List<LastReadEntry> get history => List.unmodifiable(_history);
  String get defaultFolderId => _folders.isNotEmpty ? _folders.first.id : 'favorites';

  Future<void> init() async {
    if (_initialized) return;
    final prefs = await SharedPreferences.getInstance();
    _folders
      ..clear()
      ..addAll((prefs.getStringList(_foldersKey) ?? const []).map((e) => BookmarkFolder.fromJson(jsonDecode(e))));
    if (_folders.isEmpty) {
      _folders.add(const BookmarkFolder(id: 'favorites', name: 'Favorit'));
      await _saveFolders(prefs);
    }
    _items
      ..clear()
      ..addAll((prefs.getStringList(_itemsKey) ?? const []).map((e) => BookmarkItem.fromJson(jsonDecode(e))));
    _history
      ..clear()
      ..addAll((prefs.getStringList(_historyKey) ?? const []).map((e) => LastReadEntry.fromJson(jsonDecode(e))));
    _initialized = true;
    notifyListeners();
  }

  Future<void> _ensure() async { if (!_initialized) await init(); }

  bool isBookmarked(int surahNumber, int ayahNumber) =>
      _items.any((e) => e.surahNumber == surahNumber && e.ayahNumber == ayahNumber);

  List<BookmarkItem> itemsForFolder(String folderId) =>
      _items.where((e) => e.folderId == folderId).toList(growable: false);

  Future<void> toggle(int surahNumber, int ayahNumber, {String? folderId}) async {
    await _ensure();
    final exists = isBookmarked(surahNumber, ayahNumber);
    if (exists) {
      _items.removeWhere((e) => e.surahNumber == surahNumber && e.ayahNumber == ayahNumber);
    } else {
      _items.add(BookmarkItem(
        id: '${surahNumber}_${ayahNumber}_${DateTime.now().microsecondsSinceEpoch}',
        surahNumber: surahNumber,
        ayahNumber: ayahNumber,
        folderId: folderId ?? defaultFolderId,
        createdAt: DateTime.now(),
      ));
    }
    await _save();
    notifyListeners();
  }

  Future<void> addToFolder(int surahNumber, int ayahNumber, String folderId) async {
    await _ensure();
    _items.removeWhere((e) => e.surahNumber == surahNumber && e.ayahNumber == ayahNumber);
    _items.add(BookmarkItem(
      id: '${surahNumber}_${ayahNumber}_${DateTime.now().microsecondsSinceEpoch}',
      surahNumber: surahNumber,
      ayahNumber: ayahNumber,
      folderId: folderId,
      createdAt: DateTime.now(),
    ));
    await _save();
    notifyListeners();
  }

  Future<void> addFolder(String name) async {
    await _ensure();
    final cleaned = name.trim();
    if (cleaned.isEmpty) return;
    _folders.add(BookmarkFolder(id: 'folder_${DateTime.now().microsecondsSinceEpoch}', name: cleaned));
    await _save();
    notifyListeners();
  }

  Future<void> renameFolder(String id, String name) async {
    await _ensure();
    final cleaned = name.trim();
    if (cleaned.isEmpty) return;
    final index = _folders.indexWhere((e) => e.id == id);
    if (index < 0) return;
    _folders[index] = BookmarkFolder(id: id, name: cleaned);
    await _save();
    notifyListeners();
  }

  Future<void> deleteFolder(String id) async {
    await _ensure();
    if (id == defaultFolderId) return;
    final target = defaultFolderId;
    for (final item in _items.where((e) => e.folderId == id).toList()) {
      final index = _items.indexWhere((e) => e.id == item.id);
      if (index >= 0) {
        _items[index] = BookmarkItem(id: item.id, surahNumber: item.surahNumber, ayahNumber: item.ayahNumber, folderId: target, createdAt: item.createdAt);
      }
    }
    _folders.removeWhere((e) => e.id == id);
    await _save();
    notifyListeners();
  }

  Future<void> remove(String itemId) async {
    await _ensure();
    _items.removeWhere((e) => e.id == itemId);
    await _save();
    notifyListeners();
  }

  Future<void> recordLastRead(int surahNumber, int ayahNumber) async {
    await _ensure();
    _history.removeWhere((e) => e.surahNumber == surahNumber && e.ayahNumber == ayahNumber);
    _history.insert(0, LastReadEntry(surahNumber: surahNumber, ayahNumber: ayahNumber, timestamp: DateTime.now()));
    if (_history.length > 100) _history.removeRange(100, _history.length);
    await _save();
    notifyListeners();
  }

  Future<void> clearHistory() async {
    await _ensure();
    _history.clear();
    await _save();
    notifyListeners();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await _saveFolders(prefs);
    await prefs.setStringList(_itemsKey, _items.map((e) => jsonEncode(e.toJson())).toList());
    await prefs.setStringList(_historyKey, _history.map((e) => jsonEncode(e.toJson())).toList());
  }

  Future<void> _saveFolders(SharedPreferences prefs) async {
    await prefs.setStringList(_foldersKey, _folders.map((e) => jsonEncode(e.toJson())).toList());
  }
}
