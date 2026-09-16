import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:orcweather/main.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

/// Tiles never touch the network in tests: every tile is a 1×1 transparent PNG.
class _BlankTiles extends TileProvider {
  static final _png = base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==');
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) => MemoryImage(_png);
}

Position fix({double lat = 40.6936, double lon = -89.5890, double speed = 0, double heading = -1}) => Position(
      latitude: lat, longitude: lon, timestamp: DateTime(2026, 9, 15, 18), accuracy: 5, altitude: 150,
      altitudeAccuracy: 5, heading: heading, headingAccuracy: 5, speed: speed, speedAccuracy: 1);

// Response shapes captured live 2026-09-14/15; a Severe Thunderstorm Warning polygon covers the position.
const _weatherMaps = '{"version":"2.0","generated":1789429025,"host":"https://api.librewxr.net","radar":{"past":[{"time":1789428600,"path":"/v2/radar/1789428600"}],"nowcast":[]},"colorSchemes":[]}';
const _alerts = '''{"type":"FeatureCollection","features":[
 {"type":"Feature","geometry":{"type":"Polygon","coordinates":[[[-90.2,40.3],[-89.0,40.3],[-89.0,41.1],[-90.2,41.1],[-90.2,40.3]]]},
  "properties":{"title":"Severe Thunderstorm Warning issued September 15 at 6:15PM CDT until September 15 at 7:00PM CDT by NWS Lincoln IL","severity":"Severe","time":1789430000,"expires":1789433000,
   "description":"SVRILX\\n\\n* At 615 PM CDT, a severe thunderstorm was located near Elmwood, moving east at 40 mph.","regions":["Peoria"],"uri":"urn:oid:1"}}]}''';
const _points = '{"properties":{"gridId":"ILX","forecastHourly":"https://api.weather.gov/gridpoints/ILX/1,1/forecast/hourly","relativeLocation":{"properties":{"city":"Peoria","state":"IL"}}}}';
const _hourly = '{"properties":{"periods":[{"temperature":98,"temperatureUnit":"F","windSpeed":"17 mph","windDirection":"S","shortForecast":"Chance Showers And Thunderstorms","probabilityOfPrecipitation":{"value":40},"relativeHumidity":{"value":33}}]}}';
const _idot = '{"type":"FeatureCollection","features":[{"type":"Feature","geometry":{"type":"LineString","coordinates":[[-89.7,40.7],[-89.5,40.7]]},"properties":{"WrcMntSectionName":"212 - PEORIA","COUNTY_NAM":"PEORIA","Condition":"Covered with ice or snow"}}]}';

// A cold, quiet day: no alerts, IDOT all Clear, one keyless Illinois WZDx feed with a zone nearby.
const _noAlerts = '{"type":"FeatureCollection","features":[]}';
const _hourlyCold = '{"properties":{"periods":[{"temperature":28,"temperatureUnit":"F","windSpeed":"8 mph","windDirection":"NW","shortForecast":"Light Snow","probabilityOfPrecipitation":{"value":60}}]}}';
const _idotClear = '{"type":"FeatureCollection","features":[{"type":"Feature","geometry":{"type":"LineString","coordinates":[[-89.7,40.7],[-89.5,40.7]]},"properties":{"WrcMntSectionName":"212 - PEORIA","COUNTY_NAM":"PEORIA","Condition":"Clear"}}]}';
const _registryIl = '[{"state":"illinois","feedname":"test","url":{"url":"https://wz.example.org/feed"},"active":true,"needapikey":false}]';
const _wzFeed = '{"type":"FeatureCollection","features":[{"type":"Feature","geometry":{"type":"LineString","coordinates":[[-89.60,40.70],[-89.61,40.71]]},"properties":{"core_details":{"event_type":"work-zone","road_names":["I-74"],"description":"Bridge work"}}}]}';

http.Client coldBackend(List<Uri> log) => MockClient((r) async {
      log.add(r.url);
      final u = r.url.toString();
      if (u.contains('weather-maps.json')) return http.Response(_weatherMaps, 200);
      if (u.contains('/v2/alerts')) return http.Response(_noAlerts, 200);
      if (u.contains('/points/')) return http.Response(_points, 200);
      if (u.contains('/forecast/hourly')) return http.Response(_hourlyCold, 200);
      if (u.contains('datahub.transportation.gov')) return http.Response(_registryIl, 200);
      if (u.contains('wz.example.org')) return http.Response(_wzFeed, 200);
      if (u.contains('IL_DOT_Winter_Road_Conditions')) return http.Response(_idotClear, 200);
      return http.Response('unexpected $u', 500);
    });

http.Client fakeBackend(List<Uri> log) => MockClient((r) async {
      log.add(r.url);
      final u = r.url.toString();
      if (u.contains('weather-maps.json')) return http.Response(_weatherMaps, 200);
      if (u.contains('/v2/alerts')) return http.Response(_alerts, 200);
      if (u.contains('/points/')) return http.Response(_points, 200);
      if (u.contains('/forecast/hourly')) return http.Response(_hourly, 200);
      if (u.contains('datahub.transportation.gov')) return http.Response('[]', 200);
      if (u.contains('IL_DOT_Winter_Road_Conditions')) return http.Response(_idot, 200);
      return http.Response('unexpected $u', 500);
    });

Future<void> pumpMap(WidgetTester tester, {required StreamController<Position> positions, required StreamController<double> headings, required List<Uri> log, http.Client? client}) async {
  await tester.pumpWidget(MaterialApp(
    home: MapScreen(client: client ?? fakeBackend(log), positions: positions.stream, headings: headings.stream, tileProvider: _BlankTiles()),
  ));
  await tester.pump();
}

/// Let the fake HTTP futures and the map settle; the screen has long-lived timers, so no pumpAndSettle.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  late StreamController<Position> positions;
  late StreamController<double> headings;
  late List<Uri> log;

  setUp(() {
    SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty();
    positions = StreamController<Position>.broadcast();
    headings = StreamController<double>.broadcast();
    log = [];
  });

  tearDown(() async {
    await positions.close();
    await headings.close();
  });

  testWidgets('before a fix: Locating…, no data fetched', (tester) async {
    await pumpMap(tester, positions: positions, headings: headings, log: log);
    expect(find.text('Locating…'), findsOneWidget);
    expect(log, isEmpty);
    await tester.pumpWidget(const SizedBox()); // dispose timers
  });

  testWidgets('first fix fetches everything and fills the strip; tap expands to the card', (tester) async {
    await pumpMap(tester, positions: positions, headings: headings, log: log);
    positions.add(fix());
    await settle(tester);

    expect(log.map((u) => u.host).toSet(), containsAll(['api.librewxr.net', 'api.weather.gov', 'datahub.transportation.gov', 'services2.arcgis.com']));
    expect(find.text('98°F'), findsOneWidget); // strip
    expect(find.text('S 17'), findsOneWidget);
    expect(find.text('40%'), findsOneWidget);
    expect(find.byIcon(Icons.thunderstorm), findsOneWidget);
    expect(find.byIcon(Icons.warning_amber), findsOneWidget);
    expect(find.byIcon(Icons.ac_unit), findsOneWidget); // IDOT reported section

    await tester.tap(find.text('98°F'));
    await tester.pump();
    expect(find.textContaining('Chance Showers And Thunderstorms'), findsOneWidget);
    expect(find.text('Severe Thunderstorm Warning'), findsOneWidget);
    expect(find.textContaining('1 section reported snow/ice (IDOT)'), findsOneWidget);
    expect(find.textContaining('Wet roads likely'), findsOneWidget); // 98°F + 40% precip

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('the 2-minute tick refetches weather but not the statewide road layers', (tester) async {
    await pumpMap(tester, positions: positions, headings: headings, log: log);
    positions.add(fix());
    await settle(tester);
    int calls(String host) => log.where((u) => u.host == host).length;
    final wx = calls('api.librewxr.net'), roads = calls('services2.arcgis.com'), wz = calls('datahub.transportation.gov');
    await tester.pump(const Duration(minutes: 2));
    await settle(tester);
    expect(calls('api.librewxr.net'), greaterThan(wx));
    expect(calls('services2.arcgis.com'), roads, reason: 'same state, under 30 min');
    expect(calls('datahub.transportation.gov'), wz);
    await tester.pumpWidget(const SizedBox());
  });

  Offset arrow(WidgetTester tester) => tester.getCenter(find.byIcon(Icons.navigation));
  Offset mapCenter(WidgetTester tester) => tester.getCenter(find.byType(FlutterMap));

  testWidgets('following: a new fix keeps the arrow centred; a drag stops that; recenter restores it', (tester) async {
    await pumpMap(tester, positions: positions, headings: headings, log: log);
    positions.add(fix());
    await settle(tester);
    expect((arrow(tester) - mapCenter(tester)).distance, lessThan(2));

    positions.add(fix(lat: 40.75, lon: -89.50, speed: 20, heading: 45));
    await settle(tester);
    expect((arrow(tester) - mapCenter(tester)).distance, lessThan(2), reason: 'still following');

    await tester.drag(find.byType(FlutterMap), const Offset(150, 0));
    await settle(tester);
    positions.add(fix(lat: 40.80, lon: -89.45, speed: 20, heading: 45));
    await settle(tester);
    expect((arrow(tester) - mapCenter(tester)).distance, greaterThan(50), reason: 'drag turned following off');

    await tester.tap(find.byIcon(Icons.my_location));
    await settle(tester);
    expect((arrow(tester) - mapCenter(tester)).distance, lessThan(2), reason: 'recenter follows again');
    await tester.pumpWidget(const SizedBox());
  });

  Future<void> pinchOffCentre(WidgetTester tester) async {
    final c = mapCenter(tester);
    // Both fingers to the right of centre, spreading apart: zooms in and drifts the centre.
    final g1 = await tester.startGesture(c + const Offset(80, 0));
    final g2 = await tester.startGesture(c + const Offset(120, 0));
    await tester.pump(const Duration(milliseconds: 20));
    for (var i = 0; i < 5; i++) {
      await g1.moveBy(const Offset(-15, 0));
      await g2.moveBy(const Offset(15, 0));
      await tester.pump(const Duration(milliseconds: 20));
    }
    await g1.up();
    await g2.up();
    await settle(tester);
  }

  testWidgets('pinch with Center on zoom off: the map stays where the pinch left it', (tester) async {
    await pumpMap(tester, positions: positions, headings: headings, log: log);
    positions.add(fix());
    await settle(tester);
    await pinchOffCentre(tester);
    expect(find.textContaining('mi across'), findsOneWidget, reason: 'zoom badge shows on pinch');
    expect((arrow(tester) - mapCenter(tester)).distance, greaterThan(10));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('pinch with Center on zoom on: snaps back to the arrow and follows again, even after a drag', (tester) async {
    await SharedPreferencesAsync().setBool('centerOnZoom', true);
    await pumpMap(tester, positions: positions, headings: headings, log: log);
    positions.add(fix());
    await settle(tester);
    await tester.drag(find.byType(FlutterMap), const Offset(150, 0));
    await settle(tester);
    expect((arrow(tester) - mapCenter(tester)).distance, greaterThan(50));

    await pinchOffCentre(tester);
    expect((arrow(tester) - mapCenter(tester)).distance, lessThan(2), reason: 'pinch came home');

    positions.add(fix(lat: 40.75, lon: -89.50, speed: 20, heading: 45));
    await settle(tester);
    expect((arrow(tester) - mapCenter(tester)).distance, lessThan(2), reason: 'following resumed');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('zoom buttons with Center on zoom on recenter too', (tester) async {
    await SharedPreferencesAsync().setBool('centerOnZoom', true);
    await pumpMap(tester, positions: positions, headings: headings, log: log);
    positions.add(fix());
    await settle(tester);
    await tester.drag(find.byType(FlutterMap), const Offset(150, 0));
    await settle(tester);
    await tester.tap(find.byIcon(Icons.remove));
    await settle(tester);
    expect((arrow(tester) - mapCenter(tester)).distance, lessThan(2));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('tapping inside the warning polygon lists it', (tester) async {
    await pumpMap(tester, positions: positions, headings: headings, log: log);
    positions.add(fix());
    await settle(tester);

    await tester.tapAt(tester.getCenter(find.byType(FlutterMap)));
    await settle(tester);
    expect(find.text('Warning · until ${TimeOfDay.fromDateTime(DateTime.fromMillisecondsSinceEpoch(1789433000 * 1000).toLocal()).format(tester.element(find.byType(FlutterMap)))}'), findsOneWidget);
    expect(find.textContaining('severe thunderstorm was located near Elmwood'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('settings: °C converts the strip and persists', (tester) async {
    await pumpMap(tester, positions: positions, headings: headings, log: log);
    positions.add(fix());
    await settle(tester);

    await tester.tap(find.byTooltip('Settings'));
    await settle(tester);
    await tester.tap(find.text('°C'));
    await settle(tester);
    await tester.tap(find.text('Done'));
    await settle(tester);
    expect(find.text('37°C'), findsOneWidget);
    expect(await SharedPreferencesAsync().getString('tempUnit'), 'c'); // same in-memory store the screen wrote to

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('cold quiet day: estimated ice risk (amber !), a work zone, no alert chip; card wording', (tester) async {
    await pumpMap(tester, positions: positions, headings: headings, log: log, client: coldBackend(log));
    positions.add(fix());
    await settle(tester);

    expect(find.text('28°F'), findsOneWidget);
    expect(find.byIcon(Icons.warning_amber), findsNothing, reason: 'no alerts → no alert chip');
    expect(find.byIcon(Icons.ac_unit), findsNWidgets(2), reason: 'sky icon (snow) + roads chip');
    expect(find.text('!'), findsOneWidget, reason: 'estimated risk, nothing reported');
    expect(find.byIcon(Icons.construction), findsOneWidget);
    expect(find.text('1'), findsOneWidget, reason: 'one work zone');

    await tester.tap(find.text('28°F'));
    await tester.pump();
    expect(find.textContaining('Ice risk'), findsOneWidget);
    expect(find.textContaining('— estimate'), findsOneWidget);
    expect(find.textContaining('reported snow/ice'), findsNothing);
    expect(find.textContaining('1 work zone within 50 mi'), findsOneWidget);
    expect(find.textContaining('alert'), findsNothing);
    expect(find.textContaining('RH'), findsNothing, reason: 'humidity absent from this period');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('data sources dialog opens from the (i)', (tester) async {
    await pumpMap(tester, positions: positions, headings: headings, log: log);
    await tester.tap(find.byTooltip('Data sources'));
    await settle(tester);
    expect(find.text('Data sources'), findsOneWidget);
    expect(find.textContaining('OpenStreetMap'), findsWidgets);
    expect(find.textContaining('LibreWXR'), findsWidgets);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('zoom button shows the badge, then it goes away', (tester) async {
    await pumpMap(tester, positions: positions, headings: headings, log: log);
    positions.add(fix());
    await settle(tester);
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();
    expect(find.textContaining('mi across'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    expect(find.textContaining('mi across'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
}
