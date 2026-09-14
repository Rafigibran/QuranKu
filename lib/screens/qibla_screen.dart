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

  StreamSubscription<CompassEvent>? _subscription;
  double? _heading;
  double? _bearing;
  Position? _position;
  String? _error;
  bool _loading = false;
  bool _initialized = false;

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _init() async {
    await _subscription?.cancel();
    _subscription = null;
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw Exception('Aktifkan layanan lokasi terlebih dahulu.');
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception('Izin lokasi diperlukan untuk menentukan arah kiblat.');
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      ).timeout(const Duration(seconds: 15));

      if (!mounted) return;
      setState(() {
        _position = position;
        _bearing = _calculateBearing(position.latitude, position.longitude);
        _loading = false;
        _initialized = true;
        _error = null;
      });

      _subscription = FlutterCompass.events?.listen(
        (event) {
          if (!mounted || event.heading == null) return;
          setState(() => _heading = event.heading);
        },
        onError: (_) {
          if (mounted) {
            setState(() {
              _error = 'Sensor kompas tidak tersedia pada perangkat ini.';
            });
          }
        },
      );

      if (_subscription == null && mounted) {
        setState(() => _error = 'Sensor kompas tidak tersedia pada perangkat ini.');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  double _calculateBearing(double lat, double lon) {
    final p1 = lat * math.pi / 180;
    final p2 = _kaabaLat * math.pi / 180;
    final dl = (_kaabaLon - lon) * math.pi / 180;
    final y = math.sin(dl) * math.cos(p2);
    final x = math.cos(p1) * math.sin(p2) -
        math.sin(p1) * math.cos(p2) * math.cos(dl);
    return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
  }

  double _relativeBearing() {
    if (_heading == null || _bearing == null) return 0;
    return (_bearing! - _heading! + 540) % 360 - 180;
  }

  String _direction(double degrees) {
    const names = <String>['U', 'TL', 'T', 'TG', 'S', 'BD', 'B', 'BL'];
    final index = ((degrees + 22.5) / 45).floor() % 8;
    return names[index];
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final relative = _relativeBearing();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        title: Text(
          'QIBLA.',
          style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold),
        ),
        actions: [
          if (_initialized)
            IconButton(
              onPressed: _loading ? null : _init,
              icon: const Icon(Icons.refresh),
            ),
        ],
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: scheme.primary))
          : _error != null
              ? _buildError(scheme)
              : !_initialized
                  ? _buildIntro(scheme)
                  : _buildCompass(scheme, relative),
    );
  }

  Widget _buildIntro(ColorScheme scheme) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: scheme.outline, width: 2),
                color: scheme.primary.withValues(alpha: 0.08),
              ),
              child: Icon(Icons.explore_outlined, size: 56, color: scheme.primary),
            ),
            const SizedBox(height: 24),
            Text(
              'Arah Kiblat',
              textAlign: TextAlign.center,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Aktifkan lokasi dan sensor kompas untuk menentukan arah kiblat dari posisi Anda.',
              textAlign: TextAlign.center,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 13,
                color: scheme.onSurface.withValues(alpha: 0.65),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _init,
              icon: const Icon(Icons.explore),
              label: const Text('Mulai Kompas'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompass(ColorScheme scheme, double relative) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            border: Border.all(color: scheme.outline),
            color: Theme.of(context).cardColor,
          ),
          child: Column(
            children: [
              Text(
                _heading == null ? '---°' : '${_heading!.round()}°',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: scheme.primary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _heading == null
                    ? 'Kalibrasikan kompas perangkat.'
                    : 'Arah perangkat: ${_direction(_heading!)}',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 12,
                  color: scheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: 270,
                height: 270,
                child: Transform.rotate(
                  angle: -relative * math.pi / 180,
                  child: CustomPaint(
                    painter: _CompassPainter(
                      scheme.primary,
                      scheme.onSurface,
                      scheme.outline,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                '${_bearing!.round()}° dari Utara',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Putar perangkat sampai ikon Kaaba menunjukkan arah kiblat.',
                textAlign: TextAlign.center,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 12,
                  color: scheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
        if (_position != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: scheme.outline),
            ),
            child: Row(
              children: [
                Icon(Icons.location_on_outlined, color: scheme.primary),
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
                    color: scheme.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildError(ColorScheme scheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.explore_off_outlined, size: 56, color: scheme.primary),
            const SizedBox(height: 16),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: GoogleFonts.spaceGrotesk(color: scheme.onSurface),
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

  const _CompassPainter(this.primary, this.foreground, this.outline);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = math.min(size.width, size.height) / 2 - 8;
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = outline;
    canvas.drawCircle(c, r, ring);

    final ticks = Paint()
      ..strokeWidth = 2
      ..color = foreground.withValues(alpha: 0.35);
    for (var i = 0; i < 36; i++) {
      final a = i * 10 * math.pi / 180;
      final inner = r - (i % 3 == 0 ? 14 : 8);
      canvas.drawLine(
        c + Offset(math.sin(a) * inner, -math.cos(a) * inner),
        c + Offset(math.sin(a) * r, -math.cos(a) * r),
        ticks,
      );
    }

    final tp = TextPainter(textDirection: TextDirection.ltr);
    const labels = {'U': 0.0, 'T': 90.0, 'S': 180.0, 'B': 270.0};
    labels.forEach((label, degree) {
      final a = degree * math.pi / 180;
      final pos = c + Offset(
        math.sin(a) * (r - 38),
        -math.cos(a) * (r - 38),
      );
      tp.text = TextSpan(
        text: label,
        style: TextStyle(
          color: label == 'U' ? primary : foreground,
          fontWeight: FontWeight.bold,
          fontSize: label == 'U' ? 20 : 16,
        ),
      );
      tp.layout();
      tp.paint(canvas, pos - Offset(tp.width / 2, tp.height / 2));
    });

    final arrow = Path()
      ..moveTo(c.dx, c.dy - 62)
      ..lineTo(c.dx - 12, c.dy + 18)
      ..lineTo(c.dx, c.dy + 10)
      ..lineTo(c.dx + 12, c.dy + 18)
      ..close();
    canvas.drawPath(arrow, Paint()..color = primary);
    canvas.drawCircle(c, 8, Paint()..color = foreground);
    canvas.drawCircle(c, 4, Paint()..color = primary);

    final kaaba = TextPainter(
      text: const TextSpan(text: '🕋', style: TextStyle(fontSize: 26)),
      textDirection: TextDirection.ltr,
    )..layout();
    kaaba.paint(canvas, c - Offset(kaaba.width / 2, r - 30));
  }

  @override
  bool shouldRepaint(covariant _CompassPainter oldDelegate) =>
      oldDelegate.primary != primary ||
      oldDelegate.foreground != foreground ||
      oldDelegate.outline != outline;
}
