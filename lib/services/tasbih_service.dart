import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TasbihItem {
  final String id;
  String title;
  String text;
  int target;
  int count;

  TasbihItem({
    required this.id,
    required this.title,
    required this.text,
    required this.target,
    this.count = 0,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'text': text,
        'target': target,
        'count': count,
      };

  factory TasbihItem.fromJson(Map<String, dynamic> json) => TasbihItem(
        id: json['id']?.toString() ?? DateTime.now().microsecondsSinceEpoch.toString(),
        title: json['title']?.toString() ?? 'Dzikir',
        text: json['text']?.toString() ?? '',
        target: ((json['target'] as num?)?.toInt() ?? 33).clamp(1, 999999).toInt(),
        count: ((json['count'] as num?)?.toInt() ?? 0).clamp(0, 999999).toInt(),
      );
}

class TasbihService extends ChangeNotifier {
  static final TasbihService _instance = TasbihService._internal();
  factory TasbihService() => _instance;
  TasbihService._internal();

  static const _key = 'tasbih_items';
  List<TasbihItem> _items = [];
  bool _initialized = false;

  List<TasbihItem> get items => List.unmodifiable(_items);
  bool get initialized => _initialized;

  Future<void> init() async {
    if (_initialized) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw != null) {
      try {
        final list = jsonDecode(raw) as List<dynamic>;
        _items = list
            .whereType<Map<String, dynamic>>()
            .map(TasbihItem.fromJson)
            .toList();
      } catch (e) {
        debugPrint('Tasbih parse error: $e');
      }
    }
    if (_items.isEmpty) {
      _items = [
        TasbihItem(id: 'subhanallah', title: 'Subhanallah', text: 'سُبْحَانَ اللّٰهِ', target: 33),
        TasbihItem(id: 'alhamdulillah', title: 'Alhamdulillah', text: 'الْحَمْدُ لِلّٰهِ', target: 33),
        TasbihItem(id: 'allahuakbar', title: 'Allahu Akbar', text: 'اللّٰهُ أَكْبَرُ', target: 34),
      ];
      await _save();
    }
    _initialized = true;
    notifyListeners();
  }

  Future<void> add({required String title, required String text, required int target}) async {
    _items.add(TasbihItem(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      title: title.trim(),
      text: text.trim(),
      target: target.clamp(1, 999999).toInt(),
    ));
    await _save();
  }

  Future<void> update(TasbihItem item, {required String title, required String text, required int target}) async {
    item.title = title.trim();
    item.text = text.trim();
    item.target = target.clamp(1, 999999).toInt();
    if (item.count > item.target) item.count = item.target;
    await _save();
  }

  Future<void> remove(TasbihItem item) async {
    _items.removeWhere((e) => e.id == item.id);
    await _save();
  }

  Future<void> increment(TasbihItem item) async {
    if (item.count < item.target) item.count++;
    await _save();
  }

  Future<void> reset(TasbihItem item) async {
    item.count = 0;
    await _save();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(_items.map((e) => e.toJson()).toList()));
    notifyListeners();
  }
}
