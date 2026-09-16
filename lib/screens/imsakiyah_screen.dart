import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../l10n/l10n.dart';
import '../services/api_service.dart';
import '../services/gps_prayer_service.dart';
import '../services/settings_service.dart';
import '../utils/formatters.dart';
import '../widgets/liquid_glass.dart';

class ImsakiyahScreen extends StatefulWidget {
  final String province;
  final String city;
  final DateTime date;
  final double? lat;
  final double? lon;
  final String? methodLabel;
  final String? placeLabel;

  const ImsakiyahScreen({
    super.key,
    required this.province,
    required this.city,
    required this.date,
  }) : lat = null,
       lon = null,
       methodLabel = null,
       placeLabel = null;

  const ImsakiyahScreen.gps({
    super.key,
    required double lat,
    required double lon,
    required this.date,
    this.methodLabel,
    this.placeLabel,
  }) : lat = lat,
       lon = lon,
       province = '',
       city = '';

  bool get isGps => lat != null && lon != null;

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
      if (widget.isGps) {
        final data = GpsPrayerService.monthly(
          widget.lat!,
          widget.lon!,
          widget.date.year,
          widget.date.month,
        );
        setState(() {
          _schedule = data;
          _isLoading = false;
        });
        return;
      }
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
    final monthName = DateFormat(
      'MMMM yyyy',
      localeTagOf(context),
    ).format(widget.date);
    final monthNameFormatted = _settings.formatString(monthName);
    final colorScheme = Theme.of(context).colorScheme;
    final localeTag = localeTagOf(context);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        iconTheme: IconThemeData(color: colorScheme.onSurface),
        title: RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: context.l10n.imsakiyahMonthly,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                  color: colorScheme.onSurface,
                  letterSpacing: -0.6,
                ),
              ),
              TextSpan(
                text: '.',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                  color: colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        scrolledUnderElevation: 0,
        centerTitle: true,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: colorScheme.primary))
          : _errorMessage != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: LiquidGlassCard(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.cloud_off_rounded, size: 40, color: colorScheme.error),
                      const SizedBox(height: 12),
                      Text(context.l10n.prayerLoadFailed, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12),
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: () {
                          setState(() {
                            _isLoading = true;
                            _errorMessage = null;
                          });
                          _fetchSchedule();
                        },
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: Text(context.l10n.actionRetry),
                      ),
                    ],
                  ),
                ),
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                  child: LiquidGlassCard(
                    radius: 16,
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          monthNameFormatted,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(
                              widget.isGps ? Icons.gps_fixed_rounded : Icons.location_on_outlined,
                              size: 14,
                              color: colorScheme.primary,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                widget.isGps
                                    ? '${widget.placeLabel ?? 'GPS ${widget.lat!.toStringAsFixed(4)}, ${widget.lon!.toStringAsFixed(4)}'}${widget.methodLabel != null ? ' • ${widget.methodLabel}' : ''}'
                                    : '${widget.city}, ${widget.province}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: colorScheme.onSurfaceVariant,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: colorScheme.primary.withValues(alpha: .10),
                                borderRadius: BorderRadius.circular(99),
                              ),
                              child: Text(
                                '${_schedule.length} hari',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: colorScheme.primary),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    itemCount: _schedule.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final day = _schedule[index];
                      DateTime date = DateTime.parse(day['tanggal_lengkap']);
                      bool isToday = DateUtils.isSameDay(date, DateTime.now());
                      final dayName = DateFormat(
                        'EEEE',
                        localeTag,
                      ).format(date);
                      final dayNumber = DateFormat('d', localeTag).format(date);

                      return LiquidGlassCard(
                        radius: 16,
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                        tint: isToday ? colorScheme.primary.withValues(alpha: .06) : null,
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isToday ? colorScheme.primary : colorScheme.surfaceContainerHighest,
                                    border: Border.all(color: isToday ? colorScheme.primary : colorScheme.outlineVariant),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    _settings.formatString(dayNumber),
                                    style: TextStyle(
                                      color: isToday ? Colors.white : colorScheme.onSurface,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        dayName,
                                        style: TextStyle(
                                          color: isToday ? colorScheme.primary : schemeOnSurfaceVariant(colorScheme),
                                          fontWeight: FontWeight.w800,
                                          fontSize: 13,
                                        ),
                                      ),
                                      Text(
                                        DateFormat(
                                          'd MMM',
                                          localeTag,
                                        ).format(date),
                                        style: TextStyle(
                                          color: colorScheme.onSurfaceVariant,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: isToday ? colorScheme.primary : colorScheme.surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Column(
                                    children: [
                                      Text(
                                        'IMSAK',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w800,
                                          color: isToday ? colorScheme.onPrimary : colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _settings.formatString(day['imsak']),
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                          color: isToday ? Colors.white : colorScheme.onSurface,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                              decoration: BoxDecoration(
                                color: colorScheme.surfaceContainerHighest.withValues(alpha: .55),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: colorScheme.outlineVariant),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  _buildMiniTime("Subuh", day['subuh'], isToday, colorScheme),
                                  _buildMiniTime("Dzuhur", day['dzuhur'], isToday, colorScheme),
                                  _buildMiniTime("Ashar", day['ashar'], isToday, colorScheme),
                                  _buildMiniTime("Maghrib", day['maghrib'], isToday, colorScheme),
                                  _buildMiniTime("Isya", day['isya'], isToday, colorScheme),
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

  Color schemeOnSurfaceVariant(ColorScheme s) => s.onSurfaceVariant;

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
          style: TextStyle(
            fontSize: 12,
            color: colorScheme.onSurface.withValues(alpha: 0.72),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _settings.formatString(time),
          style: TextStyle(
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
