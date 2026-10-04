import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/prayer_times.dart';
import '../services/api_service.dart';
import '../services/audio_service.dart';
import '../services/settings_service.dart';
import '../services/widget_service.dart';
import 'imsakiyah_screen.dart';

class PrayerTimesScreen extends StatefulWidget {
  const PrayerTimesScreen({super.key});

  @override
  State<PrayerTimesScreen> createState() => _PrayerTimesScreenState();
}

class _PrayerTimesScreenState extends State<PrayerTimesScreen> {
  List<dynamic> _locations = <dynamic>[];
  String? _selectedProvinsi;
  String? _selectedCity;
  List<String> _cities = <String>[];

  PrayerTimes? _todayPrayerTimes;
  bool _isLoading = true;
  String? _errorMessage;
  DateTime _selectedDate = DateTime.now();

  final SettingsService _settings = SettingsService();
  final AudioService _audioService = AudioService();

  @override
  void initState() {
    super.initState();
    _settings.addListener(_onSettingsChanged);
    _audioService.addListener(_onAudioChanged);
    _loadLokasiData();
  }

  @override
  void dispose() {
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

  Future<void> _loadLokasiData() async {
    try {
      final jsonString = await DefaultAssetBundle.of(context)
          .loadString('assets/loc_indonesian.json');
      final decoded = json.decode(jsonString);

      if (!mounted) return;
      setState(() => _locations = decoded as List<dynamic>);
      await _loadSavedLokasi();
    } catch (e) {
      debugPrint('Error loading location data: $e');
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Gagal memuat data lokasi.';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadSavedLokasi() async {
    final prefs = await SharedPreferences.getInstance();
    final savedProvinsi = prefs.getString('saved_province');
    final savedCity = prefs.getString('saved_city');

    Map<String, dynamic>? provinceData;
    if (savedProvinsi != null) {
      provinceData = _provinceByName(savedProvinsi);
    }

    if (provinceData != null && savedCity != null) {
      final cities = List<String>.from(provinceData['kota_kabupaten'] as List);
      if (cities.contains(savedCity) && mounted) {
        setState(() {
          _selectedProvinsi = savedProvinsi;
          _cities = cities;
          _selectedCity = savedCity;
        });
        await _fetchPrayerTimes();
        return;
      }
    }

    final jakarta = _provinceByName('DKI Jakarta');
    if (jakarta != null && mounted) {
      final cities = List<String>.from(jakarta['kota_kabupaten'] as List);
      setState(() {
        _selectedProvinsi = 'DKI Jakarta';
        _cities = cities;
        _selectedCity = cities.contains('Kota Jakarta')
            ? 'Kota Jakarta'
            : (cities.isNotEmpty ? cities.first : null);
      });
      await _fetchPrayerTimes();
      return;
    }

    if (mounted) setState(() => _isLoading = false);
  }

  Map<String, dynamic>? _provinceByName(String name) {
    for (final item in _locations) {
      if (item is Map && item['provinsi'] == name) {
        return Map<String, dynamic>.from(item);
      }
    }
    return null;
  }

  Future<void> _saveLokasi() async {
    if (_selectedProvinsi == null || _selectedCity == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('saved_province', _selectedProvinsi!);
    await prefs.setString('saved_city', _selectedCity!);
  }

  Future<void> _showLokasiSheet() async {
    String? tempProvinsi = _selectedProvinsi ?? 'DKI Jakarta';
    String? tempCity = _selectedCity ?? 'Kota Jakarta';

    List<String> tempCities = _cities;
    final initialProvinsi = _provinceByName(tempProvinsi!);
    if (tempCities.isEmpty && initialProvinsi != null) {
      tempCities = List<String>.from(initialProvinsi['kota_kabupaten'] as List);
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final scheme = Theme.of(context).colorScheme;
            final isDark = Theme.of(context).brightness == Brightness.dark;

            return Container(
              constraints: const BoxConstraints(maxHeight: 620),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF111B17) : const Color(0xFFFDFCF8),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                border: Border.all(
                  color: scheme.outline.withValues(alpha: 0.35),
                ),
              ),
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  20,
                  16,
                  20,
                  MediaQuery.of(context).viewInsets.bottom + 24,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 42,
                        height: 4,
                        decoration: BoxDecoration(
                          color: scheme.onSurface.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    Text(
                      'Pilih lokasi',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: scheme.onSurface,
                        letterSpacing: -0.7,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Jadwal salat akan diperbarui untuk kota yang dipilih.',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 13,
                        color: scheme.onSurface.withValues(alpha: 0.58),
                      ),
                    ),
                    const SizedBox(height: 22),
                    _buildPickerField(
                      context,
                      label: 'Provinsi',
                      value: tempProvinsi,
                      icon: Icons.map_outlined,
                      items: _locations
                          .whereType<Map>()
                          .map((item) => item['provinsi']?.toString() ?? '')
                          .where((value) => value.isNotEmpty)
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        final province = _provinceByName(value);
                        final cities = province == null
                            ? <String>[]
                            : List<String>.from(
                                province['kota_kabupaten'] as List,
                              );
                        setSheetState(() {
                          tempProvinsi = value;
                          tempCities = cities;
                          tempCity = cities.isNotEmpty ? cities.first : null;
                        });
                      },
                    ),
                    const SizedBox(height: 14),
                    _buildPickerField(
                      context,
                      label: 'Kota / Kabupaten',
                      value: tempCity,
                      icon: Icons.location_city_outlined,
                      items: tempCities,
                      onChanged: (value) {
                        setSheetState(() => tempCity = value);
                      },
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: tempProvinsi != null && tempCity != null
                            ? () {
                                setState(() {
                                  _selectedProvinsi = tempProvinsi;
                                  _selectedCity = tempCity;
                                  _cities = tempCities;
                                  _todayPrayerTimes = null;
                                });
                                Navigator.of(sheetContext).pop();
                                _saveLokasi();
                                _fetchPrayerTimes();
                              }
                            : null,
                        icon: const Icon(Icons.check_rounded),
                        label: const Text('Gunakan lokasi ini'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPickerField(
    BuildContext context, {
    required String label,
    required String? value,
    required IconData icon,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.045)
            : Colors.white.withValues(alpha: 0.80),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.55)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            isExpanded: true,
            value: items.contains(value) ? value : null,
            icon: Icon(Icons.keyboard_arrow_down_rounded, color: scheme.primary),
            dropdownColor: isDark ? const Color(0xFF17211D) : Colors.white,
            borderRadius: BorderRadius.circular(18),
            hint: Row(
              children: [
                Icon(icon, color: scheme.primary, size: 20),
                const SizedBox(width: 10),
                Text(
                  label,
                  style: GoogleFonts.spaceGrotesk(
                    color: scheme.onSurface.withValues(alpha: 0.52),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            selectedItemBuilder: (context) => items
                .map(
                  (item) => Row(
                    children: [
                      Icon(icon, color: scheme.primary, size: 20),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          item,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.spaceGrotesk(
                            color: scheme.onSurface,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
                .toList(),
            items: items
                .map(
                  (item) => DropdownMenuItem<String>(
                    value: item,
                    child: Text(
                      item,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.spaceGrotesk(
                        color: isDark ? Colors.white : const Color(0xFF18201C),
                        fontSize: 14,
                      ),
                    ),
                  ),
                )
                .toList(),
            onChanged: onChanged,
          ),
        ),
      ),
    );
  }

  Future<void> _fetchPrayerTimes() async {
    if (_selectedProvinsi == null || _selectedCity == null) return;

    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final schedule = await ApiService().fetchPrayerSchedule(
        _selectedProvinsi!,
        _selectedCity!,
        date: _selectedDate,
      );
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);

      Map<String, dynamic> todayData = <String, dynamic>{};
      for (final item in schedule) {
        if (item is Map && item['tanggal_lengkap'] == dateStr) {
          todayData = Map<String, dynamic>.from(item);
          break;
        }
      }

      if (todayData.isEmpty) {
        if (!mounted) return;
        setState(() {
          _todayPrayerTimes = null;
          _errorMessage = 'Tidak ada jadwal salat untuk tanggal ini.';
          _isLoading = false;
        });
        return;
      }

      final prayerTimes = PrayerTimes.fromJson(todayData);
      if (!mounted) return;
      setState(() {
        _todayPrayerTimes = prayerTimes;
        _isLoading = false;
      });
      _updateWidgets(prayerTimes);
    } catch (e) {
      debugPrint('API Error: $e');
      if (!mounted) return;
      setState(() {
        _todayPrayerTimes = null;
        _errorMessage = 'Gagal memuat jadwal. Periksa koneksi internet.';
        _isLoading = false;
      });
    }
  }

  void _updateWidgets(PrayerTimes prayerTimes) {
    final now = DateTime.now();
    final timesMap = <String, String>{
      'Imsak': prayerTimes.imsak,
      'Subuh': prayerTimes.subuh,
      'Dzuhur': prayerTimes.dzuhur,
      'Ashar': prayerTimes.ashar,
      'Maghrib': prayerTimes.maghrib,
      'Isya': prayerTimes.isya,
    };

    String nextName = 'Imsak';
    String nextTime = prayerTimes.imsak;

    for (final entry in timesMap.entries) {
      final parts = entry.value.split(':');
      if (parts.length != 2) continue;
      final prayerTime = DateTime(
        now.year,
        now.month,
        now.day,
        int.tryParse(parts[0]) ?? 0,
        int.tryParse(parts[1]) ?? 0,
      );
      if (prayerTime.isAfter(now)) {
        nextName = entry.key;
        nextTime = entry.value;
        break;
      }
    }

    WidgetService.updatePrayerWidgets(
      location: _selectedCity ?? 'Jakarta',
      prayerTimes: timesMap,
      nextPrayerName: nextName,
      nextPrayerTime: nextTime,
    );
  }

  String _formatDate(BuildContext context) {
    final day = _settings.formatString(DateFormat('d').format(_selectedDate));
    final monthYear = _settings.formatString(
      DateFormat('MMMM yyyy').format(_selectedDate),
    );
    return '$day $monthYear';
  }

  String _nextPrayerName() {
    final prayer = _todayPrayerTimes;
    if (prayer == null) return 'Salat berikutnya';

    final now = DateTime.now();
    final times = <MapEntry<String, String>>[
      MapEntry('Imsak', prayer.imsak),
      MapEntry('Fajr', prayer.subuh),
      MapEntry('Dhuha', prayer.dhuha),
      MapEntry('Dhuhr', prayer.dzuhur),
      MapEntry('Asr', prayer.ashar),
      MapEntry('Maghrib', prayer.maghrib),
      MapEntry('Isha', prayer.isya),
    ];

    for (final entry in times) {
      final parts = entry.value.split(':');
      if (parts.length != 2) continue;
      final candidate = DateTime(
        now.year,
        now.month,
        now.day,
        int.tryParse(parts[0]) ?? 0,
        int.tryParse(parts[1]) ?? 0,
      );
      if (candidate.isAfter(now)) return entry.key;
    }
    return 'Imsak';
  }

  String _nextPrayerTime() {
    final prayer = _todayPrayerTimes;
    if (prayer == null) return '--:--';

    final now = DateTime.now();
    final times = <MapEntry<String, String>>[
      MapEntry('Imsak', prayer.imsak),
      MapEntry('Fajr', prayer.subuh),
      MapEntry('Dhuha', prayer.dhuha),
      MapEntry('Dhuhr', prayer.dzuhur),
      MapEntry('Asr', prayer.ashar),
      MapEntry('Maghrib', prayer.maghrib),
      MapEntry('Isha', prayer.isya),
    ];

    for (final entry in times) {
      final parts = entry.value.split(':');
      if (parts.length != 2) continue;
      final candidate = DateTime(
        now.year,
        now.month,
        now.day,
        int.tryParse(parts[0]) ?? 0,
        int.tryParse(parts[1]) ?? 0,
      );
      if (candidate.isAfter(now)) return entry.value;
    }
    return prayer.imsak;
  }

  Future<void> _pickDate() async {
    final scheme = Theme.of(context).colorScheme;
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).brightness == Brightness.dark
                ? ColorScheme.dark(
                    primary: scheme.primary,
                    onPrimary: Colors.white,
                    surface: const Color(0xFF17211D),
                    onSurface: Colors.white,
                  )
                : ColorScheme.light(
                    primary: scheme.primary,
                    onPrimary: Colors.white,
                    surface: Colors.white,
                    onSurface: const Color(0xFF18201C),
                  ),
          ),
          child: child!,
        );
      },
    );

    if (picked == null || picked == _selectedDate) return;
    setState(() => _selectedDate = picked);
    await _fetchPrayerTimes();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        titleSpacing: 20,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'JADWAL SALAT',
              style: GoogleFonts.spaceGrotesk(
                color: scheme.onSurface,
                fontSize: 25,
                fontWeight: FontWeight.w800,
                letterSpacing: -1,
              ),
            ),
            Text(
              'Jadwal salat dengan tampilan sederhana.',
              style: GoogleFonts.spaceGrotesk(
                color: scheme.onSurface.withValues(alpha: 0.55),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: _iconSurface(
              context,
              icon: Icons.location_on_outlined,
              tooltip: 'Ganti lokasi',
              onTap: _showLokasiSheet,
            ),
          ),
        ],
      ),
      body: _buildBody(context, scheme, isDark),
    );
  }

  Widget _buildBody(
    BuildContext context,
    ColorScheme scheme,
    bool isDark,
  ) {
    if (_isLoading && _todayPrayerTimes == null) {
      return Center(
        child: CircularProgressIndicator(color: scheme.primary),
      );
    }

    if (_errorMessage != null && _todayPrayerTimes == null) {
      return _buildErrorState(context, scheme);
    }

    final media = MediaQuery.sizeOf(context);
    final horizontal = media.width >= 1000 ? 48.0 : media.width >= 600 ? 32.0 : 20.0;

    return RefreshIndicator(
      color: scheme.primary,
      onRefresh: _fetchPrayerTimes,
      child: CustomScrollView(
        key: const PageStorageKey<String>('prayer-times-scroll'),
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        slivers: [
          SliverPadding(
            padding: EdgeInsets.fromLTRB(horizontal, 12, horizontal, 20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildHeroCard(context, scheme, isDark),
                const SizedBox(height: 16),
                _buildControlBar(context, scheme),
                const SizedBox(height: 26),
                _buildSectionHeader(context, scheme),
                const SizedBox(height: 14),
              ]),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(horizontal, 0, horizontal, 180),
            sliver: SliverLayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.crossAxisExtent;
                if (width < 620) {
                  return SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _buildPrayerCard(context, index, _prayerEntries[index]),
                      ),
                      childCount: _prayerEntries.length,
                    ),
                  );
                }

                final columns = width >= 980 ? 3 : 2;
                final cardHeight = width >= 980 ? 116.0 : 122.0;

                return SliverGrid(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _buildPrayerCard(
                      context,
                      index,
                      _prayerEntries[index],
                    ),
                    childCount: _prayerEntries.length,
                  ),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    mainAxisExtent: cardHeight,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  List<MapEntry<String, String>> get _prayerEntries {
    final prayer = _todayPrayerTimes;
    if (prayer == null) return <MapEntry<String, String>>[];
    return <MapEntry<String, String>>[
      MapEntry('Imsak', prayer.imsak),
      MapEntry('Fajr', prayer.subuh),
      MapEntry('Dhuha', prayer.dhuha),
      MapEntry('Dhuhr', prayer.dzuhur),
      MapEntry('Asr', prayer.ashar),
      MapEntry('Maghrib', prayer.maghrib),
      MapEntry('Isha', prayer.isya),
    ];
  }

  Widget _buildHeroCard(BuildContext context, ColorScheme scheme, bool isDark) {
    final nextName = _nextPrayerName();
    final nextTime = _settings.formatString(_nextPrayerTime());

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.primary,
            Color.lerp(scheme.primary, const Color(0xFF066A4A), 0.45) ?? scheme.primary,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withValues(alpha: 0.22),
            blurRadius: 26,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -34,
            top: -44,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
          ),
          Positioned(
            right: 34,
            bottom: -72,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withValues(alpha: 0.07),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.location_on_rounded,
                          color: Colors.white,
                          size: 14,
                        ),
                        const SizedBox(width: 5),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 220),
                          child: Text(
                            _selectedCity ?? 'Select location',
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.spaceGrotesk(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.mosque_rounded,
                    color: Colors.white.withValues(alpha: 0.86),
                    size: 24,
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Text(
                DateFormat('EEEE').format(_selectedDate),
                style: GoogleFonts.spaceGrotesk(
                  color: Colors.white.withValues(alpha: 0.74),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                _formatDate(context),
                style: GoogleFonts.spaceGrotesk(
                  color: Colors.white,
                  fontSize: 28,
                  height: 1.08,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.8,
                ),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: const Icon(
                        Icons.access_time_filled_rounded,
                        color: Colors.white,
                        size: 19,
                      ),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'BERIKUTNYA PRAYER',
                            style: GoogleFonts.spaceGrotesk(
                              color: Colors.white.withValues(alpha: 0.64),
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            nextName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.spaceGrotesk(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      nextTime,
                      style: GoogleFonts.spaceGrotesk(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildControlBar(BuildContext context, ColorScheme scheme) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked = constraints.maxWidth < 380;
        final children = [
          Expanded(
            child: _controlButton(
              context,
              icon: Icons.calendar_month_rounded,
              label: _settings.formatString(DateFormat('d MMM').format(_selectedDate)),
              onTap: _pickDate,
            ),
          ),
          if (!stacked) const SizedBox(width: 12),
          Expanded(
            child: _controlButton(
              context,
              icon: Icons.location_on_rounded,
              label: 'Lokasi',
              onTap: _showLokasiSheet,
            ),
          ),
        ];

        return Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.035)
                : Colors.white.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: scheme.outline.withValues(alpha: 0.45)),
          ),
          child: stacked
              ? Column(
                  children: [
                    children[0],
                    const SizedBox(height: 6),
                    children[1],
                  ],
                )
              : Row(children: children),
        );
      },
    );
  }

  Widget _controlButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: scheme.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Icon(icon, color: scheme.primary, size: 19),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.spaceGrotesk(
                    color: scheme.onSurface,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: scheme.onSurface.withValues(alpha: 0.38),
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, ColorScheme scheme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'JADWAL SALAT',
                style: GoogleFonts.spaceGrotesk(
                  color: scheme.primary,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Jadwal hari ini',
                style: GoogleFonts.spaceGrotesk(
                  color: scheme.onSurface,
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
        ),
        TextButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ImsakiyahScreen(
                  province: _selectedProvinsi!,
                  city: _selectedCity!,
                  date: _selectedDate,
                ),
              ),
            );
          },
          child: const Text('Bulanan'),
        ),
      ],
    );
  }

  Widget _buildPrayerCard(
    BuildContext context,
    int index,
    MapEntry<String, String> entry,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final isNext = entry.key == _nextPrayerName();
    final time = _settings.formatString(entry.value);

    final icons = <String, IconData>{
      'Imsak': Icons.nights_stay_outlined,
      'Fajr': Icons.wb_twilight_rounded,
      'Dhuha': Icons.wb_sunny_outlined,
      'Dhuhr': Icons.light_mode_outlined,
      'Asr': Icons.sunny_snowing,
      'Maghrib': Icons.wb_sunny_rounded,
      'Isha': Icons.nightlight_round,
    };

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isNext
            ? scheme.primary
            : Theme.of(context).brightness == Brightness.dark
                ? Colors.white.withValues(alpha: 0.04)
                : Colors.white.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isNext
              ? scheme.primary
              : scheme.outline.withValues(alpha: 0.45),
        ),
        boxShadow: [
          if (isNext)
            BoxShadow(
              color: scheme.primary.withValues(alpha: 0.20),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isNext
                  ? Colors.white.withValues(alpha: 0.16)
                  : scheme.primary.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(
              icons[entry.key] ?? Icons.access_time_rounded,
              color: isNext ? Colors.white : scheme.primary,
              size: 21,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        entry.key,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.spaceGrotesk(
                          color: isNext ? Colors.white : scheme.onSurface,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (isNext) ...[
                      const SizedBox(width: 7),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(
                          'BERIKUTNYA',
                          style: GoogleFonts.spaceGrotesk(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Waktu salat',
                  style: GoogleFonts.spaceGrotesk(
                    color: (isNext ? Colors.white : scheme.onSurface)
                        .withValues(alpha: 0.52),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Text(
            time,
            style: GoogleFonts.spaceGrotesk(
              color: isNext ? Colors.white : scheme.onSurface,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _iconSurface(
    BuildContext context, {
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(17),
          onTap: onTap,
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(17),
              border: Border.all(color: scheme.outline.withValues(alpha: 0.35)),
            ),
            child: Icon(icon, color: scheme.primary, size: 22),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, ColorScheme scheme) {
    return RefreshIndicator(
      color: scheme.primary,
      onRefresh: _fetchPrayerTimes,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 80, 24, 140),
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: scheme.outline.withValues(alpha: 0.45)),
            ),
            child: Column(
              children: [
                Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.10),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.cloud_off_rounded,
                    color: scheme.primary,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Waktu salats unavailable',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.spaceGrotesk(
                    color: scheme.onSurface,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _errorMessage ?? 'Something went wrong.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.spaceGrotesk(
                    color: scheme.onSurface.withValues(alpha: 0.56),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: _fetchPrayerTimes,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Coba lagi'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
