import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'compass.dart';
import 'config.dart';
import 'debug_alerts.dart';
import 'idot.dart';
import 'librewxr.dart';
import 'map_logic.dart';
import 'nws.dart';
import 'nws_colors.dart';
import 'road_risk.dart';
import 'settings.dart';
import 'wzdx.dart';

void main() => runApp(const OrcWeatherApp());

/// Android Auto: a second Flutter engine runs this on the car's map surface (see
/// android/.../car/FlutterSurface.kt). Map only — the car host draws the pane and buttons.
@pragma('vm:entry-point')
void carMain() => runApp(const OrcWeatherApp(car: true));

class OrcWeatherApp extends StatelessWidget {
  const OrcWeatherApp({super.key, this.car = false});
  final bool car;

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'orcweather',
        theme: ThemeData(colorSchemeSeed: Colors.blueGrey, brightness: Brightness.dark),
        home: MapScreen(car: car),
      );
}

class MapScreen extends StatefulWidget {
  /// Everything that leaves the process can be injected, so a widget test runs with fakes.
  const MapScreen({super.key, this.client, this.positions, this.headings, this.tileProvider, this.car = false});
  final http.Client? client;
  /// On the car screen: no phone chrome, no touch handling (the host owns input), zoom and
  /// conditions go over [carChannel].
  final bool car;
  final Stream<Position>? positions;
  final Stream<double>? headings;
  final TileProvider? tileProvider;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final _map = MapController();
  late final _client = widget.client ?? http.Client();
  late final _wxr = LibreWxr(_client);
  late final _nws = Nws(_client);
  late final _wzdx = Wzdx(_client);
  late final _idot = Idot(_client);
  final _settings = Settings(SharedPreferencesAsync());
  final _alertHits = LayerHitNotifier<WeatherAlert>(null);
  static const carChannel = MethodChannel('orcweather/car');

  LatLng? _position;
  double _headingDeg = 0;
  bool _moving = false; // GPS course wins while moving (car bodies skew the compass); compass when stopped
  StreamSubscription<double>? _compassSub;
  Timer? _attributionBanner;
  Timer? _zoomBadgeTimer;
  Timer? _carRecenter; // car: follow again 15 s after the last pan/zoom gesture
  String? _zoomBadge; // shown for a moment after the zoom changes
  double _lastGestureZoom = 0;
  double? _zoomAtGestureStart;
  LatLng? _centerAtGestureStart;
  bool _recenterAfterGesture = false;
  bool _showAttribution = true; // OSMF guideline: visible at first, collapses to (i) after 5 s
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
  bool _mapReady = false;
  double _carMiles = defaultViewMiles; // car zoom button cycles this // flutter_map has laid out with a real size (never true while headless on the car)

  static const _refreshEvery = Duration(minutes: 2); // LibreWXR frames are 10 min apart; index is a tiny JSON
  static const _roadsEvery = Duration(minutes: 30);
  static const _radiusMeters = radiusMiles * metersPerMile;

  @override
  void initState() {
    super.initState();
    _settings.addListener(() => setState(() {}));
    _settings.load();
    _startLocation();
    _compassSub = (widget.headings ?? Compass().headings).listen((h) {
      if (!_moving) setState(() => _headingDeg = h);
    });
    _attributionBanner = Timer(const Duration(seconds: 5), () => setState(() => _showAttribution = false));
    if (widget.car) {
      carChannel.setMethodCallHandler((call) async {
        switch (call.method) {
          case 'zoom':
            _zoomBy((call.arguments as num).toDouble());
          case 'recenter':
            _fitRadius();
          case 'zoomCycle':
            _followPosition = true;
            _fitMiles(nextCarViewMiles(_carMiles));
          case 'panMode':
            if (call.arguments == false && _settings.centerOnZoom) _fitRadius();
          case 'pan':
            // Host scroll distances are in surface pixels; move the centre by that much.
            final d = (call.arguments as List).cast<num>();
            final cam = _map.camera;
            final centerPx = cam.latLngToScreenOffset(cam.center);
            _followPosition = false;
            _map.move(cam.screenOffsetToLatLng(centerPx + Offset(d[0].toDouble(), d[1].toDouble())), cam.zoom);
            _carRecenterLater();
          case 'scale':
            _map.move(_map.camera.center, _map.camera.zoom + math.log((call.arguments as num).toDouble()) / math.ln2);
            _carRecenterLater();
          case 'tap':
            final xy = (call.arguments as List).cast<num>();
            final hits = alertsAt(_map.camera.screenOffsetToLatLng(Offset(xy[0].toDouble(), xy[1].toDouble())), _alerts);
            debugPrint('orcweather car tap at $xy: ${hits.length} alert(s)');
            if (hits.isNotEmpty) {
              // Every alert under the finger, most urgent first, one breath each.
              final text = hits
                  .map((a) => spokenAlert(a, until: TimeOfDay.fromDateTime(a.expires.toLocal()).format(context)))
                  .join(' ');
              carChannel.invokeMethod('speak', text);
            }
        }
      });
    }
    _refresh = Timer.periodic(_refreshEvery, (_) => _refreshWeather());
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _compassSub?.cancel();
    _attributionBanner?.cancel();
    _zoomBadgeTimer?.cancel();
    _carRecenter?.cancel();
    _refresh?.cancel();
    _client.close();
    _settings.dispose();
    super.dispose();
  }

  Future<void> _startLocation() async {
    Stream<Position> positions;
    if (widget.positions != null) {
      positions = widget.positions!;
    } else {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        setState(() => _error = 'Location permission denied');
        return;
      }
      positions = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 25),
      );
    }
    _positionSub = positions.listen((p) {
      final first = _position == null;
      setState(() {
        _position = LatLng(p.latitude, p.longitude);
        _moving = movingFix(speedMps: p.speed, heading: p.heading);
        if (_moving) _headingDeg = p.heading;
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
        _alerts = [
          ...results[1] as List<WeatherAlert>,
          if (fakeAlertsEnabled) ...fakeAlertsAround(here),
        ];
        _conditions = results[2] as Conditions;
        _error = null;
      });
      await _refreshRoads(here, _conditions?.state);
      if (widget.car) _pushCarConditions();
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  /// No recenter button on the car (four strip slots: pan, speak, +, −): come home on our own.
  void _carRecenterLater() {
    _carRecenter?.cancel();
    _carRecenter = Timer(const Duration(seconds: 15), () {
      if (!mounted || _position == null) return;
      _followPosition = true;
      _map.move(_position!, _map.camera.zoom);
    });
  }

  /// What the car card shows (one line) and what the megaphone says.
  void _pushCarConditions() {
    final c = _conditions;
    final bad = _roads.where((r) => !r.isClear).length;
    final risk = roadRisk(c, _alerts);
    final roads = bad > 0 ? '$bad road section${bad == 1 ? '' : 's'} with snow or ice' : (risk == null ? null : 'roads: $risk (estimate)');
    final temp = c == null ? null : _settings.formatTemp(c.temperatureF);
    final wind = c == null ? null : '${c.windDirection} ${c.windSpeed}';
    carChannel.invokeMethod('conditions', {
      'strip': stripLine(temp: temp, sky: c?.shortForecast, wind: wind, alerts: _alerts.length, badRoads: bad, roadRisk: risk, workZones: _workZones.length),
      'spoken': spokenConditions(temp: temp, sky: c?.shortForecast, wind: wind, alerts: _alerts, roads: roads),
    });
  }

  /// Road layers are statewide downloads (up to ~10 MB): only on state change or every 30 min.
  Future<void> _refreshRoads(LatLng here, String? state) async {
    if (!roadsDue(state: state, lastState: _roadsState, lastAt: _roadsAt, now: DateTime.now(), every: _roadsEvery)) return;
    _roadsState = state!;
    _roadsAt = DateTime.now();
    final zones = await _wzdx.near(here, _radiusMeters, state);
    final roads = state == 'IL' ? await _idot.near(here, _radiusMeters) : const <RoadCondition>[];
    if (mounted) setState(() { _workZones = zones; _roads = roads; });
  }

  /// Zoom so [defaultViewMiles] around the position fills the short side of the screen.
  void _fitRadius() => _fitMiles(defaultViewMiles);

  void _fitMiles(double miles) {
    final here = _position;
    if (here == null || !_mapReady) return;
    final size = _map.camera.nonRotatedSize;
    if (size.shortestSide < 1) return; // headless (car engine before its surface): zoom would come out as 0
    _carMiles = miles;
    _map.fitCamera(CameraFit.bounds(bounds: fitBounds(here, miles * metersPerMile), padding: const EdgeInsets.all(16)));
    debugPrint('orcweather fit: $miles mi, size ${size.width.round()}x${size.height.round()}, zoom ${_map.camera.zoom.toStringAsFixed(2)}');
    _followPosition = true;
    _flashZoom();
  }

  /// A pinch reaches us as up to three gestures (first finger "drag", multi-finger, last finger "drag"),
  /// so decide by outcome: the map centre moved more than a thumb-wobble with no zoom change → a real
  /// drag → stop following; the zoom changed → a pinch → snap back to the car (and follow again) once
  /// any fling is over.
  void _onMapEvent(MapEvent e) {
    if (e is MapEventNonRotatedSizeChange && e.oldCamera.nonRotatedSize.shortestSide < 1 && e.camera.nonRotatedSize.shortestSide >= 1) {
      // The car surface just gave the headless map its first real size. This event fires during
      // layout; moving the camera inside it corrupts the camera, so fit on the next turn.
      Future<void>(() { if (mounted) _fitRadius(); });
      return;
    }
    if (e is MapEventMoveStart && e.source != MapEventSource.mapController) {
      _zoomAtGestureStart = e.camera.zoom;
      _centerAtGestureStart = e.camera.center;
    } else if (e is MapEventMoveEnd && _zoomAtGestureStart != null) {
      final movedPx = (e.camera.latLngToScreenOffset(_centerAtGestureStart!) - e.camera.latLngToScreenOffset(e.camera.center)).distance;
      final outcome = classifyGesture(zoomStart: _zoomAtGestureStart!, zoomEnd: e.camera.zoom, movedPx: movedPx);
      _zoomAtGestureStart = null;
      _centerAtGestureStart = null;
      switch (outcome) {
        case GestureOutcome.pinch when _settings.centerOnZoom:
          // "Center on zoom": a pinch comes home — recenter on the car and follow again, even after a drag.
          _followPosition = true;
          _recenterAfterGesture = true;
        case GestureOutcome.drag:
          _followPosition = false;
        case GestureOutcome.pinch || GestureOutcome.none:
          break;
      }
    } else if (e is MapEventFlingAnimationEnd || e is MapEventFlingAnimationNotStarted) {
      _snapBack();
    }
  }

  void _snapBack() {
    if (!_recenterAfterGesture || _position == null) return;
    _recenterAfterGesture = false;
    final here = _position!;
    // Next event-loop turn: outside flutter_map's event dispatch, and not tied to a frame that may never come.
    Future<void>(() {
      if (mounted) _map.move(here, _map.camera.zoom);
    });
  }

  void _zoomBy(double delta) {
    if (_settings.centerOnZoom && _position != null) {
      _followPosition = true;
      _map.move(_position!, _map.camera.zoom + delta);
    } else {
      _map.move(_map.camera.center, _map.camera.zoom + delta);
    }
    _flashZoom();
  }

  /// "Zoom 9 · 31 mi across" for 1.5 s. Miles = ground width of the screen's short side at this latitude.
  void _flashZoom() {
    final cam = _map.camera;
    _zoomBadgeTimer?.cancel();
    setState(() => _zoomBadge = zoomBadge(
          zoom: cam.zoom,
          latitude: cam.center.latitude,
          shortSidePx: math.min(cam.nonRotatedSize.width, cam.nonRotatedSize.height),
        ));
    _zoomBadgeTimer = Timer(const Duration(milliseconds: 1500), () => setState(() => _zoomBadge = null));
  }

  /// Every alert under the tap, most urgent first (NWS priority, then CAP severity).
  void _showAlerts(List<WeatherAlert> hits) {
    final seen = <WeatherAlert>{};
    final list = hits.where(seen.add).toList()
      ..sort((a, b) => hazardPriority(a.event).compareTo(hazardPriority(b.event)));
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => ListView.separated(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        itemCount: list.length,
        separatorBuilder: (_, _) => const Divider(height: 24),
        itemBuilder: (context, i) => _AlertTile(alert: list[i]),
      ),
    );
  }

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
              interactionOptions: InteractionOptions(
                flags: widget.car
                    ? InteractiveFlag.none
                    : InteractiveFlag.all & ~InteractiveFlag.rotate & ~InteractiveFlag.doubleTapZoom & ~InteractiveFlag.doubleTapDragZoom,
              ),
              onMapReady: () {
                _mapReady = true;
                _fitRadius(); // the first fix may have arrived before the map had a size (car: headless engine)
              },
              onPositionChanged: (camera, hasGesture) {
                if (hasGesture && (camera.zoom - _lastGestureZoom).abs() > 0.05) {
                  _lastGestureZoom = camera.zoom;
                  _flashZoom();
                }
              },
              onMapEvent: _onMapEvent,
            ),
            children: [
              ColorFiltered(
                colorFilter: _settings.darkMap(MediaQuery.platformBrightnessOf(context))
                    ? const ColorFilter.matrix(_darkTiles)
                    : const ColorFilter.mode(Colors.transparent, BlendMode.dst),
                child: TileLayer(urlTemplate: baseTileUrl, userAgentPackageName: applicationId, tileProvider: widget.tileProvider),
              ),
              if (_radar != null)
                Opacity(
                  opacity: 0.6,
                  child: TileLayer(urlTemplate: _radar!.tileUrl(librewxrHost), userAgentPackageName: applicationId, tileProvider: widget.tileProvider),
                ),
              GestureDetector(
                onTap: () {
                  final hits = _alertHits.value?.hitValues;
                  if (hits != null && hits.isNotEmpty) _showAlerts(hits);
                },
                child: PolygonLayer(
                  hitNotifier: _alertHits,
                  polygons: [
                    for (final a in _alerts)
                      for (final ring in a.polygons)
                        Polygon(
                          points: ring,
                          hitValue: a,
                          color: kindOf(a.event) == HazardKind.warning
                              ? hazardColor(a.event, a.severity).withValues(alpha: 0.2)
                              : Colors.transparent,
                          borderColor: hazardColor(a.event, a.severity),
                          borderStrokeWidth: kindOf(a.event) == HazardKind.other ? 1.5 : 2.5,
                        ),
                  ],
                ),
              ),
              IgnorePointer(child: PolylineLayer(polylines: [
                for (final r in _roads)
                  if (!r.isClear)
                    for (final line in r.lines)
                      Polyline(points: line, color: _conditionColor(r.condition), strokeWidth: 5),
                for (final z in _workZones)
                  Polyline(points: z.points, color: Colors.orange, strokeWidth: 3),
              ])),
              if (here != null) ...[
                IgnorePointer(child: CircleLayer(circles: [
                  CircleMarker(
                    point: here,
                    radius: defaultViewMiles * metersPerMile,
                    useRadiusInMeter: true,
                    color: Colors.transparent,
                    borderColor: Colors.white70,
                    borderStrokeWidth: 1.5,
                  ),
                ])),
                IgnorePointer(child: MarkerLayer(markers: [
                  Marker(
                    point: here,
                    width: 28,
                    height: 28,
                    child: Transform.rotate(
                      angle: _headingDeg * math.pi / 180,
                      child: const Icon(Icons.navigation, color: Colors.lightBlueAccent, size: 28),
                    ),
                  ),
                ])),
              ],
            ],
          ),
          if (!widget.car) ..._phoneChrome(context),
          if (widget.car)
            // Licence attribution lives on the map surface itself: the host's card text truncates,
            // and OSM/LibreWXR both require it readable. Bottom-left, clear of the host's strip.
            Positioned(
              left: 8,
              bottom: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(4)),
                child: Text(
                  '$baseAttribution · $librewxrAttribution · NWS · IDOT · NOAA RRQPE',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _phoneChrome(BuildContext context) => [
          if (_zoomBadge != null)
            SafeArea(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Card(
                    color: Colors.black.withValues(alpha: 0.75),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      child: Text(_zoomBadge!, style: Theme.of(context).textTheme.titleMedium),
                    ),
                  ),
                ),
              ),
            ),
          SafeArea(
            child: Align(
              alignment: Alignment.bottomRight,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (_showAttribution)
                      Card(
                        margin: const EdgeInsets.only(bottom: 6),
                        color: Colors.black.withValues(alpha: 0.7),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          child: Text('$baseAttribution · $librewxrAttribution · NWS', style: Theme.of(context).textTheme.bodySmall),
                        ),
                      ),
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      IconButton.filledTonal(
                        tooltip: 'Settings',
                        icon: const Icon(Icons.settings),
                        onPressed: () => showDialog<void>(context: context, builder: (_) => _SettingsDialog(settings: _settings)),
                      ),
                      const SizedBox(width: 6),
                      IconButton.filledTonal(
                        tooltip: 'Data sources',
                        icon: const Icon(Icons.info_outline),
                        onPressed: () => showDialog<void>(context: context, builder: (_) => const _SourcesDialog()),
                      ),
                    ]),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: SingleChildScrollView(
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
        ];
}

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
    final worst = worstAlert(alerts);
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
  Widget _compact(Conditions c, WeatherAlert? worst, bool roadsBad, TextTheme text) => Wrap(
        runSpacing: 4,
        children: [
          _chip(skyIcon(c.shortForecast), widget.settings.formatTemp(c.temperatureF), text),
          _chip(Icons.air, '${c.windDirection} ${c.windSpeed.replaceAll(' mph', '')}', text),
          if ((c.precipChance ?? 0) > 0) _chip(Icons.umbrella, '${c.precipChance}%', text),
          if (worst != null) _chip(Icons.warning_amber, '${widget.alerts.length}', text, color: hazardColor(worst.event, worst.severity)),
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
              style: text.labelLarge?.copyWith(color: hazardColor(worst.event, worst.severity))),
          Text(worst.event, style: text.bodyMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
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
}

class _AlertTile extends StatelessWidget {
  const _AlertTile({required this.alert});
  final WeatherAlert alert;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final color = hazardColor(alert.event, alert.severity);
    final kind = switch (kindOf(alert.event)) { HazardKind.warning => 'Warning', HazardKind.watch => 'Watch', HazardKind.other => alert.severity };
    final until = TimeOfDay.fromDateTime(alert.expires.toLocal()).format(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(width: 14, height: 14, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Expanded(child: Text(alert.event, style: text.titleMedium)),
        Text('$kind · until $until', style: text.labelMedium),
      ]),
      const SizedBox(height: 6),
      Text(briefDescription(alert.description), style: text.bodyMedium, maxLines: 6, overflow: TextOverflow.ellipsis),
    ]);
  }

}

/// Inverted grayscale: dark ground, light roads, no orange water. Base tiles only.
const _darkTiles = <double>[
  -0.2126, -0.7152, -0.0722, 0, 255,
  -0.2126, -0.7152, -0.0722, 0, 255,
  -0.2126, -0.7152, -0.0722, 0, 255,
  0, 0, 0, 1, 0,
];

class _SourcesDialog extends StatelessWidget {
  const _SourcesDialog();

  @override
  Widget build(BuildContext context) {
    Widget link(String text, String url) => TextButton(
        style: TextButton.styleFrom(padding: EdgeInsets.zero, alignment: Alignment.centerLeft),
        onPressed: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
        child: Text(text));
    final small = Theme.of(context).textTheme.bodyMedium;
    return AlertDialog(
      title: const Text('Data sources'),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        link('Map data $baseAttribution (ODbL)', 'https://openstreetmap.org/copyright'),
        link(librewxrAttribution, 'https://librewxr.net'),
        Text('Precipitation data from NOAA Enterprise Rain Rate (RRQPE)', style: small),
        link('Conditions and warnings: US National Weather Service', 'https://www.weather.gov'),
        Text('Road conditions: Illinois DOT · Work zones: USDOT WZDx', style: small),
        link('Map widget: flutter_map', 'https://github.com/fleaflet/flutter_map'),
        const SizedBox(height: 10),
        Text('Not an official warning source. Estimates are marked as such.', style: small?.copyWith(color: Colors.amberAccent)),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Done'))],
    );
  }
}

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
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Center on zoom'),
                subtitle: const Text('After a pinch or zoom button, jump back to your position and follow again'),
                value: settings.centerOnZoom,
                onChanged: settings.setCenterOnZoom,
              ),
            ],
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Done'))],
        ),
      );
}

