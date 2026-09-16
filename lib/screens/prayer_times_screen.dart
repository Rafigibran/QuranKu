import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../models/prayer_times.dart';
import '../services/api_service.dart';
import '../services/adhan_service.dart';
import '../services/gps_prayer_service.dart';
import '../l10n/l10n.dart';
import '../utils/formatters.dart';
import '../utils/hijri.dart';
import 'imsakiyah_screen.dart';
import 'settings_screen.dart';
import '../services/settings_service.dart';
import '../services/audio_service.dart';
import '../services/widget_service.dart';
import '../widgets/liquid_glass.dart';
import 'package:quranku/l10n/app_localizations.dart';

class PrayerTimesScreen extends StatefulWidget {
  const PrayerTimesScreen({super.key});

  @override
  State<PrayerTimesScreen> createState() => _PrayerTimesScreenState();
}

class _PrayerTimesScreenState extends State<PrayerTimesScreen> {
  List<dynamic> _locations = [];
  String? _selectedProvince;
  String? _selectedCity;
  List<String> _cities = [];

  PrayerTimes? _todayPrayerTimes;
  bool _isLoading = true;
  String? _errorMessage;
  DateTime _selectedDate = DateTime.now();

  bool _gpsMode = false;
  double? _gpsLat;
  double? _gpsLon;
  String? _gpsLabel;
  String? _methodLabel;
  bool _gpsLoading = false;

  bool _worldMode = false;
  double? _worldLat;
  double? _worldLon;
  String? _worldName;

  final SettingsService _settings = SettingsService();
  final AudioService _audioService = AudioService();
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _settings.addListener(_onSettingsChanged);
    _audioService.addListener(_onAudioChanged);
    AdhanService().init();
    _loadLocationData();
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted && _todayPrayerTimes != null) setState(() {});
    });
  }

  Map<String, String> _adhanTimes() {
    final t = _todayPrayerTimes;
    if (t == null) return const {};
    return {
      'subuh': t.subuh,
      'dzuhur': t.dzuhur,
      'ashar': t.ashar,
      'maghrib': t.maghrib,
      'isya': t.isya,
    };
  }

  Future<void> _rescheduleAdhan() async {
    final times = _adhanTimes();
    if (times.isNotEmpty) await AdhanService().schedulePrayers(times);
  }

  Future<void> _openPrayerModeSheet(String prayerKey, String title) async {
    final adhan = AdhanService();
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          final scheme = Theme.of(ctx).colorScheme;
          final current = adhan.prayerMode(prayerKey);
          return SafeArea(
            child: Container(
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: scheme.outline.withValues(alpha: .35),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Pengingat $title',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    context.l10n.prayerAdhanSubtitle,
                    style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 8),
                  for (final m in AdhanMode.values)
                    RadioListTile<AdhanMode>(
                      contentPadding: EdgeInsets.zero,
                      value: m,
                      groupValue: current,
                      secondary: Icon(
                        AdhanService.modeIcon(m),
                        color: m == AdhanMode.off ? scheme.outline : scheme.primary,
                      ),
                      title: Text(AdhanService.modeLabel(m)),
                      onChanged: (v) async {
                        if (v == null) return;
                        await adhan.setPrayerMode(prayerKey, v);
                        setSheet(() {});
                        setState(() {});
                        await _rescheduleAdhan();
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                    ),
                  const SizedBox(height: 4),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => adhan.preview(current, prayerKey == 'Subuh'),
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: Text(
                        current == AdhanMode.fullAdhan && prayerKey == 'Subuh'
                            ? context.l10n.prayerAdhanTestFajr
                            : context.l10n.prayerAdhanTest,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    await adhan.stopAdhan();
  }

  Future<void> _openAdhanGlobalSheet() async {
    final adhan = AdhanService();
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          final scheme = Theme.of(ctx).colorScheme;
          return SafeArea(
            child: Container(
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: scheme.outline.withValues(alpha: .35),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    context.l10n.prayerAdhanSettings,
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: Text(context.l10n.prayerAdhanEnable),
                    value: adhan.enabled,
                    onChanged: (v) async {
                      await adhan.setEnabled(v);
                      setSheet(() {});
                      setState(() {});
                      await _rescheduleAdhan();
                    },
                  ),
                  Text(
                    context.l10n.prayerAdhanMuezzin,
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: RadioListTile<Muezzin>(
                          contentPadding: EdgeInsets.zero,
                          title: Text(context.l10n.prayerAdhanMakkah),
                          value: Muezzin.makkah,
                          groupValue: adhan.muezzin,
                          onChanged: (v) async {
                            if (v == null) return;
                            await adhan.setMuezzin(v);
                            setSheet(() {});
                          },
                        ),
                      ),
                      Expanded(
                        child: RadioListTile<Muezzin>(
                          contentPadding: EdgeInsets.zero,
                          title: Text(context.l10n.prayerAdhanMadinah),
                          value: Muezzin.madinah,
                          groupValue: adhan.muezzin,
                          onChanged: (v) async {
                            if (v == null) return;
                            await adhan.setMuezzin(v);
                            setSheet(() {});
                          },
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(child: Text(context.l10n.prayerAdhanVolume)),
                      Expanded(
                        child: Slider(
                          value: adhan.volume,
                          onChanged: (v) async {
                            await adhan.setVolume(v);
                            setSheet(() {});
                          },
                        ),
                      ),
                      SizedBox(
                        width: 44,
                        child: Text('${(adhan.volume * 100).round()}%',
                            textAlign: TextAlign.end),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _loadLocationData() async {
    try {
      final String jsonString =
          await DefaultAssetBundle.of(context).loadString('assets/loc_indonesian.json');
      setState(() => _locations = json.decode(jsonString));
      await _loadSavedLocation();
    } catch (e) {
      debugPrint('Error loading location data: $e');
      setState(() {
        _errorMessage = AppLocalizations.of(context)!.prayerLoadFailed;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadSavedLocation() async {
    final prefs = await SharedPreferences.getInstance();
    final mode = prefs.getString('location_mode');
    if (mode == 'gps') {
      final lat = prefs.getDouble('gps_lat');
      final lon = prefs.getDouble('gps_lon');
      if (lat != null && lon != null) {
        _gpsMode = true;
        _worldMode = false;
        _gpsLat = lat;
        _gpsLon = lon;
        _gpsLabel = prefs.getString('gps_place') ?? 'GPS ${GpsPrayerService.coordsLabel(lat, lon)}';
        _methodLabel = GpsPrayerService.methodLabel(lat, lon);
      }
      _useGpsLocation(background: true);
      if (_gpsLat != null) {
        _fetchGpsTimes();
        return;
      }
    } else if (mode == 'world') {
      final lat = prefs.getDouble('world_lat');
      final lon = prefs.getDouble('world_lon');
      final name = prefs.getString('world_name');
      if (lat != null && lon != null && name != null) {
        _gpsMode = false;
        _worldMode = true;
        _worldLat = lat;
        _worldLon = lon;
        _worldName = name;
        _methodLabel = GpsPrayerService.methodLabel(lat, lon);
        _fetchWorldTimes();
        return;
      }
    }
    final savedProvince = prefs.getString('saved_province');
    final savedCity = prefs.getString('saved_city');
    if (savedProvince != null && savedCity != null) {
      final provinceData = _locations.firstWhere(
        (e) => e['provinsi'] == savedProvince,
        orElse: () => null,
      );
      if (provinceData != null) {
        final cities = List<String>.from(provinceData['kota_kabupaten']);
        if (cities.contains(savedCity)) {
          if (mounted) {
            setState(() {
              _selectedProvince = savedProvince;
              _cities = cities;
              _selectedCity = savedCity;
            });
            _fetchPrayerTimes();
            return;
          }
        }
      }
    }
    final jakartaData = _locations.firstWhere(
      (e) => e['provinsi'] == 'DKI Jakarta',
      orElse: () => null,
    );
    if (jakartaData != null) {
      if (mounted) {
        setState(() {
          _selectedProvince = 'DKI Jakarta';
          _cities = List<String>.from(jakartaData['kota_kabupaten']);
          _selectedCity = 'Kota Jakarta';
        });
        _fetchPrayerTimes();
      }
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showLocationDialog() async {
    String? tempProvince = _selectedProvince ?? "DKI Jakarta";
    String? tempCity = _selectedCity ?? "Kota Jakarta";
    if (_cities.isEmpty && _locations.isNotEmpty) {
      final provinceData = _locations.firstWhere(
        (e) => e['provinsi'] == tempProvince,
        orElse: () => null,
      );
      if (provinceData != null) _cities = List<String>.from(provinceData['kota_kabupaten']);
    }
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        final scheme = Theme.of(context).colorScheme;
        final worldCtrl = TextEditingController();
        List<Map<String, dynamic>> worldResults = [];
        bool worldSearching = false;
        String? worldError;
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            Future<void> doWorldSearch() async {
              final q = worldCtrl.text.trim();
              if (q.length < 2) return;
              setStateDialog(() {
                worldSearching = true;
                worldError = null;
              });
              try {
                final r = await GpsPrayerService.searchCity(q);
                setStateDialog(() {
                  worldResults = r;
                  if (r.isEmpty) worldError = context.l10n.prayerWorldNotFound;
                });
              } catch (e) {
                setStateDialog(() => worldError = context.l10n.prayerWorldOffline('$e'));
              } finally {
                setStateDialog(() => worldSearching = false);
              }
            }

            return AlertDialog(
              backgroundColor: scheme.surfaceContainer,
              shape: RoundedRectangleBorder(
                side: BorderSide(color: scheme.outlineVariant),
                borderRadius: BorderRadius.circular(24),
              ),
              title: Text(
                context.l10n.prayerSelectLocation,
                style: TextStyle(color: scheme.onSurface, fontWeight: FontWeight.w800),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: worldCtrl,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => doWorldSearch(),
                      decoration: InputDecoration(
                        hintText: context.l10n.prayerWorldSearchHint,
                        prefixIcon: const Icon(Icons.public_rounded, size: 20),
                        suffixIcon: worldSearching
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox(
                                    width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                              )
                            : IconButton(
                                icon: const Icon(Icons.search_rounded),
                                onPressed: doWorldSearch,
                              ),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                        isDense: true,
                      ),
                    ),
                    if (worldError != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(worldError!, style: TextStyle(fontSize: 12, color: scheme.error)),
                      ),
                    if (worldResults.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Container(
                        constraints: const BoxConstraints(maxHeight: 180),
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerLow,
                          border: Border.all(color: scheme.outlineVariant),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: worldResults.length,
                          separatorBuilder: (_, __) =>
                              Divider(height: 1, color: scheme.outlineVariant.withValues(alpha: .5)),
                          itemBuilder: (_, i) {
                            final m = worldResults[i];
                            return ListTile(
                              dense: true,
                              title: Text(GpsPrayerService.worldLabel(m),
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                              subtitle: Text(
                                  '${(m['lat'] as double).toStringAsFixed(3)}, ${(m['lon'] as double).toStringAsFixed(3)}',
                                  style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                              onTap: () {
                                Navigator.of(context).pop();
                                _useWorldPlace(m);
                              },
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 10),
                      Center(
                        child: Text(
                          context.l10n.prayerOrPickIndonesia,
                          style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ] else
                      const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      value: tempProvince,
                      decoration: InputDecoration(
                        labelText: context.l10n.prayerProvince,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                        isDense: true,
                      ),
                      items: _locations.map<DropdownMenuItem<String>>((dynamic item) {
                        return DropdownMenuItem<String>(
                          value: item['provinsi'] as String,
                          child: Text(item['provinsi'] as String, style: const TextStyle(fontSize: 14)),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val == null) return;
                        final provinceData = _locations.firstWhere((e) => e['provinsi'] == val);
                        setStateDialog(() {
                          tempProvince = val;
                          _cities = List<String>.from(provinceData['kota_kabupaten']);
                          tempCity = null;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: tempCity,
                      decoration: InputDecoration(
                        labelText: context.l10n.prayerCity,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                        isDense: true,
                      ),
                      items: _cities
                          .map<DropdownMenuItem<String>>((String value) => DropdownMenuItem<String>(
                                value: value,
                                child: Text(value, style: const TextStyle(fontSize: 14)),
                              ))
                          .toList(),
                      onChanged: (val) => setStateDialog(() => tempCity = val),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(AppLocalizations.of(context)!.commonCancel),
                ),
                FilledButton(
                  onPressed: (tempProvince != null && tempCity != null)
                      ? () async {
                          setState(() {
                            _selectedProvince = tempProvince;
                            _selectedCity = tempCity;
                          });
                          Navigator.of(context).pop();
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.setString('location_mode', 'manual');
                          setState(() {
                            _gpsMode = false;
                            _worldMode = false;
                          });
                          _saveLocation();
                          _fetchPrayerTimes();
                        }
                      : null,
                  child: Text(AppLocalizations.of(context)!.commonSave),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _saveLocation() async {
    if (_selectedProvince != null && _selectedCity != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('saved_province', _selectedProvince!);
      await prefs.setString('saved_city', _selectedCity!);
    }
  }

  Future<void> _useGpsLocation({bool background = false}) async {
    if (!background) setState(() => _gpsLoading = true);
    try {
      final pos = await GpsPrayerService.currentPosition();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('location_mode', 'gps');
      await prefs.setDouble('gps_lat', pos.latitude);
      await prefs.setDouble('gps_lon', pos.longitude);
      if (!mounted) return;
      setState(() {
        _gpsMode = true;
        _worldMode = false;
        _gpsLat = pos.latitude;
        _gpsLon = pos.longitude;
        _gpsLabel = 'GPS ${GpsPrayerService.coordsLabel(pos.latitude, pos.longitude)}';
        _methodLabel = GpsPrayerService.methodLabel(pos.latitude, pos.longitude);
      });
      _fetchGpsTimes();
      GpsPrayerService.placeName(pos.latitude, pos.longitude).then((name) async {
        if (name == null || !mounted) return;
        final p = await SharedPreferences.getInstance();
        await p.setString('gps_place', name);
        if (!mounted || !_gpsMode) return;
        setState(() => _gpsLabel = name);
      });
    } catch (e) {
      if (!mounted) return;
      if (_gpsLat == null) {
        setState(() {
          _gpsMode = false;
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_errorMessage ?? context.l10n.prayerGpsFailed)));
      } else {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(context.l10n.prayerGpsStale)));
      }
    } finally {
      if (mounted) setState(() => _gpsLoading = false);
    }
  }

  Future<void> _useManualLocation() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('location_mode', 'manual');
    if (!mounted) return;
    setState(() {
      _gpsMode = false;
      _worldMode = false;
    });
    _fetchPrayerTimes();
  }

  Future<void> _useWorldPlace(Map<String, dynamic> m) async {
    final lat = m['lat'] as double;
    final lon = m['lon'] as double;
    final name = GpsPrayerService.worldLabel(m);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('location_mode', 'world');
    await prefs.setDouble('world_lat', lat);
    await prefs.setDouble('world_lon', lon);
    await prefs.setString('world_name', name);
    if (!mounted) return;
    setState(() {
      _gpsMode = false;
      _worldMode = true;
      _worldLat = lat;
      _worldLon = lon;
      _worldName = name;
      _methodLabel = GpsPrayerService.methodLabel(lat, lon);
    });
    _fetchWorldTimes();
  }

  void _fetchWorldTimes() {
    if (_worldLat == null || _worldLon == null) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final t = GpsPrayerService.daily(_worldLat!, _worldLon!, _selectedDate);
      setState(() {
        _todayPrayerTimes = t;
        _methodLabel = GpsPrayerService.methodLabel(_worldLat!, _worldLon!);
      });
      _updateWidgets(t);
      AdhanService()
          .schedulePrayers({'subuh': t.subuh, 'dzuhur': t.dzuhur, 'ashar': t.ashar, 'maghrib': t.maghrib, 'isya': t.isya})
          .catchError((_) {});
    } catch (e) {
      setState(() => _errorMessage = AppLocalizations.of(context)!.prayerLoadFailed);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _fetchGpsTimes() {
    if (_gpsLat == null || _gpsLon == null) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final t = GpsPrayerService.daily(_gpsLat!, _gpsLon!, _selectedDate);
      setState(() {
        _todayPrayerTimes = t;
        _methodLabel = GpsPrayerService.methodLabel(_gpsLat!, _gpsLon!);
      });
      _updateWidgets(t);
      AdhanService()
          .schedulePrayers({'subuh': t.subuh, 'dzuhur': t.dzuhur, 'ashar': t.ashar, 'maghrib': t.maghrib, 'isya': t.isya})
          .catchError((_) {});
    } catch (e) {
      setState(() => _errorMessage = AppLocalizations.of(context)!.prayerLoadFailed);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchPrayerTimes() async {
    if (_gpsMode) {
      _fetchGpsTimes();
      return;
    }
    if (_worldMode) {
      _fetchWorldTimes();
      return;
    }
    if (_selectedProvince == null || _selectedCity == null) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final schedule = await ApiService().fetchPrayerSchedule(_selectedProvince!, _selectedCity!, date: _selectedDate);
      final String dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final todayData = schedule.firstWhere((element) => element['tanggal_lengkap'] == dateStr, orElse: () => {});
      if (todayData.isNotEmpty) {
        final prayerTimes = PrayerTimes.fromJson(todayData);
        setState(() => _todayPrayerTimes = prayerTimes);
        _updateWidgets(prayerTimes);
        try {
          await AdhanService().schedulePrayers({
            'subuh': prayerTimes.subuh,
            'dzuhur': prayerTimes.dzuhur,
            'ashar': prayerTimes.ashar,
            'maghrib': prayerTimes.maghrib,
            'isya': prayerTimes.isya,
          });
        } catch (_) {}
      } else {
        setState(() {
          _errorMessage = AppLocalizations.of(context)!.prayerLoadFailed;
          _todayPrayerTimes = null;
        });
      }
    } catch (e) {
      setState(() => _errorMessage = AppLocalizations.of(context)!.prayerLoadFailed);
      debugPrint("API Error: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _settings.removeListener(_onSettingsChanged);
    _audioService.removeListener(_onAudioChanged);
    super.dispose();
  }

  void _onSettingsChanged() {
    if (mounted) setState(() {});
  }

  void _onAudioChanged() {
    if (mounted) setState(() {});
  }

  void _updateWidgets(PrayerTimes prayerTimes) {
    final now = DateTime.now();
    final timesMap = {
      'Imsak': prayerTimes.imsak,
      'Subuh': prayerTimes.subuh,
      'Dzuhur': prayerTimes.dzuhur,
      'Ashar': prayerTimes.ashar,
      'Maghrib': prayerTimes.maghrib,
      'Isya': prayerTimes.isya,
    };
    String nextName = 'Imsak';
    String nextTime = prayerTimes.imsak;
    for (var entry in timesMap.entries) {
      final t = entry.value.split(':');
      final prayerTime = DateTime(now.year, now.month, now.day, int.parse(t[0]), int.parse(t[1]));
      if (prayerTime.isAfter(now)) {
        nextName = entry.key;
        nextTime = entry.value;
        break;
      }
    }
    WidgetService.updatePrayerWidgets(
      location: _selectedCity ?? _worldName ?? _gpsLabel ?? 'Jakarta',
      prayerTimes: timesMap,
      nextPrayerName: nextName,
      nextPrayerTime: nextTime,
    );
  }

  // Helpers for UI

  bool get _isTodaySelected => DateUtils.isSameDay(_selectedDate, DateTime.now());

  Map<String, String> get _orderedTimes {
    final t = _todayPrayerTimes;
    if (t == null) return {};
    return {
      'Imsak': t.imsak,
      'Subuh': t.subuh,
      'Dhuha': t.dhuha,
      'Dzuhur': t.dzuhur,
      'Ashar': t.ashar,
      'Maghrib': t.maghrib,
      'Isya': t.isya,
    };
  }

  String? _nextPrayerKey() {
    if (_todayPrayerTimes == null || !_isTodaySelected) return null;
    final now = DateTime.now();
    for (final e in _orderedTimes.entries) {
      if (e.value.isEmpty) continue;
      if (e.key == 'Imsak' || e.key == 'Dhuha') continue;
      final parts = e.value.split(':');
      final h = int.tryParse(parts[0]) ?? 0;
      final m = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
      final dt = DateTime(now.year, now.month, now.day, h, m);
      if (dt.isAfter(now)) return e.key;
    }
    return null;
  }

  String _countdownTo(String hhmm) {
    final now = DateTime.now();
    final p = hhmm.split(':');
    final h = int.tryParse(p[0]) ?? 0;
    final m = p.length > 1 ? int.tryParse(p[1]) ?? 0 : 0;
    var target = DateTime(now.year, now.month, now.day, h, m);
    if (target.isBefore(now)) target = target.add(const Duration(days: 1));
    final d = target.difference(now);
    final hours = d.inHours;
    final mins = d.inMinutes % 60;
    if (hours > 0) return context.l10n.prayerCountdown(hours, mins);
    return context.l10n.prayerCountdownMinutes(mins);
  }

  double _dayProgress() {
    final t = _todayPrayerTimes;
    if (t == null) return 0;
    try {
      DateTime parse(String s) {
        final p = s.split(':');
        final now = DateTime.now();
        return DateTime(now.year, now.month, now.day, int.parse(p[0]), int.parse(p[1]));
      }

      final start = parse(t.subuh);
      final end = parse(t.isya);
      final now = DateTime.now();
      final total = end.difference(start).inMinutes;
      if (total <= 0) return 0;
      final elapsed = now.difference(start).inMinutes.clamp(0, total);
      return elapsed / total;
    } catch (_) {
      return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_errorMessage != null) return _buildErrorOverlay();
    final scheme = Theme.of(context).colorScheme;
    if (_isLoading) {
      return Scaffold(
        backgroundColor: scheme.surface,
        appBar: _buildAppBar(scheme),
        body: Center(child: CircularProgressIndicator(color: scheme.primary)),
      );
    }
    if (_todayPrayerTimes == null) {
      return Scaffold(
        backgroundColor: scheme.surface,
        appBar: _buildAppBar(scheme),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.location_on_outlined, size: 48, color: scheme.outline),
                const SizedBox(height: 16),
                Text(
                  AppLocalizations.of(context)!.prayerSetLocation,
                  style: TextStyle(color: scheme.onSurface, fontWeight: FontWeight.w700),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _showLocationDialog,
                  icon: const Icon(Icons.location_on_rounded),
                  label: Text(AppLocalizations.of(context)!.prayerSetLocation),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: _buildAppBar(scheme),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeaderCard(scheme),
            const SizedBox(height: 14),
            if (_isTodaySelected) _buildNextPrayerCard(scheme),
            if (_isTodaySelected) const SizedBox(height: 14),
            _buildScheduleCard(scheme),
            const SizedBox(height: 12),
            _buildFooterActions(scheme),
            if (_audioService.currentSurah != null) const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(ColorScheme scheme) {
    return AppBar(
      title: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: context.l10n.prayerScheduleTitle,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 20,
                color: scheme.onSurface,
                letterSpacing: -0.4,
              ),
            ),
            TextSpan(
              text: '.',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20, color: scheme.primary),
            ),
          ],
        ),
      ),
      centerTitle: false,
      backgroundColor: scheme.surface,
      scrolledUnderElevation: 0,
      elevation: 0,
      automaticallyImplyLeading: false,
      actions: [
        IconButton(
          tooltip: context.l10n.prayerAdhanSettings,
          onPressed: _openAdhanGlobalSheet,
          icon: Icon(Icons.notifications_none_rounded, color: scheme.onSurfaceVariant),
        ),
        IconButton(
          tooltip: 'Pengaturan',
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
          icon: Icon(Icons.settings_outlined, color: scheme.onSurfaceVariant),
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  Widget _buildHeaderCard(ColorScheme scheme) {
    final localeTag = localeTagOf(context);
    final h = hijriToday(
      date: _selectedDate,
      languageCode: Localizations.localeOf(context).languageCode,
    );
    final dayName = DateFormat('EEEE', localeTag).format(_selectedDate);
    final dayNum = _settings.formatString(DateFormat('d', localeTag).format(_selectedDate));
    final monthYear = _settings.formatString(DateFormat('MMMM yyyy', localeTag).format(_selectedDate));
    final locationLabel = _gpsMode
        ? (_gpsLabel ?? 'GPS')
        : _worldMode
            ? (_worldName ?? context.l10n.prayerWorldCity)
            : '${_selectedCity ?? ''}, ${_selectedProvince ?? ''}';

    return LiquidGlassCard(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                dayName,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: scheme.primary,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: .10),
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(color: scheme.primary.withValues(alpha: .18)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.nightlight_round, size: 14, color: scheme.primary),
                    const SizedBox(width: 6),
                    Text(h.full,
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: scheme.primary)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                dayNum,
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  height: 1.0,
                  letterSpacing: -1.2,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  monthYear,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: scheme.onSurfaceVariant),
                ),
              ),
              if (h.isRamadan || h.isEidFitr || h.isEidAdha || h.isArafah)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: scheme.tertiary.withValues(alpha: .14),
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(color: scheme.tertiary.withValues(alpha: .28)),
                  ),
                  child: Text(
                    h.isEidFitr
                        ? context.l10n.prayerEidFitr
                        : h.isEidAdha
                        ? context.l10n.prayerEidAdha
                        : h.isArafah
                        ? context.l10n.prayerArafah
                        : context.l10n.prayerRamadan,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: scheme.tertiary),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Divider(height: 1, color: scheme.outlineVariant),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _gpsMode || _worldMode ? scheme.primary.withValues(alpha: .12) : scheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: scheme.outlineVariant),
                ),
                child: Icon(
                  _gpsMode ? Icons.gps_fixed_rounded : Icons.location_on_rounded,
                  size: 18,
                  color: _gpsMode || _worldMode ? scheme.primary : scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(locationLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: scheme.onSurface)),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        if (_methodLabel != null && (_gpsMode || _worldMode))
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: scheme.primary.withValues(alpha: .10),
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: Text(_methodLabel!,
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: scheme.primary)),
                          ),
                        if (_methodLabel != null && (_gpsMode || _worldMode)) const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            _gpsMode
                                ? context.l10n.prayerOfflineGps
                                : _worldMode
                                    ? context.l10n.prayerOfflineCity
                                    : context.l10n.prayerScheduleKemenag,
                            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_gpsMode || _worldMode)
            Padding(
              padding: const EdgeInsets.only(top: 8, left: 46),
              child: Text(
                'Imsak = Subuh -10 mnt  •  Dhuha = Syuruk +30 mnt',
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant.withValues(alpha: .85)),
              ),
            ),
          const SizedBox(height: 14),
          SegmentedButton<bool>(
            segments: [
              ButtonSegment<bool>(
                value: true,
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_gpsLoading)
                      SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: scheme.primary))
                    else
                      Icon(Icons.gps_fixed_rounded, size: 16, color: _gpsMode ? scheme.primary : scheme.onSurfaceVariant),
                    const SizedBox(width: 6),
                    const Text('GPS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              const ButtonSegment<bool>(
                value: false,
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.list_rounded, size: 16),
                    SizedBox(width: 6),
                    Text('Manual', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ],
            selected: {_gpsMode},
            onSelectionChanged: (s) {
              if (s.first) {
                _useGpsLocation();
              } else {
                _useManualLocation();
              }
            },
            showSelectedIcon: false,
            style: ButtonStyle(
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (picked != null && picked != _selectedDate) {
                      setState(() => _selectedDate = picked);
                      _fetchPrayerTimes();
                    }
                  },
                  icon: Icon(Icons.calendar_today_rounded, size: 16, color: scheme.onSurface),
                  label: Text(context.l10n.prayerDate, style: TextStyle(color: scheme.onSurface, fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 44),
                    side: BorderSide(color: scheme.outlineVariant),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    backgroundColor: scheme.surfaceContainerHighest.withValues(alpha: .6),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _showLocationDialog,
                  icon: Icon(Icons.map_outlined, size: 16, color: scheme.onSurface),
                  label: Text(context.l10n.prayerLocation, style: TextStyle(color: scheme.onSurface, fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 44),
                    side: BorderSide(color: scheme.outlineVariant),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    backgroundColor: scheme.surfaceContainerHighest.withValues(alpha: .6),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNextPrayerCard(ColorScheme scheme) {
    final nextKey = _nextPrayerKey();
    final times = _orderedTimes;
    final isDone = nextKey == null;
    if (isDone) {
      return LiquidGlassCard(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: scheme.tertiary.withValues(alpha: .14),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: scheme.tertiary.withValues(alpha: .22)),
              ),
              child: Icon(Icons.check_rounded, color: scheme.tertiary, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(AppLocalizations.of(context)!.prayerAllPassed,
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: scheme.onSurface)),
                  const SizedBox(height: 2),
                  Text(AppLocalizations.of(context)!.prayerAllPassedDesc(_settings.formatString(_orderedTimes['Subuh'] ?? '')),
                      style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                ],
              ),
            ),
          ],
        ),
      );
    }
    final nextTime = times[nextKey] ?? '';
    final countdown = _countdownTo(nextTime);
    final progress = _dayProgress();

    return LiquidGlassCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
            decoration: BoxDecoration(
              color: scheme.tertiary.withValues(alpha: .08),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
              border: Border(bottom: BorderSide(color: scheme.tertiary.withValues(alpha: .12))),
            ),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: scheme.tertiary, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Text(
                  AppLocalizations.of(context)!.prayerNext,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: scheme.tertiary,
                  ),
                ),
                const Spacer(),
                Text(countdown,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: scheme.tertiary)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(nextKey,
                          style: TextStyle(
                              fontSize: 28, fontWeight: FontWeight.w800, height: 1.0, color: scheme.onSurface, letterSpacing: -0.6)),
                      const SizedBox(height: 4),
                      Text(AppLocalizations.of(context)!.prayerTimeUpcoming(_settings.formatString(nextTime)),
                          style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: scheme.outlineVariant),
                  ),
                  child: Text(
                    _settings.formatString(nextTime),
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: scheme.onSurface, letterSpacing: -0.4),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(AppLocalizations.of(context)!.prayerProgress, style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                    const Spacer(),
                    Text('${(progress * 100).round()}%',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: scheme.onSurfaceVariant)),
                  ],
                ),
                const SizedBox(height: 8),
                ThreadProgress(value: progress),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleCard(ColorScheme scheme) {
    final nextKey = _nextPrayerKey();
    final entries = _orderedTimes.entries.toList();
    return LiquidGlassCard(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
            child: Row(
              children: [
                Text(
                  AppLocalizations.of(context)!.prayerTodaySchedule,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: scheme.onSurfaceVariant),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => (_gpsMode && _gpsLat != null && _gpsLon != null)
                            ? ImsakiyahScreen.gps(
                                lat: _gpsLat!, lon: _gpsLon!, date: _selectedDate, methodLabel: _methodLabel, placeLabel: _gpsLabel)
                            : (_worldMode && _worldLat != null && _worldLon != null)
                                ? ImsakiyahScreen.gps(
                                    lat: _worldLat!, lon: _worldLon!, date: _selectedDate, methodLabel: _methodLabel, placeLabel: _worldName)
                                : ImsakiyahScreen(province: _selectedProvince!, city: _selectedCity!, date: _selectedDate),
                      ),
                    );
                  },
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    minimumSize: const Size(0, 32),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  icon: Icon(Icons.calendar_view_month_rounded, size: 14, color: scheme.primary),
                  label: Text(context.l10n.prayerMonthly, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: scheme.primary)),
                ),
              ],
            ),
          ),
          ...entries.map((e) {
            final label = e.key;
            final time = e.value;
            if (time.isEmpty) return const SizedBox.shrink();
            final isNext = label == nextKey && _isTodaySelected;
            final isPast = _isPast(label, time);
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: _buildPrayerRow(scheme, label: label, time: time, isNext: isNext, isPast: isPast),
            );
          }),
        ],
      ),
    );
  }

  bool _isPast(String label, String time) {
    if (!_isTodaySelected) return false;
    if (label == 'Imsak' || label == 'Dhuha') return false;
    final next = _nextPrayerKey();
    if (next == null) return true;
    final order = ['Subuh', 'Dzuhur', 'Ashar', 'Maghrib', 'Isya'];
    final idxLabel = order.indexOf(label);
    final idxNext = order.indexOf(next);
    if (idxLabel == -1 || idxNext == -1) return false;
    return idxLabel < idxNext;
  }

  /// Display name for a prayer label. The API returns Indonesian labels, and
  /// those same labels are used as internal keys elsewhere — so only the
  /// rendered name is translated.
  static String _prayerDisplayName(AppLocalizations l, String label) {
    switch (label) {
      case 'Imsak':
        return l.prayerImsak;
      case 'Subuh':
        return l.prayerFajr;
      case 'Dhuha':
        return l.prayerDhuha;
      case 'Dzuhur':
        return l.prayerDhuhr;
      case 'Ashar':
        return l.prayerAsr;
      case 'Maghrib':
        return l.prayerMaghrib;
      case 'Isya':
        return l.prayerIsha;
      default:
        return label;
    }
  }

  static const Map<String, String> _prayerKeys = {
    'Subuh': 'Subuh',
    'Dzuhur': 'Dzuhur',
    'Ashar': 'Ashar',
    'Maghrib': 'Maghrib',
    'Isya': 'Isya',
  };

  static const Map<String, IconData> _prayerIcons = {
    'Imsak': Icons.nights_stay_rounded,
    'Subuh': Icons.wb_twilight_rounded,
    'Dhuha': Icons.wb_sunny_rounded,
    'Dzuhur': Icons.light_mode_rounded,
    'Ashar': Icons.wb_sunny_outlined,
    'Maghrib': Icons.nights_stay_outlined,
    'Isya': Icons.dark_mode_rounded,
  };

  Widget _buildPrayerRow(ColorScheme scheme,
      {required String label, required String time, required bool isNext, required bool isPast}) {
    final formatted = _settings.formatString(time);
    final prayerKey = _prayerKeys[label];
    final mode = prayerKey == null ? null : AdhanService().prayerMode(prayerKey);

    final bg = isNext
        ? scheme.primary.withValues(alpha: .08)
        : isPast
            ? scheme.surfaceContainerHigh.withValues(alpha: .5)
            : scheme.surfaceContainerHighest.withValues(alpha: .55);
    final border = isNext ? scheme.primary.withValues(alpha: .22) : scheme.outlineVariant.withValues(alpha: .6);

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isNext
                  ? scheme.primary.withValues(alpha: .14)
                  : isPast
                      ? scheme.surfaceContainerHigh
                      : scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isNext ? scheme.primary.withValues(alpha: .20) : scheme.outlineVariant),
            ),
            child: Icon(
              _prayerIcons[label] ?? Icons.schedule_rounded,
              size: 18,
              color: isNext ? scheme.primary : isPast ? scheme.onSurfaceVariant.withValues(alpha: .6) : scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(_prayerDisplayName(context.l10n, label),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: isNext ? FontWeight.w800 : FontWeight.w600,
                              color: isNext ? scheme.primary : scheme.onSurface)),
                    ),
                    if (isNext) ...[
                      const SizedBox(width: 8),
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: scheme.tertiary.withValues(alpha: .14),
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Text(AppLocalizations.of(context)!.prayerNext,
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: scheme.tertiary)),
                        ),
                      ),
                    ],
                    if (isPast && !isNext) ...[
                      const SizedBox(width: 8),
                      BeadDot(filled: true, size: 7),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  isNext ? AppLocalizations.of(context)!.prayerTimeUpcoming(formatted) : isPast ? AppLocalizations.of(context)!.prayerTimePassed : 'Pengingat ${mode != null ? AdhanService.modeLabel(mode) : 'aktif'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: isNext ? scheme.primary.withValues(alpha: .85) : scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                formatted,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                  color: isNext ? scheme.primary : isPast ? scheme.onSurfaceVariant.withValues(alpha: .7) : scheme.onSurface,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
          if (mode != null) ...[
            const SizedBox(width: 2),
            IconButton(
              tooltip: '${AdhanService.modeLabel(mode)} — atur',
              onPressed: () => _openPrayerModeSheet(prayerKey!, label),
              icon: Icon(
                AdhanService.modeIcon(mode),
                size: 18,
                color: mode == AdhanMode.off ? scheme.outline : scheme.primary,
              ),
              style: IconButton.styleFrom(minimumSize: const Size(40, 40), tapTargetSize: MaterialTapTargetSize.shrinkWrap),
            ),
          ] else
            const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildFooterActions(ColorScheme scheme) {
    return Row(
      children: [
        Expanded(
          child: TextButton.icon(
            onPressed: _openAdhanGlobalSheet,
            icon: Icon(Icons.tune_rounded, size: 16, color: scheme.onSurfaceVariant),
            label: Text(context.l10n.prayerAdhanSettings, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: scheme.onSurfaceVariant)),
            style: TextButton.styleFrom(
              minimumSize: const Size(0, 44),
              backgroundColor: scheme.surfaceContainerHigh.withValues(alpha: .5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _fetchPrayerTimes,
            icon: Icon(Icons.refresh_rounded, size: 16, color: scheme.primary),
            label: Text(context.l10n.commonReload, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: scheme.primary)),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 44),
              side: BorderSide(color: scheme.outlineVariant),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorOverlay() {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: _buildAppBar(scheme),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: scheme.errorContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(Icons.wifi_off_rounded, size: 32, color: scheme.error),
              ),
              const SizedBox(height: 16),
              Text(AppLocalizations.of(context)!.prayerLoadFailed,
                  style: TextStyle(color: scheme.onSurface, fontWeight: FontWeight.w800, fontSize: 16)),
              const SizedBox(height: 8),
              Text(
                _errorMessage ?? context.l10n.commonError,
                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13, height: 1.4),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _fetchPrayerTimes,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(AppLocalizations.of(context)!.prayerRetry),
              ),
              const SizedBox(height: 10),
              TextButton(onPressed: _showLocationDialog, child: Text(AppLocalizations.of(context)!.prayerChangeLocation)),
            ],
          ),
        ),
      ),
    );
  }
}
