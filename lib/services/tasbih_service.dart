import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/dhikr.dart';

class TasbihService extends ChangeNotifier {
  static final TasbihService _instance = TasbihService._internal();
  factory TasbihService() => _instance;
  TasbihService._internal();

  static const _keyList = 'tasbih_dhikr_list';
  static const _keyCurrentId = 'tasbih_current_id';
  static const _keyVibration = 'tasbih_vibration';
  static const _keyAutoAdvance = 'tasbih_auto_advance';
  static const _keyKeepScreenOn = 'tasbih_keep_screen_on';

  List<Dhikr> _items = [];
  String? _currentId;
  bool _vibration = true;
  bool _autoAdvance = true;
  bool _keepScreenOn = true;
  bool _initialized = false;
  _TasbihUndo? _lastUndo;

  List<Dhikr> get items => List.unmodifiable(_items);
  Dhikr? get current =>
      _items.where((e) => e.id == _currentId).firstOrNull ??
      (_items.isNotEmpty ? _items.first : null);
  bool get vibration => _vibration;
  bool get autoAdvance => _autoAdvance;
  bool get keepScreenOn => _keepScreenOn;
  bool get isInitialized => _initialized;

  Future<void> init() async {
    if (_initialized) return;
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_keyList);
    if (raw != null && raw.isNotEmpty) {
      _items = Dhikr.decodeList(raw);
    } else {
      _items = _defaultPresets();
      await _persist();
    }
    _currentId =
        p.getString(_keyCurrentId) ??
        (_items.isNotEmpty ? _items.first.id : null);
    _vibration = p.getBool(_keyVibration) ?? true;
    _autoAdvance = p.getBool(_keyAutoAdvance) ?? true;
    _keepScreenOn = p.getBool(_keyKeepScreenOn) ?? true;
    _initialized = true;
    notifyListeners();
  }

  List<Dhikr> _defaultPresets() {
    final now = DateTime.now();
    return [
      Dhikr(
        id: '1',
        arabic: 'سُبْحَانَ اللهِ',
        latin: 'Subhanallah',
        translation: 'Maha Suci Allah',
        translationEn: 'Glory be to Allah',
        category: 'dzikir',
        target: 33,
        createdAt: now,
      ),
      Dhikr(
        id: '2',
        arabic: 'الْحَمْدُ لِلَّهِ',
        latin: 'Alhamdulillah',
        translation: 'Segala puji bagi Allah',
        translationEn: 'All praise is for Allah',
        category: 'dzikir',
        target: 33,
        createdAt: now,
      ),
      Dhikr(
        id: '3',
        arabic: 'اللهُ أَكْبَرُ',
        latin: 'Allahu Akbar',
        translation: 'Allah Maha Besar',
        translationEn: 'Allah is the Greatest',
        category: 'dzikir',
        target: 33,
        createdAt: now,
      ),
      Dhikr(
        id: '4',
        arabic: 'أَسْتَغْفِرُ اللهَ',
        latin: 'Astaghfirullah',
        translation: 'Aku memohon ampun kepada Allah',
        translationEn: 'I seek forgiveness from Allah',
        category: 'dzikir',
        target: 33,
        createdAt: now,
      ),
      Dhikr(
        id: '5',
        arabic: 'لَا إِلَٰهَ إِلَّا اللهُ',
        latin: 'La ilaha illallah',
        translation: 'Tiada Tuhan selain Allah',
        translationEn: 'There is no god but Allah',
        category: 'dzikir',
        target: 33,
        createdAt: now,
      ),
      Dhikr(
        id: '6',
        arabic: 'اللَّهُمَّ صَلِّ عَلَى سَيِّدِنَا مُحَمَّدٍ',
        latin: 'Allahumma sholli ala Sayyidina Muhammad',
        translation: 'Ya Allah limpahkan shalawat kepada Nabi Muhammad',
        translationEn:
            'O Allah, send blessings upon our Prophet Muhammad',
        category: 'shalawat',
        target: 33,
        createdAt: now,
      ),
      Dhikr(
        id: '7',
        arabic: 'اللَّهُمَّ صَلِّ عَلَى مُحَمَّدٍ وَعَلَى آلِ مُحَمَّدٍ',
        latin: 'Allahumma sholli ala Muhammad wa ala ali Muhammad',
        translation: 'Shalawat Ibrahimiyah',
        translationEn: 'The Abrahamic prayer of blessings',
        category: 'shalawat',
        target: 33,
        createdAt: now,
      ),
      Dhikr(
        id: '8',
        arabic: 'حَسْبُنَا اللهُ وَنِعْمَ الْوَكِيلُ',
        latin: 'Hasbunallah wa ni\'mal wakil',
        translation: 'Cukuplah Allah sebagai penolong kami',
        translationEn: 'Allah is sufficient for us, and He is the best Guardian',
        category: 'doa',
        target: 33,
        createdAt: now,
      ),
    ];
  }

  Future<void> _persist() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_keyList, Dhikr.encodeList(_items));
    if (_currentId != null) await p.setString(_keyCurrentId, _currentId!);
  }

  Future<void> setCurrent(String id) async {
    _currentId = id;
    final p = await SharedPreferences.getInstance();
    await p.setString(_keyCurrentId, id);
    // update lastUsed
    final idx = _items.indexWhere((e) => e.id == id);
    if (idx != -1) {
      _items[idx] = _items[idx].copyWith(lastUsedAt: DateTime.now());
      await _persist();
    }
    notifyListeners();
  }

  /// Increment the current dhikr. On reaching target the count wraps and,
  /// when [autoAdvance] is on, the current dhikr moves to the next one.
  /// Returns completion info (null when the target was not reached).
  Future<TasbihCompletion?> increment() async {
    final c = current;
    if (c == null) return null;
    final idx = _items.indexWhere((e) => e.id == c.id);
    if (idx == -1) return null;

    final newCount = c.count + 1;
    final completed = c.totalCompleted;
    if (newCount < c.target) {
      _items[idx] = c.copyWith(count: newCount, lastUsedAt: DateTime.now());
      await _persist();
      notifyListeners();
      if (_vibration) {
        if (newCount % 33 == 0 && newCount != 0) {
          HapticFeedback.mediumImpact();
        } else {
          HapticFeedback.selectionClick();
        }
      }
      return null;
    }

    _items[idx] = c.copyWith(
      count: 0,
      totalCompleted: completed + 1,
      lastUsedAt: DateTime.now(),
    );

    Dhikr? next;
    var advanced = false;
    if (_autoAdvance && _items.length > 1) {
      final nextIdx = (idx + 1) % _items.length;
      next = _items[nextIdx];
      _lastUndo = _TasbihUndo(
        completedId: c.id,
        prevCount: c.count,
        prevCompleted: completed,
      );
      _currentId = next.id;
      _items[nextIdx] = next.copyWith(lastUsedAt: DateTime.now());
      advanced = true;
    } else {
      _lastUndo = null;
    }

    await _persist();
    notifyListeners();

    if (_vibration) HapticFeedback.heavyImpact();

    return TasbihCompletion(
      completed: _items[idx],
      next: next,
      autoAdvanced: advanced,
    );
  }

  /// Undo the last auto-advance: back to the completed dhikr with its
  /// pre-completion count. Returns false when there is nothing to undo.
  Future<bool> undoLastCompletion() async {
    final u = _lastUndo;
    if (u == null) return false;
    final ci = _items.indexWhere((e) => e.id == u.completedId);
    if (ci == -1) return false;
    _items[ci] = _items[ci].copyWith(
      count: u.prevCount,
      totalCompleted: u.prevCompleted,
    );
    _currentId = u.completedId;
    _lastUndo = null;
    await _persist();
    notifyListeners();
    return true;
  }

  Future<void> resetCurrent() async {
    final c = current;
    if (c == null) return;
    final idx = _items.indexWhere((e) => e.id == c.id);
    _items[idx] = c.copyWith(count: 0);
    await _persist();
    notifyListeners();
    if (_vibration) HapticFeedback.lightImpact();
  }

  Future<void> resetAll() async {
    for (var i = 0; i < _items.length; i++) {
      _items[i] = _items[i].copyWith(count: 0);
    }
    await _persist();
    notifyListeners();
  }

  Future<void> addCustom({
    required String arabic,
    String latin = '',
    String translation = '',
    String category = 'custom',
    int target = 33,
  }) async {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final d = Dhikr(
      id: id,
      arabic: arabic,
      latin: latin,
      translation: translation,
      category: category,
      target: target,
    );
    _items.insert(0, d);
    _currentId = id;
    await _persist();
    notifyListeners();
  }

  Future<void> updateDhikr(Dhikr updated) async {
    final idx = _items.indexWhere((e) => e.id == updated.id);
    if (idx == -1) return;
    _items[idx] = updated;
    await _persist();
    notifyListeners();
  }

  Future<void> delete(String id) async {
    _items.removeWhere((e) => e.id == id);
    if (_currentId == id) {
      _currentId = _items.isNotEmpty ? _items.first.id : null;
    }
    await _persist();
    if (_currentId != null) {
      final p = await SharedPreferences.getInstance();
      await p.setString(_keyCurrentId, _currentId!);
    }
    notifyListeners();
  }

  Future<void> setVibration(bool v) async {
    _vibration = v;
    final p = await SharedPreferences.getInstance();
    await p.setBool(_keyVibration, v);
    notifyListeners();
  }

  Future<void> setAutoAdvance(bool v) async {
    _autoAdvance = v;
    if (!v) _lastUndo = null;
    final p = await SharedPreferences.getInstance();
    await p.setBool(_keyAutoAdvance, v);
    notifyListeners();
  }

  Future<void> setKeepScreenOn(bool v) async {
    _keepScreenOn = v;
    final p = await SharedPreferences.getInstance();
    await p.setBool(_keyKeepScreenOn, v);
    notifyListeners();
  }

  int get progressPercent {
    final c = current;
    if (c == null || c.target == 0) return 0;
    return ((c.count / c.target) * 100).round().clamp(0, 100);
  }
}

/// Info about a reached dhikr target.
class TasbihCompletion {
  final Dhikr completed;
  final Dhikr? next;
  final bool autoAdvanced;

  const TasbihCompletion({
    required this.completed,
    this.next,
    required this.autoAdvanced,
  });
}

class _TasbihUndo {
  final String completedId;
  final int prevCount;
  final int prevCompleted;

  const _TasbihUndo({
    required this.completedId,
    required this.prevCount,
    required this.prevCompleted,
  });
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
