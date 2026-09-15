import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:orcweather/idot.dart';
import 'package:orcweather/librewxr.dart';
import 'package:orcweather/nws.dart';
import 'package:orcweather/road_risk.dart';
import 'package:orcweather/wzdx.dart';

const peoria = LatLng(40.6936, -89.5890);

// Registry rows as served by datahub.transportation.gov on 2026-09-14 (trimmed).
const registry = '''[
 {"state":"oklahoma","feedname":"odot","url":{"url":"https://oktraffic.org/api/Geojsons/workzones"},"format":"geojson","active":true,"needapikey":false},
 {"state":"Illinois","feedname":"idot_cwz","url":{"url":"https://wzad-idot.illinois.gov/cwz/01.00?api_key=KEY"},"active":true,"needapikey":true},
 {"state":"illinois","feedname":"iltollway","url":{"url":"https://tims2go.tollway.state.il.us/wzdx/v4.2?api_key=KEY"},"active":true,"needapikey":true},
 {"state":"New Hampshire, Vermont, Maine","feedname":"necdot","url":{"url":"https://example.org/necdot"},"active":true,"needapikey":false},
 {"state":"michigan","feedname":"michigandot","active":false,"needapikey":false}
]''';

// One feature from the live Oklahoma DOT WZDx 4.0 feed, 2026-09-14; second is a MultiPoint far away.
const wzdxFeed = '''{"type":"FeatureCollection","features":[
 {"type":"Feature","geometry":{"type":"LineString","coordinates":[[-89.60,40.70],[-89.61,40.71]]},
  "properties":{"core_details":{"event_type":"work-zone","road_names":["I-240 E","I-240 W"],"direction":"westbound","description":"GRADE, DRAIN, SURFACE, AND BRIDGE"}}},
 {"type":"Feature","geometry":{"type":"MultiPoint","coordinates":[[-97.5,35.4],[-97.6,35.4]]},
  "properties":{"core_details":{"event_type":"work-zone","road_names":["SH-9"],"description":"far away"}}},
 {"type":"Feature","geometry":null,"properties":{"core_details":{"road_names":["no geom"]}}}]}''';

// IDOT FeatureServer/2 query response shape, f=geojson, 2026-09-14.
const idotFeed = '''{"type":"FeatureCollection","features":[
 {"type":"Feature","id":142,"geometry":{"type":"MultiLineString","coordinates":[[[-89.8754,40.5295],[-89.8752,40.5294]],[[-89.8750,40.5299],[-89.8749,40.5298]]]},
  "properties":{"WrcMntSectionName":"212 - LYNN CENTER (HENRY)","COUNTY_NAM":"HENRY","Condition":"Covered with ice or snow"}},
 {"type":"Feature","id":143,"geometry":{"type":"LineString","coordinates":[[-89.5,40.6],[-89.4,40.6]]},
  "properties":{"WrcMntSectionName":"334 - PONTIAC (LASALLE)","COUNTY_NAM":"LASALLE","Condition":"Clear"}}]}''';

Conditions cond({int temp = 70, int? precip, String forecast = 'Sunny'}) => Conditions(
    temperatureF: temp, windSpeed: '5 mph', windDirection: 'N', shortForecast: forecast, precipChance: precip, humidity: null);

WeatherAlert alert(String title) =>
    WeatherAlert(title: title, severity: 'Moderate', expires: DateTime(2030), description: '', polygons: const []);

void main() {
  group('WZDx', () {
    test('registry filter: keyless, active, state match incl. multi-state rows', () {
      expect(Wzdx.feedUrlsIn(registry, 'oklahoma'), ['https://oktraffic.org/api/Geojsons/workzones']);
      expect(Wzdx.feedUrlsIn(registry, 'illinois'), isEmpty); // both IL feeds need keys
      expect(Wzdx.feedUrlsIn(registry, 'vermont'), ['https://example.org/necdot']);
      expect(Wzdx.feedUrlsIn(registry, 'michigan'), isEmpty);
    });

    test('parses LineString + MultiPoint, skips null geometry, filters by radius', () {
      final zones = WorkZone.parse(wzdxFeed);
      expect(zones, hasLength(2));
      expect(zones[0].road, 'I-240 E / I-240 W');
      expect(zones.where((z) => z.within(peoria, 80467)).map((z) => z.road), ['I-240 E / I-240 W']);
    });

    test('near(): state -> registry -> feeds -> radius; one dead feed does not kill the rest', () async {
      final client = MockClient((r) async {
        if (r.url.host.contains('datahub')) {
          return http.Response(registry.replaceAll('"oklahoma"', '"illinois"').replaceAll('"needapikey":true', '"needapikey":false'), 200);
        }
        if (r.url.host == 'oktraffic.org') return http.Response(wzdxFeed, 200);
        return http.Response('down', 503);
      });
      final zones = await Wzdx(client).near(peoria, 80467, 'IL');
      expect(zones.map((z) => z.road), ['I-240 E / I-240 W']);
    });

    test('unknown state -> no feeds, no registry call', () async {
      var calls = 0;
      final client = MockClient((_) async { calls++; return http.Response('[]', 200); });
      expect(await Wzdx(client).near(peoria, 1, 'ZZ'), isEmpty);
      expect(calls, 0);
    });
  });

  group('IDOT', () {
    test('parses MultiLineString and LineString sections with condition', () {
      final roads = RoadCondition.parse(idotFeed);
      expect(roads, hasLength(2));
      expect(roads[0].isClear, isFalse);
      expect(roads[0].lines, hasLength(2));
      expect(roads[0].lines[0][0], const LatLng(40.5295, -89.8754));
      expect(roads[1].isClear, isTrue);
    });

    test('query asks the server for a radius around the point in WGS84 GeoJSON', () async {
      late Uri seen;
      final client = MockClient((r) async { seen = r.url; return http.Response(idotFeed, 200); });
      await Idot(client).near(peoria, 80467);
      expect(seen.path, endsWith('/FeatureServer/2/query'));
      final q = seen.queryParameters;
      expect(q['geometry'], '-89.589,40.6936');
      expect(q['distance'], '80467');
      expect(q['units'], 'esriSRUnit_Meter');
      expect(q['f'], 'geojson');
      expect(q['outSR'], '4326');
    });
  });

  group('road risk', () {
    test('nothing suspicious -> null', () => expect(roadRisk(cond(), const []), isNull));
    test('freezing + precip -> ice', () => expect(roadRisk(cond(temp: 30, precip: 60), const []), startsWith('Ice risk')));
    test('warm + precip -> wet', () => expect(roadRisk(cond(temp: 60, precip: 60), const []), 'Wet roads likely'));
    test('snow in forecast text counts as precip', () => expect(roadRisk(cond(temp: 28, forecast: 'Light Snow'), const []), startsWith('Ice risk')));
    test('alerts win over conditions', () {
      expect(roadRisk(cond(), [alert('Winter Storm Warning')]), 'Snow risk (alert)');
      expect(roadRisk(cond(), [alert('Ice Storm Warning')]), 'Ice risk (alert)');
      expect(roadRisk(cond(), [alert('Dense Fog Advisory')]), 'Low visibility (alert)');
      expect(roadRisk(null, [alert('Flood Warning')]), 'Flooding risk (alert)');
    });
    test('unrelated alert -> falls through', () => expect(roadRisk(cond(), [alert('Heat Advisory')]), isNull));
  });

  test('NWS conditions carry the state from /points', () async {
    final client = MockClient((r) async => http.Response(
        r.url.path.startsWith('/points')
            ? '{"properties":{"forecastHourly":"https://api.weather.gov/gridpoints/ILX/1,1/forecast/hourly","relativeLocation":{"properties":{"city":"Peoria","state":"IL"}}}}'
            : '{"properties":{"periods":[{"temperature":70,"windSpeed":"5 mph","windDirection":"N","shortForecast":"Sunny"}]}}',
        200));
    expect((await Nws(client).conditions(peoria)).state, 'IL');
  });
}
