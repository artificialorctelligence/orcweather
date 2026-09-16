import 'package:flutter/material.dart' show Color;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:orcweather/config.dart';
import 'package:orcweather/librewxr.dart';
import 'package:orcweather/nws_colors.dart';

// Shapes copied from live api.librewxr.net responses on 2026-09-14.
const weatherMaps = '''
{"version":"2.0","generated":1789429025,"host":"https://api.librewxr.net",
 "radar":{"past":[{"time":1789422000,"path":"/v2/radar/1789422000"},
                  {"time":1789428600,"path":"/v2/radar/1789428600"}],
          "nowcast":[{"time":1789429200,"path":"/v2/radar/1789429200"}]},
 "colorSchemes":[{"id":0,"name":"Black and White"}]}''';

const alerts = '''
{"type":"FeatureCollection","features":[
 {"type":"Feature","geometry":{"type":"Polygon","coordinates":[[[-97.6,35.4],[-97.4,35.4],[-97.4,35.6],[-97.6,35.4]]]},
  "properties":{"title":"Severe Thunderstorm Warning","severity":"Severe","time":1789411331,"expires":1789468931,
   "description":"Wind gusts to 70 mph.","regions":["Oklahoma County"],"uri":"https://example/cap.xml"}},
 {"type":"Feature","geometry":{"type":"MultiPolygon","coordinates":[[[[-98,36],[-97,36],[-97,37],[-98,36]]],[[[-99,36],[-98.5,36],[-98.5,36.5],[-99,36]]]]},
  "properties":{"title":"yellow advisory - frost - in effect","severity":"Moderate","time":1,"expires":2,
   "description":"Frost.","regions":["Somewhere"],"uri":"https://example/cap2.xml"}}]}''';

void main() {
  test('parses radar frames and builds a tile template', () {
    final f = RadarFrames.parse(weatherMaps);
    expect(f.host, 'https://api.librewxr.net');
    expect(f.past, hasLength(2));
    expect(f.nowcast, hasLength(1));
    expect(f.latest.time, 1789428600);
    expect(f.latest.tileUrl(f.host),
        'https://api.librewxr.net/v2/radar/1789428600/256/{z}/{x}/{y}/$librewxrColorScheme/1_1.png');
  });

  test('parses Polygon and MultiPolygon alerts', () {
    final a = WeatherAlert.parse(alerts);
    expect(a, hasLength(2));
    expect(a[0].severity, 'Severe');
    expect(a[0].polygons, hasLength(1));
    expect(a[0].polygons[0][0], const LatLng(35.4, -97.6)); // lon,lat -> LatLng(lat,lon)
    expect(a[0].expires.toUtc().year, 2026);
    expect(a[1].polygons, hasLength(2));
  });

  test('client sends User-Agent and a bbox around the point', () async {
    late Uri seen;
    late Map<String, String> headers;
    final client = MockClient((r) async {
      seen = r.url;
      headers = r.headers;
      return http.Response(alerts, 200);
    });
    final result = await LibreWxr(client).alertsAround(const LatLng(35.5, -97.5), 80467);
    expect(result, hasLength(2));
    expect(headers['User-Agent'], appUserAgent);
    expect(seen.path, '/v2/alerts');
    final b = seen.queryParameters['bbox']!.split(',').map(double.parse).toList();
    expect(b[0], lessThan(-97.5)); // west
    expect(b[1], lessThan(35.5)); // south
    expect(b[2], greaterThan(-97.5)); // east
    expect(b[3], greaterThan(35.5)); // north
    expect(b[3] - b[1], closeTo(1.45, 0.05)); // ~50 mi each way in degrees latitude
    // Each edge is exactly the radius away, in the order west,south,east,north.
    const d = Distance();
    const c = LatLng(35.5, -97.5);
    expect(b[0], closeTo(d.offset(c, 80467, 270).longitude, 1e-9));
    expect(b[1], closeTo(d.offset(c, 80467, 180).latitude, 1e-9));
    expect(b[2], closeTo(d.offset(c, 80467, 90).longitude, 1e-9));
    expect(b[3], closeTo(d.offset(c, 80467, 0).latitude, 1e-9));
  });

  test('event name and kind from titles; NWS colours', () {
    expect(eventOf('Severe Thunderstorm Warning issued September 15 at 10:27PM EDT until 10:45PM EDT by NWS Northern Indiana'), 'Severe Thunderstorm Warning');
    expect(eventOf('yellow advisory - frost - in effect'), 'yellow advisory - frost - in effect');
    expect(kindOf('Tornado Watch'), HazardKind.watch);
    expect(kindOf('Flash Flood Warning'), HazardKind.warning);
    expect(kindOf('Heat Advisory'), HazardKind.other);
    expect(hazardColor('Tornado Warning', 'Extreme'), const Color(0xFFFF0000));
    expect(hazardColor('Severe Thunderstorm Warning', 'Severe'), const Color(0xFFFFA500));
    expect(hazardColor('Tornado Watch', 'Severe'), const Color(0xFFFFFF00));
    expect(hazardColor('Winter Storm Warning', 'Severe'), const Color(0xFFFF69B4));
    expect(hazardColor('yellow advisory - frost - in effect', 'Moderate'), severityFallback('Moderate'));
    expect(hazardPriority('Tornado Warning'), lessThan(hazardPriority('Severe Thunderstorm Warning')));
    expect(hazardPriority('Severe Thunderstorm Warning'), lessThan(hazardPriority('Flood Watch')));
    expect(WeatherAlert.parse(alerts).first.event, 'Severe Thunderstorm Warning');
  });

  test('non-200 throws', () {
    final client = MockClient((_) async => http.Response('nope', 503));
    expect(LibreWxr(client).frames(), throwsA(isA<http.ClientException>()));
  });
}
