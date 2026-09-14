import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import 'config.dart';

/// One radar frame from weather-maps.json: unix seconds + tile path prefix.
class RadarFrame {
  const RadarFrame({required this.time, required this.path});
  final int time;
  final String path;

  /// flutter_map urlTemplate for this frame.
  String tileUrl(String host) =>
      '$host$path/256/{z}/{x}/{y}/$librewxrColorScheme/1_1.png';
}

class RadarFrames {
  const RadarFrames({required this.host, required this.past, required this.nowcast});
  final String host;
  final List<RadarFrame> past;
  final List<RadarFrame> nowcast;

  RadarFrame get latest => past.last;

  static RadarFrames parse(String body) {
    final json = jsonDecode(body) as Map<String, dynamic>;
    final radar = json['radar'] as Map<String, dynamic>;
    List<RadarFrame> frames(String key) => (radar[key] as List)
        .map((f) => RadarFrame(time: f['time'] as int, path: f['path'] as String))
        .toList();
    return RadarFrames(
      host: json['host'] as String,
      past: frames('past'),
      nowcast: frames('nowcast'),
    );
  }
}

/// A weather alert polygon as served by /v2/alerts (only the keys it really sends).
class WeatherAlert {
  const WeatherAlert({
    required this.title,
    required this.severity,
    required this.expires,
    required this.description,
    required this.polygons,
  });
  final String title;
  final String severity; // Minor | Moderate | Severe | Extreme
  final DateTime expires;
  final String description;
  final List<List<LatLng>> polygons; // outer rings only

  static List<WeatherAlert> parse(String body) {
    final json = jsonDecode(body) as Map<String, dynamic>;
    return (json['features'] as List).map((f) {
      final p = f['properties'] as Map<String, dynamic>;
      final g = f['geometry'] as Map<String, dynamic>;
      final coords = g['coordinates'] as List;
      final polys = g['type'] == 'MultiPolygon' ? coords : [coords];
      return WeatherAlert(
        title: p['title'] as String,
        severity: p['severity'] as String,
        expires: DateTime.fromMillisecondsSinceEpoch((p['expires'] as int) * 1000),
        description: p['description'] as String,
        polygons: [
          for (final poly in polys)
            [for (final c in poly[0] as List) LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble())],
        ],
      );
    }).toList();
  }
}

class LibreWxr {
  LibreWxr(this._client, {this.host = librewxrHost});
  final http.Client _client;
  final String host;

  Future<String> _get(String pathAndQuery) async {
    final r = await _client.get(Uri.parse('$host$pathAndQuery'), headers: {'User-Agent': appUserAgent});
    if (r.statusCode != 200) throw http.ClientException('LibreWXR $pathAndQuery -> ${r.statusCode}');
    return r.body;
  }

  Future<RadarFrames> frames() async => RadarFrames.parse(await _get('/public/weather-maps.json'));

  /// Alerts intersecting a bounding box around [center] of [radiusMeters].
  Future<List<WeatherAlert>> alertsAround(LatLng center, double radiusMeters) async {
    const d = Distance();
    final n = d.offset(center, radiusMeters, 0).latitude;
    final s = d.offset(center, radiusMeters, 180).latitude;
    final e = d.offset(center, radiusMeters, 90).longitude;
    final w = d.offset(center, radiusMeters, 270).longitude;
    return WeatherAlert.parse(await _get('/v2/alerts?bbox=$w,$s,$e,$n'));
  }
}
