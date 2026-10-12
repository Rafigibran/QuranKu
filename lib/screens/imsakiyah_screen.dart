import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../services/settings_service.dart';

class ImsakiyahScreen extends StatefulWidget {
  final String province;
  final String city;
  final DateTime date;

  const ImsakiyahScreen({
    super.key,
    required this.province,
    required this.city,
    required this.date,
  });

  @override
  State<ImsakiyahScreen> createState() => _ImsakiyahScreenState();
}

class _ImsakiyahScreenState extends State<ImsakiyahScreen> {
  List<Map<String, dynamic>> _schedule = [];
  bool _isLoading = true;
  String? _errorMessage;
  final SettingsService _settings = SettingsService();

  @override
  void initState() {
    super.initState();
    _settings.addListener(_onSettingsChanged);
    _fetchSchedule();
  }

  @override
  void dispose() {
    _settings.removeListener(_onSettingsChanged);
    super.dispose();
  }

  void _onSettingsChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _fetchSchedule() async {
    try {
      final data = await ApiService().fetchPrayerSchedule(
        widget.province,
        widget.city,
        date: widget.date,
      );
      setState(() {
        _schedule = data;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final monthName = DateFormat('MMMM yyyy').format(widget.date);
    final monthNameFormatted = _settings.formatString(monthName);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        iconTheme: IconThemeData(color: colorScheme.onSurface),
        title: RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: 'IMSAKIYAH',
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
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        centerTitle: true,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: colorScheme.primary))
          : _errorMessage != null
          ? Center(
              child: Text(
                'Error: $_errorMessage',
                style: TextStyle(color: colorScheme.error),
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start, // Align Left
                    children: [
                      Text(
                        monthNameFormatted.toUpperCase(),
                        style: GoogleFonts.spaceGrotesk(
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 0,
                          vertical: 6,
                        ), // Reduced padding since no border
                        child: Text(
                          '${widget.city}, ${widget.province}',
                          style: GoogleFonts.spaceGrotesk(
                            color: colorScheme.onSurface.withValues(alpha: 0.5),
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 0,
                    ),
                    itemCount: _schedule.length,
                    itemBuilder: (context, index) {
                      final day = _schedule[index];
                      // Parse date using the VALID key we fixed earlier
                      final date = DateTime.tryParse(day['tanggal_lengkap']?.toString() ?? '') ?? DateTime.now();
                      bool isToday = DateUtils.isSameDay(date, DateTime.now());

                      final dayName = DateFormat('EEEE').format(date);
                      final dayNumber = DateFormat('d').format(date);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          border: Border.all(
                            color: isToday
                                ? colorScheme.primary
                                : colorScheme.outline,
                          ),
                          borderRadius: BorderRadius.circular(0),
                        ),
                        child: Column(
                          children: [
                            // Top Row: Date & Imsak
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      dayName,
                                      style: GoogleFonts.spaceGrotesk(
                                        color: colorScheme.primary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    Text(
                                      _settings.formatString(dayNumber),
                                      style: GoogleFonts.spaceGrotesk(
                                        color: colorScheme.onSurface,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 32,
                                        height: 1.0,
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.transparent,
                                    borderRadius: BorderRadius.circular(0),
                                  ),
                                  child: Column(
                                    children: [
                                      Text(
                                        "IMSAK",
                                        style: GoogleFonts.spaceGrotesk(
                                          fontSize: 10,
                                          color: colorScheme.onSurface
                                              .withValues(alpha: 0.5),
                                        ),
                                      ),
                                      Text(
                                        _settings.formatString(day['imsak']),
                                        style: GoogleFonts.spaceGrotesk(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: colorScheme.onSurface,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            // Grid of other times
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.transparent, // Removed background
                                border: Border.all(
                                  color: colorScheme.outline.withValues(
                                    alpha: 0.5,
                                  ),
                                ),
                                borderRadius: BorderRadius.circular(0),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  _buildMiniTime(
                                    "Fajr",
                                    day['subuh'],
                                    isToday,
                                    colorScheme,
                                  ),
                                  _buildMiniTime(
                                    "Dhuhr",
                                    day['dzuhur'],
                                    isToday,
                                    colorScheme,
                                  ),
                                  _buildMiniTime(
                                    "Asr",
                                    day['ashar'],
                                    isToday,
                                    colorScheme,
                                  ),
                                  _buildMiniTime(
                                    "Maghrib",
                                    day['maghrib'],
                                    isToday,
                                    colorScheme,
                                  ),
                                  _buildMiniTime(
                                    "Isha",
                                    day['isya'],
                                    isToday,
                                    colorScheme,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildMiniTime(
    String label,
    String time,
    bool isToday,
    ColorScheme colorScheme,
  ) {
    return Column(
      children: [
        Text(
          label,
          style: GoogleFonts.spaceGrotesk(
            fontSize: 10,
            color: colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _settings.formatString(time),
          style: GoogleFonts.spaceGrotesk(
            fontSize: 14,
            fontWeight: FontWeight
                .bold, // Removed conditional bold logic for simplicity/cleaner look
            color: colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}
