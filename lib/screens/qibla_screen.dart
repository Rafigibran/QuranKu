import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:geolocator/geolocator.dart';
import 'package:quranku/l10n/app_localizations.dart';
import 'package:quranku/l10n/l10n.dart';
import '../widgets/liquid_glass.dart';

class QiblaScreen extends StatefulWidget {
  const QiblaScreen({super.key});
  @override
  State<QiblaScreen> createState() => _QiblaScreenState();
}

class _QiblaScreenState extends State<QiblaScreen> {
  Position? _pos;
  String? _error;
  bool _loading = true;
  StreamSubscription<Position>? _posSub;

  static const double kaabaLat = 21.4225;
  static const double kaabaLon = 39.8262;

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  @override
  void dispose() {
    _posSub?.cancel();
    super.dispose();
  }

  Future<void> _initLocation() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        setState(() {
          _error = context.l10n.qiblaPermissionDenied;
          _loading = false;
        });
        return;
      }
      final service = await Geolocator.isLocationServiceEnabled();
      if (!service) {
        setState(() {
          _error = context.l10n.qiblaGpsOff;
          _loading = false;
        });
        return;
      }
      final p = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      if (!mounted) return;
      setState(() {
        _pos = p;
        _loading = false;
      });
      _posSub =
          Geolocator.getPositionStream(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              distanceFilter: 5,
            ),
          ).listen((e) {
            if (mounted) setState(() => _pos = e);
          });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '${context.l10n.qiblaGpsFailed}: $e';
        _loading = false;
      });
    }
  }

  double _qiblaBearing() {
    if (_pos == null) return 0;
    final lat1 = _pos!.latitude * math.pi / 180;
    final lon1 = _pos!.longitude * math.pi / 180;
    final lat2 = kaabaLat * math.pi / 180;
    final lon2 = kaabaLon * math.pi / 180;
    final dLon = lon2 - lon1;
    final y = math.sin(dLon);
    final x = math.cos(lat1) * math.tan(lat2) - math.sin(lat1) * math.cos(dLon);
    final brng = math.atan2(y, x) * 180 / math.pi;
    return (brng + 360) % 360;
  }

  double _distanceKm() {
    if (_pos == null) return 0;
    return Geolocator.distanceBetween(
          _pos!.latitude,
          _pos!.longitude,
          kaabaLat,
          kaabaLon,
        ) /
        1000;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final bearing = _qiblaBearing();
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.qiblaTitle, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
            Text(
              l10n.qiblaSubtitle,
              style: TextStyle(
                color: scheme.onSurface.withValues(alpha: .72),
                fontSize: 12,
              ),
            ),
          ],
        ),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          LiquidGlassCard(
            radius: 24,
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
            child: Column(
              children: [
                if (_loading) ...[
                  const CircularProgressIndicator(),
                  const SizedBox(height: 12),
                  Text(context.l10n.qiblaSearching),
                ] else if (_error != null) ...[
                  Icon(
                    Icons.location_off_rounded,
                    size: 40,
                    color: scheme.error,
                  ),
                  const SizedBox(height: 10),
                  Text(_error!, textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _initLocation,
                    icon: const Icon(Icons.refresh_rounded),
                    label: Text(context.l10n.actionRetry),
                  ),
                ] else ...[
                  Text(
                    context.l10n.qiblaFromNorth(bearing.toStringAsFixed(1)),
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: scheme.primary,
                    ),
                  ),
                  Text(
                    '${context.l10n.qiblaDistanceToKaaba(_distanceKm().toStringAsFixed(0))} • ${_pos!.latitude.toStringAsFixed(4)}, ${_pos!.longitude.toStringAsFixed(4)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurface.withValues(alpha: .72),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 260,
                    child: StreamBuilder<CompassEvent>(
                      stream: FlutterCompass.events,
                      builder: (ctx, snap) {
                        final heading = snap.data?.heading;
                        if (heading == null) {
                          return Center(
                            child: Text(
                              context.l10n.qiblaCompassUnavailable,
                            ),
                          );
                        }
                        final needle = (bearing - heading) * math.pi / 180;
                        return RepaintBoundary(
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                width: 220,
                                height: 220,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: scheme.outline.withValues(
                                      alpha: .25,
                                    ),
                                    width: 1.5,
                                  ),
                                  color: scheme.surfaceContainerHighest
                                      .withValues(alpha: .30),
                                ),
                              ),
                              ...List.generate(12, (i) {
                                final a = i * 30 * math.pi / 180;
                                return Transform.rotate(
                                  angle: a,
                                  child: Align(
                                    alignment: Alignment.topCenter,
                                    child: Container(
                                      margin: const EdgeInsets.only(top: 14),
                                      width: i % 3 == 0 ? 3 : 1.5,
                                      height: i % 3 == 0 ? 14 : 8,
                                      color: scheme.onSurface.withValues(
                                        alpha: .45,
                                      ),
                                    ),
                                  ),
                                );
                              }),
                              Transform.rotate(
                                angle: needle,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.navigation_rounded,
                                      size: 64,
                                      color: scheme.primary,
                                    ),
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: scheme.primary,
                                        borderRadius: BorderRadius.circular(99),
                                      ),
                                      child: Text(
                                        'KAKBAH',
                                        style: TextStyle(
                                          color: scheme.onPrimary,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Positioned(
                                bottom: 8,
                                child: Text(
                                  '${heading.toStringAsFixed(0)}°',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: scheme.onSurface.withValues(
                                      alpha: .72,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    context.l10n.qiblaAlignHint,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurface.withValues(alpha: .72),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          LiquidGlassCard(
            radius: 16,
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Icon(Icons.explore_outlined, color: scheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    context.l10n.qiblaSourceNote,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
