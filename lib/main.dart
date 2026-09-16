import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'config.dart';
import 'idot.dart';
import 'librewxr.dart';
import 'nws.dart';
import 'road_risk.dart';
import 'settings.dart';
import 'wzdx.dart';

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
  late final _wzdx = Wzdx(_client);
  late final _idot = Idot(_client);
  final _settings = Settings(SharedPreferencesAsync());

  LatLng? _position;
  double _headingDeg = 0; // course over ground from GPS; meaningful only while moving
  RadarFrame? _radar;
  List<WeatherAlert> _alerts = const [];
  Conditions? _conditions;
  List<WorkZone> _workZones = const [];
  List<RoadCondition> _roads = const [];
  String? _roadsState; // state the road layers were last fetched for
  DateTime? _roadsAt;
  String? _error;
  StreamSubscription<Position>? _positionSub;
  Timer? _refresh;
  bool _followPosition = true;

  static const _refreshEvery = Duration(minutes: 5);
  static const _roadsEvery = Duration(minutes: 30);
  static const _radiusMeters = radiusMiles * metersPerMile;

  @override
  void initState() {
    super.initState();
    _settings.addListener(() => setState(() {}));
    _settings.load();
    _startLocation();
    _refresh = Timer.periodic(_refreshEvery, (_) => _refreshWeather());
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _refresh?.cancel();
    _client.close();
    _settings.dispose();
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
      setState(() {
        _position = LatLng(p.latitude, p.longitude);
        if (p.heading >= 0 && p.speed > 1) _headingDeg = p.heading; // ponytail: GPS course only; compass when standing still needs a sensor plugin
      });
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
      await _refreshRoads(here, _conditions?.state);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  /// Road layers are statewide downloads (up to ~10 MB): only on state change or every 30 min.
  Future<void> _refreshRoads(LatLng here, String? state) async {
    if (state == null) return;
    final stale = _roadsAt == null || DateTime.now().difference(_roadsAt!) > _roadsEvery;
    if (state == _roadsState && !stale) return;
    _roadsState = state;
    _roadsAt = DateTime.now();
    final zones = await _wzdx.near(here, _radiusMeters, state);
    final roads = state == 'IL' ? await _idot.near(here, _radiusMeters) : const <RoadCondition>[];
    if (mounted) setState(() { _workZones = zones; _roads = roads; });
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
              interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
              onPositionChanged: (_, hasGesture) {
                if (hasGesture) _followPosition = false;
              },
            ),
            children: [
              ColorFiltered(
                colorFilter: _settings.darkMap(MediaQuery.platformBrightnessOf(context))
                    ? const ColorFilter.matrix(_darkTiles)
                    : const ColorFilter.mode(Colors.transparent, BlendMode.dst),
                child: TileLayer(urlTemplate: baseTileUrl, userAgentPackageName: applicationId),
              ),
              if (_radar != null)
                Opacity(
                  opacity: 0.6,
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
              PolylineLayer(polylines: [
                for (final r in _roads)
                  if (!r.isClear)
                    for (final line in r.lines)
                      Polyline(points: line, color: _conditionColor(r.condition), strokeWidth: 5),
                for (final z in _workZones)
                  Polyline(points: z.points, color: Colors.orange, strokeWidth: 3),
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
                  Marker(
                    point: here,
                    width: 28,
                    height: 28,
                    child: Transform.rotate(
                      angle: _headingDeg * math.pi / 180,
                      child: const Icon(Icons.navigation, color: Colors.lightBlueAccent, size: 28),
                    ),
                  ),
                ]),
              ],
              RichAttributionWidget(
                alignment: AttributionAlignment.bottomRight,
                popupInitialDisplayDuration: const Duration(seconds: 5),
                attributions: [
                  TextSourceAttribution(baseAttribution, onTap: () => launchUrl(Uri.parse('https://openstreetmap.org/copyright'))),
                  TextSourceAttribution(librewxrAttribution, onTap: () => launchUrl(Uri.parse('https://librewxr.net'))),
                  const TextSourceAttribution('Precipitation data from NOAA Enterprise Rain Rate (RRQPE)'),
                  const TextSourceAttribution('Conditions and warnings from the US National Weather Service'),
                  const TextSourceAttribution('Road conditions from Illinois DOT; work zones via USDOT WZDx'),
                  const TextSourceAttribution('Not an official warning source. Estimates are marked as such.', prependCopyright: false),
                ],
              ),
            ],
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.bottomRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 44, bottom: 4),
                child: IconButton.filledTonal(
                  tooltip: 'Settings',
                  icon: const Icon(Icons.settings),
                  onPressed: () => showDialog<void>(context: context, builder: (_) => _SettingsDialog(settings: _settings)),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 300),
                      child: _ConditionsPanel(
                        settings: _settings,
                        conditions: _conditions,
                        alerts: _alerts,
                        error: _error,
                        roadRisk: roadRisk(_conditions, _alerts),
                        reportedBad: _roads.where((r) => !r.isClear).length,
                        workZones: _workZones.length,
                      ),
                    ),
                    const SizedBox(height: 8),
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

Color _conditionColor(String condition) => switch (condition) {
      'Covered with ice or snow' => Colors.deepPurpleAccent,
      'Mostly Covered with ice or snow' => Colors.redAccent,
      'Partly Covered with ice or snow' => Colors.amberAccent,
      _ => Colors.transparent,
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

class _ConditionsPanel extends StatefulWidget {
  const _ConditionsPanel({
    required this.settings,
    required this.conditions,
    required this.alerts,
    required this.error,
    required this.roadRisk,
    required this.reportedBad,
    required this.workZones,
  });
  final Settings settings;
  final Conditions? conditions;
  final List<WeatherAlert> alerts;
  final String? error;
  final String? roadRisk;
  final int reportedBad; // IDOT sections not "Clear" within range
  final int workZones;

  @override
  State<_ConditionsPanel> createState() => _ConditionsPanelState();
}

class _ConditionsPanelState extends State<_ConditionsPanel> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.conditions;
    final alerts = widget.alerts;
    final worst = alerts.isEmpty ? null : alerts.reduce((a, b) => _rank(a.severity) >= _rank(b.severity) ? a : b);
    final text = Theme.of(context).textTheme;
    final roadsBad = widget.reportedBad > 0 || widget.roadRisk != null;
    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: Card(
        margin: EdgeInsets.zero,
        color: Colors.black.withValues(alpha: 0.7),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: c == null
              ? Text(widget.error ?? 'Locating…', style: text.bodyLarge)
              : _expanded
                  ? _full(c, worst, text)
                  : _compact(c, worst, roadsBad, text),
        ),
      ),
    );
  }

  /// One row: sky icon + temp · wind · precip · alerts · roads · work zones.
  Widget _compact(Conditions c, WeatherAlert? worst, bool roadsBad, TextTheme text) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _chip(_skyIcon(c.shortForecast), widget.settings.formatTemp(c.temperatureF), text),
          _chip(Icons.air, '${c.windDirection} ${c.windSpeed.replaceAll(' mph', '')}', text),
          if ((c.precipChance ?? 0) > 0) _chip(Icons.umbrella, '${c.precipChance}%', text),
          if (worst != null) _chip(Icons.warning_amber, '${widget.alerts.length}', text, color: _severityColor(worst.severity)),
          if (roadsBad) _chip(Icons.ac_unit, widget.reportedBad > 0 ? '${widget.reportedBad}' : '!', text, color: widget.reportedBad > 0 ? Colors.redAccent : Colors.amberAccent),
          if (widget.workZones > 0) _chip(Icons.construction, '${widget.workZones}', text, color: Colors.orange),
        ],
      );

  Widget _chip(IconData icon, String label, TextTheme text, {Color? color}) => Padding(
        padding: const EdgeInsets.only(right: 10),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 18, color: color ?? Colors.white70),
          const SizedBox(width: 3),
          Text(label, style: text.bodyMedium?.copyWith(color: color, fontWeight: FontWeight.w600)),
        ]),
      );

  Widget _full(Conditions c, WeatherAlert? worst, TextTheme text) {
    final alerts = widget.alerts;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('${widget.settings.formatTemp(c.temperatureF)}  ${c.shortForecast}', style: text.headlineSmall),
        Text('Wind ${c.windDirection} ${c.windSpeed}'
            '${c.precipChance != null ? '  ·  Precip ${c.precipChance}%' : ''}'
            '${c.humidity != null ? '  ·  RH ${c.humidity}%' : ''}', style: text.bodyLarge),
        if (worst != null) ...[
          const SizedBox(height: 6),
          Text('${alerts.length} alert${alerts.length == 1 ? '' : 's'} within ${radiusMiles.round()} mi',
              style: text.labelLarge?.copyWith(color: _severityColor(worst.severity))),
          Text(worst.title, style: text.bodyMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
        ],
        if (widget.reportedBad > 0 || widget.roadRisk != null || widget.workZones > 0) ...[
          const SizedBox(height: 6),
          if (widget.reportedBad > 0)
            Text('Roads: ${widget.reportedBad} section${widget.reportedBad == 1 ? '' : 's'} reported snow/ice (IDOT)',
                style: text.bodyMedium?.copyWith(color: Colors.redAccent)),
          if (widget.roadRisk != null)
            Text('Roads: ${widget.roadRisk} — estimate', style: text.bodyMedium?.copyWith(color: Colors.amberAccent)),
          if (widget.workZones > 0)
            Text('${widget.workZones} work zone${widget.workZones == 1 ? '' : 's'} within ${radiusMiles.round()} mi', style: text.bodySmall),
        ],
        if (widget.error != null) Text(widget.error!, style: text.bodySmall?.copyWith(color: Colors.orangeAccent)),
      ],
    );
  }

  static int _rank(String s) => const {'Minor': 0, 'Moderate': 1, 'Severe': 2, 'Extreme': 3}[s] ?? 0;
}

/// Inverted grayscale: dark ground, light roads, no orange water. Base tiles only.
const _darkTiles = <double>[
  -0.2126, -0.7152, -0.0722, 0, 255,
  -0.2126, -0.7152, -0.0722, 0, 255,
  -0.2126, -0.7152, -0.0722, 0, 255,
  0, 0, 0, 1, 0,
];

class _SettingsDialog extends StatelessWidget {
  const _SettingsDialog({required this.settings});
  final Settings settings;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: settings,
        builder: (context, _) => AlertDialog(
          title: const Text('Settings'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Temperature scale'),
              const SizedBox(height: 6),
              SegmentedButton<TempUnit>(
                segments: const [ButtonSegment(value: TempUnit.f, label: Text('°F')), ButtonSegment(value: TempUnit.c, label: Text('°C'))],
                selected: {settings.tempUnit},
                onSelectionChanged: (s) => settings.setTempUnit(s.first),
              ),
              const SizedBox(height: 18),
              const Text('Map theme'),
              const SizedBox(height: 6),
              SegmentedButton<MapTheme>(
                segments: const [
                  ButtonSegment(value: MapTheme.light, label: Text('Light')),
                  ButtonSegment(value: MapTheme.dark, label: Text('Dark')),
                  ButtonSegment(value: MapTheme.auto, label: Text('Auto')),
                ],
                selected: {settings.mapTheme},
                onSelectionChanged: (s) => settings.setMapTheme(s.first),
              ),
              const SizedBox(height: 6),
              Text('Auto follows the phone\'s dark mode.', style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Done'))],
        ),
      );
}

IconData _skyIcon(String forecast) {
  final f = forecast.toLowerCase();
  if (f.contains('thunder')) return Icons.thunderstorm;
  if (f.contains('snow') || f.contains('sleet') || f.contains('ice')) return Icons.ac_unit;
  if (f.contains('rain') || f.contains('shower') || f.contains('drizzle')) return Icons.water_drop;
  if (f.contains('fog') || f.contains('haze') || f.contains('smoke')) return Icons.foggy;
  if (f.contains('cloud') || f.contains('overcast')) return Icons.cloud;
  return Icons.wb_sunny;
}
