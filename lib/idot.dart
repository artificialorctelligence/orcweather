import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import 'config.dart';

/// One IDOT winter-maintenance section with its reported surface condition.
class RoadCondition {
  const RoadCondition({required this.section, required this.county, required this.condition, required this.lines});
  final String section;
  final String county;
  final String condition; // Clear | Partly Covered with ice or snow | Mostly Covered … | Covered with ice or snow
  final List<List<LatLng>> lines;

  bool get isClear => condition == 'Clear';

  static List<RoadCondition> parse(String geojson) {
    final json = jsonDecode(geojson) as Map<String, dynamic>;
    return [
      for (final f in json['features'] as List)
        RoadCondition(
          section: (f['properties']['WrcMntSectionName'] as String?) ?? '',
          county: (f['properties']['COUNTY_NAM'] as String?) ?? '',
          condition: (f['properties']['Condition'] as String?) ?? 'Clear',
          lines: _lines(f['geometry'] as Map),
        ),
    ];
  }

  static List<List<LatLng>> _lines(Map g) {
    List<LatLng> ring(List cs) => [for (final c in cs) LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble())];
    return switch (g['type']) {
      'LineString' => [ring(g['coordinates'] as List)],
      'MultiLineString' => [for (final l in g['coordinates'] as List) ring(l as List)],
      _ => const [],
    };
  }
}

/// Illinois DOT "IL DOT Winter Road Conditions" — reported, statewide, free, no key.
/// Illinois only; other states need their own source (BACKLOG #6).
class Idot {
  Idot(this._client, {this.layerUrl = idotWinterRoadsUrl});
  final http.Client _client;
  final String layerUrl;

  /// Sections intersecting a circle of [meters] around [center], as GeoJSON in WGS84.
  Future<List<RoadCondition>> near(LatLng center, double meters) async {
    final uri = Uri.parse('$layerUrl/query').replace(queryParameters: {
      'where': '1=1',
      'geometry': '${center.longitude},${center.latitude}',
      'geometryType': 'esriGeometryPoint',
      'inSR': '4326',
      'distance': meters.round().toString(),
      'units': 'esriSRUnit_Meter',
      'outFields': 'WrcMntSectionName,COUNTY_NAM,Condition',
      'outSR': '4326',
      'f': 'geojson',
    });
    final r = await _client.get(uri, headers: {'User-Agent': appUserAgent});
    if (r.statusCode != 200) throw http.ClientException('IDOT -> ${r.statusCode}');
    return RoadCondition.parse(r.body);
  }
}
