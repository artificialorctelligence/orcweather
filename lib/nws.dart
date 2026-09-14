import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import 'config.dart';

/// Current-hour conditions from the NWS hourly forecast.
class Conditions {
  const Conditions({
    required this.temperatureF,
    required this.windSpeed,
    required this.windDirection,
    required this.shortForecast,
    required this.precipChance,
    required this.humidity,
  });
  final int temperatureF;
  final String windSpeed; // NWS sends a string, e.g. "17 mph"
  final String windDirection;
  final String shortForecast;
  final int? precipChance;
  final int? humidity;

  static Conditions parse(String hourlyBody) {
    final p = ((jsonDecode(hourlyBody) as Map)['properties']['periods'] as List).first as Map;
    return Conditions(
      temperatureF: p['temperature'] as int,
      windSpeed: p['windSpeed'] as String,
      windDirection: p['windDirection'] as String,
      shortForecast: p['shortForecast'] as String,
      precipChance: (p['probabilityOfPrecipitation'] as Map?)?['value'] as int?,
      humidity: (p['relativeHumidity'] as Map?)?['value'] as int?,
    );
  }
}

class Nws {
  Nws(this._client, {this.host = nwsHost});
  final http.Client _client;
  final String host;

  Future<String> _get(Uri uri) async {
    final r = await _client.get(uri, headers: {'User-Agent': appUserAgent, 'Accept': 'application/geo+json'});
    if (r.statusCode != 200) throw http.ClientException('NWS $uri -> ${r.statusCode}');
    return r.body;
  }

  /// Two calls: /points resolves the grid, then its forecastHourly URL.
  Future<Conditions> conditions(LatLng at) async {
    final lat = at.latitude.toStringAsFixed(4);
    final lon = at.longitude.toStringAsFixed(4);
    final points = jsonDecode(await _get(Uri.parse('$host/points/$lat,$lon'))) as Map;
    final hourlyUrl = points['properties']['forecastHourly'] as String;
    return Conditions.parse(await _get(Uri.parse(hourlyUrl)));
  }
}
