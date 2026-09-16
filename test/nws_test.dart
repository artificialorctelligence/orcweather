import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:orcweather/config.dart';
import 'package:orcweather/nws.dart';

// Shapes copied from live api.weather.gov responses on 2026-09-14.
const points = '''{"properties":{"gridId":"OUN","forecastHourly":"https://api.weather.gov/gridpoints/OUN/97,94/forecast/hourly"}}''';
const hourly = '''{"properties":{"periods":[
 {"startTime":"2026-09-14T18:00:00-05:00","temperature":98,"temperatureUnit":"F","windSpeed":"17 mph","windDirection":"S",
  "shortForecast":"Mostly Clear","probabilityOfPrecipitation":{"unitCode":"wmoUnit:percent","value":1},
  "relativeHumidity":{"unitCode":"wmoUnit:percent","value":33}},
 {"startTime":"2026-09-14T19:00:00-05:00","temperature":95,"temperatureUnit":"F","windSpeed":"15 mph","windDirection":"S","shortForecast":"Clear"}]}}''';

void main() {
  test('parses the first hourly period', () {
    final c = Conditions.parse(hourly);
    expect(c.temperatureF, 98);
    expect(c.windSpeed, '17 mph');
    expect(c.windDirection, 'S');
    expect(c.precipChance, 1);
    expect(c.humidity, 33);
  });

  test('tolerates missing precip/humidity', () {
    const one = '{"properties":{"periods":[{"temperature":70,"windSpeed":"5 mph","windDirection":"N","shortForecast":"Sunny"}]}}';
    final c = Conditions.parse(one);
    expect(c.precipChance, isNull);
    expect(c.humidity, isNull);
  });

  test('non-200 from /points throws', () {
    final client = MockClient((_) async => http.Response('Service Unavailable', 503));
    expect(Nws(client).conditions(const LatLng(35.47, -97.52)), throwsA(isA<http.ClientException>()));
  });

  test('resolves /points then follows forecastHourly with a User-Agent', () async {
    final urls = <String>[];
    final client = MockClient((r) async {
      urls.add(r.url.toString());
      expect(r.headers['User-Agent'], appUserAgent);
      return http.Response(r.url.path.startsWith('/points') ? points : hourly, 200);
    });
    final c = await Nws(client).conditions(const LatLng(35.47, -97.52));
    expect(c.temperatureF, 98);
    expect(urls, [
      'https://api.weather.gov/points/35.4700,-97.5200',
      'https://api.weather.gov/gridpoints/OUN/97,94/forecast/hourly',
    ]);
  });
}
