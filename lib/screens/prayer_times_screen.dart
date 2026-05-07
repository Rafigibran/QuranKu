import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../models/prayer_times.dart';
import '../services/api_service.dart';
import 'imsakiyah_screen.dart';
import '../services/settings_service.dart';
import '../services/audio_service.dart';
import '../services/widget_service.dart';

class PrayerTimesScreen extends StatefulWidget {
  const PrayerTimesScreen({super.key});

  @override
  State<PrayerTimesScreen> createState() => _PrayerTimesScreenState();
}

class _PrayerTimesScreenState extends State<PrayerTimesScreen> {
  // Location Data
  List<dynamic> _locations = [];
  String? _selectedProvince;
  String? _selectedCity;
  List<String> _cities = [];

  // Prayer Times Data
  PrayerTimes? _todayPrayerTimes;
  bool _isLoading = true; // Start true to wait for location check
  String? _errorMessage;
  DateTime _selectedDate = DateTime.now();

  final SettingsService _settings = SettingsService();
  final AudioService _audioService = AudioService();

  @override
  void initState() {
    super.initState();
    _settings.addListener(_onSettingsChanged);
    _audioService.addListener(_onAudioChanged);
    _loadLocationData();
  }

  Future<void> _loadLocationData() async {
    try {
      final String jsonString = await DefaultAssetBundle.of(
        context,
      ).loadString('assets/loc_indonesian.json');
      setState(() {
        _locations = json.decode(jsonString);
      });
      await _loadSavedLocation();
    } catch (e) {
      debugPrint('Error loading location data: $e');
      setState(() {
        _errorMessage = 'Failed to load location data.';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadSavedLocation() async {
    final prefs = await SharedPreferences.getInstance();
    final savedProvince = prefs.getString('saved_province');
    final savedCity = prefs.getString('saved_city');

    if (savedProvince != null && savedCity != null) {
      // Validate
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
            return; // Successfully loaded saved location
          }
        }
      }
    }

    // Default to Jakarta if no saved location or invalid saved location
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
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _showLocationDialog() async {
    // Set defaults if empty
    String? tempProvince = _selectedProvince ?? "DKI Jakarta";
    String? tempCity = _selectedCity ?? "Kota Jakarta";

    // Ensure cities list is populated if starting with defaults
    if (_cities.isEmpty && _locations.isNotEmpty) {
      final provinceData = _locations.firstWhere(
        (e) => e['provinsi'] == tempProvince,
        orElse: () => null,
      );
      if (provinceData != null) {
        _cities = List<String>.from(provinceData['kota_kabupaten']);
      }
    }

    await showDialog(
      context: context,
      barrierDismissible: false, // Force selection
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: const Color(0xFF111111),
              shape: RoundedRectangleBorder(
                side: const BorderSide(color: Color(0xFF2A2A2A)),
                borderRadius: BorderRadius.circular(0),
              ),
              title: Text(
                'Select Location',
                style: GoogleFonts.spaceGrotesk(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Province Dropdown
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFF2A2A2A)),
                      borderRadius: BorderRadius.circular(0),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: tempProvince,
                        hint: Text(
                          'Province',
                          style: GoogleFonts.spaceGrotesk(
                            color: const Color(0xFF555555),
                            fontSize: 14,
                          ),
                        ),
                        dropdownColor: const Color(0xFF0A0A0A),
                        isExpanded: true,
                        icon: const Icon(
                          Icons.arrow_drop_down,
                          color: Color(0xFF40B779),
                        ),
                        items: _locations.map<DropdownMenuItem<String>>((
                          dynamic item,
                        ) {
                          return DropdownMenuItem<String>(
                            value: item['provinsi'],
                            child: Text(
                              item['provinsi'],
                              style: GoogleFonts.spaceGrotesk(
                                color: Colors.white,
                                fontSize: 14,
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val == null) return;
                          final provinceData = _locations.firstWhere(
                            (e) => e['provinsi'] == val,
                          );
                          setStateDialog(() {
                            tempProvince = val;
                            _cities = List<String>.from(
                              provinceData['kota_kabupaten'],
                            );
                            tempCity = null;
                          });
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // City Dropdown
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFF2A2A2A)),
                      borderRadius: BorderRadius.circular(0),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: tempCity,
                        hint: Text(
                          'City',
                          style: GoogleFonts.spaceGrotesk(
                            color: const Color(0xFF555555),
                            fontSize: 14,
                          ),
                        ),
                        dropdownColor: const Color(0xFF0A0A0A),
                        isExpanded: true,
                        icon: const Icon(
                          Icons.arrow_drop_down,
                          color: Color(0xFF40B779),
                        ),
                        items: _cities.map<DropdownMenuItem<String>>((
                          String value,
                        ) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(
                              value,
                              style: GoogleFonts.spaceGrotesk(
                                color: Colors.white,
                                fontSize: 14,
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setStateDialog(() {
                            tempCity = val;
                          });
                        },
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'CANCEL',
                    style: GoogleFonts.spaceGrotesk(
                      color: Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: (tempProvince != null && tempCity != null)
                      ? () {
                          setState(() {
                            _selectedProvince = tempProvince;
                            _selectedCity = tempCity;
                          });
                          Navigator.of(context).pop();
                          _saveLocation();
                          _fetchPrayerTimes();
                        }
                      : null,
                  child: Text(
                    'SAVE',
                    style: GoogleFonts.spaceGrotesk(
                      color: (tempProvince != null && tempCity != null)
                          ? const Color(0xFF40B779)
                          : Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
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

  Future<void> _fetchPrayerTimes() async {
    if (_selectedProvince == null || _selectedCity == null) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final schedule = await ApiService().fetchPrayerSchedule(
        _selectedProvince!,
        _selectedCity!,
        date: _selectedDate,
      );

      final String dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);

      final todayData = schedule.firstWhere(
        (element) => element['tanggal_lengkap'] == dateStr,
        orElse: () => {},
      );

      if (todayData.isNotEmpty) {
        final prayerTimes = PrayerTimes.fromJson(todayData);
        setState(() {
          _todayPrayerTimes = prayerTimes;
        });

        // Update Home Screen Widgets
        _updateWidgets(prayerTimes);
      } else {
        setState(() {
          _errorMessage = 'No schedule found for this date.';
          _todayPrayerTimes = null;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to fetch data.\nPlease check your connection.';
      });
      debugPrint("API Error: $e");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
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

  void _onProvinceChanged(String? newValue) {
    if (newValue == null) return;
    final provinceData = _locations.firstWhere(
      (e) => e['provinsi'] == newValue,
    );
    setState(() {
      _selectedProvince = newValue;
      _cities = List<String>.from(provinceData['kota_kabupaten']);
      _selectedCity = null; // Reset city
      _todayPrayerTimes = null;
    });
  }

  void _onCityChanged(String? newValue) {
    if (newValue == null) return;
    setState(() {
      _selectedCity = newValue;
    });
    _saveLocation();
    _fetchPrayerTimes();
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
      final prayerTime = DateTime(
        now.year,
        now.month,
        now.day,
        int.parse(t[0]),
        int.parse(t[1]),
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

  @override
  Widget build(BuildContext context) {
    if (_errorMessage != null) {
      return _buildErrorOverlay();
    }

    final colorScheme = Theme.of(context).colorScheme;

    final dateFormatted = _settings.formatString(
      DateFormat('d').format(_selectedDate),
    );
    final monthYear = DateFormat('MMMM yyyy').format(_selectedDate);
    final monthYearFormatted = _settings.formatString(monthYear);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: 'TIME',
                style: GoogleFonts.spaceGrotesk(
                  fontWeight: FontWeight.bold,
                  fontSize: 24,
                  color: colorScheme.onSurface,
                  letterSpacing: -1,
                ),
              ),
              TextSpan(
                text: '.',
                style: GoogleFonts.spaceGrotesk(
                  fontWeight: FontWeight.bold,
                  fontSize: 24,
                  color: colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
        centerTitle: false,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        scrolledUnderElevation: 0,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: colorScheme.primary))
          : (_todayPrayerTimes != null)
          ? SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              child: Column(
                children: [
                  // --- HEADER CARD ---
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          DateFormat('EEEE').format(_selectedDate),
                          style: GoogleFonts.spaceGrotesk(
                            color: colorScheme.primary,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          "$dateFormatted $monthYearFormatted",
                          style: GoogleFonts.spaceGrotesk(
                            color: colorScheme.onSurface,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(
                              Icons.location_on_outlined,
                              color: colorScheme.onSurface.withValues(
                                alpha: 0.5,
                              ),
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                '${_selectedCity ?? ''}, ${_selectedProvince ?? ''}',
                                style: GoogleFonts.spaceGrotesk(
                                  color: colorScheme.onSurface.withValues(
                                    alpha: 0.7,
                                  ),
                                  fontSize: 14,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () async {
                                  final DateTime? picked = await showDatePicker(
                                    context: context,
                                    initialDate: _selectedDate,
                                    firstDate: DateTime(2020),
                                    lastDate: DateTime(2030),
                                    builder: (context, child) {
                                      return Theme(
                                        data: Theme.of(context).copyWith(
                                          colorScheme: ColorScheme.dark(
                                            primary: colorScheme.primary,
                                            onPrimary: Colors.black,
                                            surface: const Color(
                                              0xFF111111,
                                            ), // Keep dark for picker or use theme
                                            onSurface: Colors.white,
                                          ),
                                          textButtonTheme: TextButtonThemeData(
                                            style: TextButton.styleFrom(
                                              foregroundColor:
                                                  colorScheme.primary,
                                            ),
                                          ),
                                          dialogTheme: DialogThemeData(
                                            backgroundColor: Theme.of(
                                              context,
                                            ).cardColor,
                                          ),
                                        ),
                                        child: child!,
                                      );
                                    },
                                  );
                                  if (picked != null &&
                                      picked != _selectedDate) {
                                    setState(() => _selectedDate = picked);
                                    _fetchPrayerTimes();
                                  }
                                },
                                icon: Icon(
                                  Icons.calendar_today,
                                  size: 16,
                                  color: colorScheme.onSurface,
                                ),
                                label: Text(
                                  "Date",
                                  style: GoogleFonts.spaceGrotesk(
                                    color: colorScheme.onSurface,
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(color: colorScheme.outline),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(0),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _showLocationDialog,
                                icon: Icon(
                                  Icons.map,
                                  size: 16,
                                  color: colorScheme.onSurface,
                                ),
                                label: Text(
                                  "Location",
                                  style: GoogleFonts.spaceGrotesk(
                                    color: colorScheme.onSurface,
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(color: colorScheme.outline),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(0),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // --- SCHEDULE LIST TITLE ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'TODAY\'S PRAYERS',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface.withValues(alpha: 0.5),
                          letterSpacing: 1.5,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          // Navigate to Imsakiyah Screen
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ImsakiyahScreen(
                                province: _selectedProvince!,
                                city: _selectedCity!,
                                date: _selectedDate,
                              ),
                            ),
                          );
                        },
                        child: Text(
                          'See Monthly',
                          style: GoogleFonts.spaceGrotesk(
                            color: colorScheme.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  _buildScheduleList(),

                  // Extra padding for MiniPlayer
                  if (_audioService.currentSurah != null)
                    const SizedBox(height: 80),
                ],
              ),
            )
          : Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Set your location to view prayer times",
                    style: TextStyle(color: colorScheme.onSurface),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _showLocationDialog,
                    icon: const Icon(Icons.location_on, color: Colors.black),
                    label: Text(
                      'Set Location',
                      style: GoogleFonts.spaceGrotesk(
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildErrorOverlay() {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.wifi_off_outlined,
                size: 48,
                color: Colors.redAccent,
              ),
              const SizedBox(height: 16),
              Text(
                'Connection Error',
                style: GoogleFonts.spaceGrotesk(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage ?? 'Unknown Error',
                style: GoogleFonts.spaceGrotesk(
                  color: colorScheme.onSurface.withValues(alpha: 0.5),
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _fetchPrayerTimes,
                icon: const Icon(Icons.refresh, color: Colors.black),
                label: Text(
                  'Retry',
                  style: GoogleFonts.spaceGrotesk(
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(0),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScheduleList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTimeRow('Imsak', _todayPrayerTimes!.imsak),
        _buildTimeRow('Fajr', _todayPrayerTimes!.subuh),
        _buildTimeRow('Duha', _todayPrayerTimes!.dhuha),
        _buildTimeRow('Dhuhr', _todayPrayerTimes!.dzuhur),
        _buildTimeRow('Asr', _todayPrayerTimes!.ashar),
        _buildTimeRow('Maghrib', _todayPrayerTimes!.maghrib),
        _buildTimeRow('Isha', _todayPrayerTimes!.isya),
      ],
    );
  }

  Widget _buildTimeRow(String label, String time, {bool isHighlight = false}) {
    final colorScheme = Theme.of(context).colorScheme;
    final formattedTime = _settings.formatString(time);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: isHighlight
            ? colorScheme.primary.withValues(alpha: 0.1)
            : Colors.transparent,
        border: Border.all(
          color: isHighlight ? colorScheme.primary : colorScheme.outline,
        ),
        borderRadius: BorderRadius.circular(0),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.spaceGrotesk(
              color: isHighlight ? colorScheme.primary : colorScheme.onSurface,
              fontWeight: isHighlight ? FontWeight.bold : FontWeight.normal,
              fontSize: 16,
            ),
          ),
          Text(
            formattedTime,
            style: GoogleFonts.spaceGrotesk(
              color: isHighlight ? colorScheme.primary : colorScheme.onSurface,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }
}
