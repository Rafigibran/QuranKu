import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';

class QiblaScreen extends StatefulWidget {
  const QiblaScreen({super.key});
  @override
  State<QiblaScreen> createState() => _QiblaScreenState();
}

class _QiblaScreenState extends State<QiblaScreen> {
  static const _kaabaLat = 21.422487;
  static const _kaabaLon = 39.826206;
  StreamSubscription<MagnetometerEvent>? _magSub;
  Position? _position;
  double? _heading;
  double? _qibla;
  String? _error;
  double _mx = 0;
  double _my = 0;

  @override
  void initState() {
    super.initState();
    _locate();
    _magSub = magnetometerEventStream().listen((e) {
      _mx = e.x;
      _my = e.y;
      _updateHeading();
    }, onError: (_) {
      if (mounted) setState(() => _error = 'Sensor kompas tidak tersedia.');
    });
  }

  Future<void> _locate() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw Exception('Layanan lokasi perangkat nonaktif.');
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        throw Exception('Izin lokasi diperlukan untuk menghitung arah kiblat.');
      }
      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      if (!mounted) return;
      setState(() {
        _position = p;
        _qibla = _bearing(p.latitude, p.longitude, _kaabaLat, _kaabaLon);
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  double _bearing(double lat1, double lon1, double lat2, double lon2) {
    final p1 = lat1 * math.pi / 180;
    final p2 = lat2 * math.pi / 180;
    final dl = (lon2 - lon1) * math.pi / 180;
    final y = math.sin(dl) * math.cos(p2);
    final x = math.cos(p1) * math.sin(p2) - math.sin(p1) * math.cos(p2) * math.cos(dl);
    return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
  }

  void _updateHeading() {
    final h = (math.atan2(-_mx, _my) * 180 / math.pi + 360) % 360;
    if (mounted) setState(() => _heading = h);
  }

  @override
  void dispose() {
    _magSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = _qibla;
    final heading = _heading ?? 0;
    final needle = q == null ? 0 : (q - heading + 360) % 360;
    return Scaffold(
      appBar: AppBar(title: const Text('Arah kiblat')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            if (_error != null)
              Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            if (_position != null) ...[
              Text('${_position!.latitude.toStringAsFixed(4)}, ${_position!.longitude.toStringAsFixed(4)}', style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 20),
            ],
            Container(
              width: 270,
              height: 270,
              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Theme.of(context).colorScheme.primary, width: 3)),
              child: Transform.rotate(
                angle: -needle * math.pi / 180,
                child: const Center(child: Icon(Icons.navigation_rounded, size: 140)),
              ),
            ),
            const SizedBox(height: 20),
            Text(q == null ? 'Menentukan arah…' : 'Kiblat ${q.toStringAsFixed(1)}° dari Utara', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            const Text('Putar perangkat sampai penunjuk mengarah ke kiblat.'),
          ]),
        ),
      ),
      floatingActionButton: FloatingActionButton(onPressed: _locate, child: const Icon(Icons.my_location_rounded)),
    );
  }
}
