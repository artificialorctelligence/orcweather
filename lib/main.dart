import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import 'config.dart';
import 'librewxr.dart';
import 'nws.dart';

void main() => runApp(const OrcWeatherApp());

class OrcWeatherApp extends StatelessWidget {
  const OrcWeatherApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'orcweather',
        theme: ThemeData(colorSchemeSeed: Colors.blueGrey, brightness: Brightness.dark),
        home: const MapScreen(),
      );
}

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final _map = MapController();
  final _client = http.Client();
  late final _wxr = LibreWxr(_client);
  late final _nws = Nws(_client);

  LatLng? _position;
  RadarFrame? _radar;
  List<WeatherAlert> _alerts = const [];
  Conditions? _conditions;
  String? _error;
  StreamSubscription<Position>? _positionSub;
  Timer? _refresh;
  bool _followPosition = true;

  static const _refreshEvery = Duration(minutes: 5);
  static const _radiusMeters = radiusMiles * metersPerMile;

  @override
  void initState() {
    super.initState();
    _startLocation();
    _refresh = Timer.periodic(_refreshEvery, (_) => _refreshWeather());
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _refresh?.cancel();
    _client.close();
    super.dispose();
  }

  Future<void> _startLocation() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      setState(() => _error = 'Location permission denied');
      return;
    }
    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 25),
    ).listen((p) {
      final first = _position == null;
      setState(() => _position = LatLng(p.latitude, p.longitude));
      if (first) {
        _fitRadius();
        _refreshWeather();
      } else if (_followPosition) {
        _map.move(_position!, _map.camera.zoom);
      }
    }, onError: (Object e) => setState(() => _error = '$e'));
  }

  Future<void> _refreshWeather() async {
    final here = _position;
    if (here == null) return;
    try {
      final results = await Future.wait([
        _wxr.frames(),
        _wxr.alertsAround(here, _radiusMeters),
        _nws.conditions(here),
      ]);
      if (!mounted) return;
      setState(() {
        _radar = (results[0] as RadarFrames).latest;
        _alerts = results[1] as List<WeatherAlert>;
        _conditions = results[2] as Conditions;
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  /// Zoom so the 50-mile circle fills the short side of the screen.
  void _fitRadius() {
    final here = _position;
    if (here == null) return;
    const d = Distance();
    final bounds = LatLngBounds(
      d.offset(here, _radiusMeters, 315),
      d.offset(here, _radiusMeters, 135),
    );
    _map.fitCamera(CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(16)));
    _followPosition = true;
  }

  void _zoomBy(double delta) => _map.move(_map.camera.center, _map.camera.zoom + delta);

  @override
  Widget build(BuildContext context) {
    final here = _position;
    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _map,
            options: MapOptions(
              initialCenter: here ?? const LatLng(39.5, -98.35),
              initialZoom: here == null ? 4 : 8,
              onPositionChanged: (_, hasGesture) {
                if (hasGesture) _followPosition = false;
              },
            ),
            children: [
              TileLayer(urlTemplate: baseTileUrl, userAgentPackageName: applicationId),
              if (_radar != null)
                Opacity(
                  opacity: 0.7,
                  child: TileLayer(urlTemplate: _radar!.tileUrl(librewxrHost), userAgentPackageName: applicationId),
                ),
              PolygonLayer(polygons: [
                for (final a in _alerts)
                  for (final ring in a.polygons)
                    Polygon(
                      points: ring,
                      color: _severityColor(a.severity).withValues(alpha: 0.15),
                      borderColor: _severityColor(a.severity),
                      borderStrokeWidth: 2,
                    ),
              ]),
              if (here != null) ...[
                CircleLayer(circles: [
                  CircleMarker(
                    point: here,
                    radius: _radiusMeters,
                    useRadiusInMeter: true,
                    color: Colors.transparent,
                    borderColor: Colors.white70,
                    borderStrokeWidth: 1.5,
                  ),
                ]),
                MarkerLayer(markers: [
                  Marker(point: here, width: 24, height: 24, child: const Icon(Icons.navigation, color: Colors.lightBlueAccent)),
                ]),
              ],
              const SimpleAttributionWidget(source: Text('$baseAttribution · $librewxrAttribution · NWS')),
            ],
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: _ConditionsPanel(conditions: _conditions, alerts: _alerts, error: _error),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _ZoomButton(icon: Icons.add, onPressed: () => _zoomBy(1)),
                    const SizedBox(height: 8),
                    _ZoomButton(icon: Icons.remove, onPressed: () => _zoomBy(-1)),
                    const SizedBox(height: 8),
                    _ZoomButton(icon: Icons.my_location, onPressed: _fitRadius),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Color _severityColor(String severity) => switch (severity) {
      'Extreme' => Colors.purpleAccent,
      'Severe' => Colors.redAccent,
      'Moderate' => Colors.orangeAccent,
      _ => Colors.yellowAccent,
    };

class _ZoomButton extends StatelessWidget {
  const _ZoomButton({required this.icon, required this.onPressed});
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => FloatingActionButton.small(
        heroTag: icon.codePoint,
        onPressed: onPressed,
        child: Icon(icon, size: 28),
      );
}

class _ConditionsPanel extends StatelessWidget {
  const _ConditionsPanel({required this.conditions, required this.alerts, required this.error});
  final Conditions? conditions;
  final List<WeatherAlert> alerts;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final c = conditions;
    final worst = alerts.isEmpty ? null : alerts.reduce((a, b) => _rank(a.severity) >= _rank(b.severity) ? a : b);
    final text = Theme.of(context).textTheme;
    return Card(
      margin: const EdgeInsets.all(8),
      color: Colors.black.withValues(alpha: 0.7),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (c == null)
              Text(error ?? 'Locating…', style: text.bodyLarge)
            else ...[
              Text('${c.temperatureF}°F  ${c.shortForecast}', style: text.headlineSmall),
              Text('Wind ${c.windDirection} ${c.windSpeed}'
                  '${c.precipChance != null ? '  ·  Precip ${c.precipChance}%' : ''}'
                  '${c.humidity != null ? '  ·  RH ${c.humidity}%' : ''}', style: text.bodyLarge),
            ],
            if (worst != null) ...[
              const SizedBox(height: 6),
              Text('${alerts.length} alert${alerts.length == 1 ? '' : 's'} within ${radiusMiles.round()} mi',
                  style: text.labelLarge?.copyWith(color: _severityColor(worst.severity))),
              Text(worst.title, style: text.bodyMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
            if (c != null && error != null) Text(error!, style: text.bodySmall?.copyWith(color: Colors.orangeAccent)),
          ],
        ),
      ),
    );
  }

  static int _rank(String s) => const {'Minor': 0, 'Moderate': 1, 'Severe': 2, 'Extreme': 3}[s] ?? 0;
}
