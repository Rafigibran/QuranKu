import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_device_compass/flutter_device_compass.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';

class QiblaScreen extends StatefulWidget {
  const QiblaScreen({super.key});

  @override
  State<QiblaScreen> createState() => _QiblaScreenState();
}

class _QiblaScreenState extends State<QiblaScreen> {
  static const double _kaabaLat = 21.422487;
  static const double _kaabaLon = 39.826206;

  StreamSubscription<double?>? _headingSubscription;
  double? _heading;
  double? _qiblaBearing;
  Position? _position;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _headingSubscription?.cancel();
    super.dispose();
  }

  Future<void> _init() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Aktifkan layanan lokasi untuk menentukan arah kiblat.');
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception('Izin lokasi diperlukan untuk menghitung arah kiblat.');
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      ).timeout(const Duration(seconds: 15));

      final bearing = _bearingToKaaba(position.latitude, position.longitude);
      if (!mounted) return;
      setState(() {
        _position = position;
        _qiblaBearing = bearing;
        _loading = false;
        _error = null;
      });

      _headingSubscription = FlutterDeviceCompass.events.listen(
        (event) {
          if (!mounted) return;
          final heading = event.heading;
          if (heading != null) setState(() => _heading = heading);
        },
        onError: (_) {
          if (mounted) setState(() => _error = 'Sensor kompas tidak tersedia pada perangkat ini.');
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  double _bearingToKaaba(double lat, double lon) {
    final phi1 = _degToRad(lat);
    final phi2 = _degToRad(_kaabaLat);
    final deltaLambda = _degToRad(_kaabaLon - lon);
    final y = math.sin(deltaLambda) * math.cos(phi2);
    final x = math.cos(phi1) * math.sin(phi2) -
        math.sin(phi1) * math.cos(phi2) * math.cos(deltaLambda);
    final bearing = math.atan2(y, x) * 180 / math.pi;
    return (bearing + 360) % 360;
  }

  double _degToRad(double value) => value * math.pi / 180;

  double _normalize(double value) => (value + 540) % 360 - 180;

  String _direction(double degrees) {
    const names = <String>['U', 'TL', 'T', 'TG', 'S', 'BD', 'B', 'BL'];
    final index = ((degrees + 22.5) / 45).floor() % 8;
    return names[index];
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final relative = (_heading != null && _qiblaBearing != null)
        ? _normalize(_qiblaBearing! - _heading!)
        : 0.0;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        title: Text.rich(
          TextSpan(
            text: 'QIBLA',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: colors.onSurface,
            ),
            children: [
              TextSpan(
                text: '.',
                style: GoogleFonts.spaceGrotesk(color: colors.primary),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            onPressed: () {
              setState(() {
                _loading = true;
                _error = null;
              });
              _headingSubscription?.cancel();
              _init();
            },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: colors.primary))
          : _error != null
              ? _buildError(colors)
              : ListView(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        border: Border.all(color: colors.outline),
                        color: Theme.of(context).cardColor,
                      ),
                      child: Column(
                        children: [
                          Text(
                            _heading == null ? '---°' : '${_heading!.round()}°',
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: colors.primary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _heading == null
                                ? 'Putar perangkat untuk mengaktifkan kompas'
                                : 'Arah perangkat: ${_direction(_heading!)}',
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 12,
                              color: colors.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: 260,
                            height: 260,
                            child: Transform.rotate(
                              angle: -relative * math.pi / 180,
                              child: CustomPaint(
                                painter: _CompassPainter(
                                  primary: colors.primary,
                                  foreground: colors.onSurface,
                                  outline: colors.outline,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            _qiblaBearing == null
                                ? '--°'
                                : '${_qiblaBearing!.round()}° dari Utara',
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: colors.onSurface,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Putar sampai jarum mengarah ke ikon Kaaba.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 12,
                              color: colors.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_position != null)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          border: Border.all(color: colors.outline),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.location_on_outlined, color: colors.primary),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Lokasi ${_position!.latitude.toStringAsFixed(4)}, ${_position!.longitude.toStringAsFixed(4)}',
                                style: GoogleFonts.spaceGrotesk(fontSize: 12),
                              ),
                            ),
                            Text(
                              '${relative.abs().round()}°',
                              style: GoogleFonts.spaceGrotesk(
                                fontWeight: FontWeight.bold,
                                color: colors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
    );
  }

  Widget _buildError(ColorScheme colors) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.explore_off_outlined, size: 56, color: colors.primary),
            const SizedBox(height: 16),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: GoogleFonts.spaceGrotesk(color: colors.onSurface),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _init,
              icon: const Icon(Icons.refresh),
              label: const Text('Coba Lagi'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompassPainter extends CustomPainter {
  final Color primary;
  final Color foreground;
  final Color outline;

  const _CompassPainter({
    required this.primary,
    required this.foreground,
    required this.outline,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = math.min(size.width, size.height) / 2 - 8;
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = outline;
    canvas.drawCircle(center, radius, ring);

    final tick = Paint()
      ..strokeWidth = 2
      ..color = foreground.withValues(alpha: 0.35);
    for (var i = 0; i < 36; i++) {
      final angle = i * 10 * math.pi / 180;
      final inner = radius - (i % 3 == 0 ? 14 : 8);
      final p1 = center + Offset(math.sin(angle) * inner, -math.cos(angle) * inner);
      final p2 = center + Offset(math.sin(angle) * radius, -math.cos(angle) * radius);
      canvas.drawLine(p1, p2, tick);
    }

    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    final labels = {'U': 0.0, 'T': 90.0, 'S': 180.0, 'B': 270.0};
    labels.forEach((label, degree) {
      final angle = degree * math.pi / 180;
      final position = center + Offset(math.sin(angle) * (radius - 38), -math.cos(angle) * (radius - 38));
      textPainter.text = TextSpan(
        text: label,
        style: TextStyle(
          color: label == 'U' ? primary : foreground,
          fontWeight: FontWeight.bold,
          fontSize: label == 'U' ? 20 : 16,
        ),
      );
      textPainter.layout();
      textPainter.paint(canvas, position - Offset(textPainter.width / 2, textPainter.height / 2));
    });

    final arrow = Path()
      ..moveTo(center.dx, center.dy - 62)
      ..lineTo(center.dx - 12, center.dy + 18)
      ..lineTo(center.dx, center.dy + 10)
      ..lineTo(center.dx + 12, center.dy + 18)
      ..close();
    canvas.drawPath(arrow, Paint()..color = primary);
    canvas.drawCircle(center, 8, Paint()..color = foreground);
    canvas.drawCircle(center, 4, Paint()..color = primary);

    final kaaba = TextPainter(
      text: const TextSpan(text: '🕋', style: TextStyle(fontSize: 26)),
      textDirection: TextDirection.ltr,
    )..layout();
    kaaba.paint(canvas, center - Offset(kaaba.width / 2, radius - 30));
  }

  @override
  bool shouldRepaint(covariant _CompassPainter oldDelegate) =>
      oldDelegate.primary != primary ||
      oldDelegate.foreground != foreground ||
      oldDelegate.outline != outline;
}
