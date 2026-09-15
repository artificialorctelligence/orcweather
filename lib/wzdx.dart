import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import 'config.dart';

/// One WZDx road event (work zone) reduced to what the map needs.
class WorkZone {
  const WorkZone({required this.road, required this.description, required this.points});
  final String road;
  final String description;
  final List<LatLng> points; // LineString vertices, or MultiPoint start/end

  static List<WorkZone> parse(String body) {
    final json = jsonDecode(body) as Map<String, dynamic>;
    return [
      for (final f in json['features'] as List)
        if (f['geometry'] != null && _coords(f['geometry'] as Map).isNotEmpty)
          WorkZone(
            road: ((f['properties']?['core_details']?['road_names'] as List?) ?? const []).join(' / '),
            description: (f['properties']?['core_details']?['description'] as String?) ?? '',
            points: _coords(f['geometry'] as Map),
          ),
    ];
  }

  static List<LatLng> _coords(Map geometry) => switch (geometry['type']) {
        'LineString' || 'MultiPoint' => [
            for (final c in geometry['coordinates'] as List) LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()),
          ],
        _ => const [],
      };

  bool within(LatLng center, double meters) {
    const d = Distance();
    return points.any((p) => d(center, p) <= meters);
  }
}

/// USDOT's WZDx feed registry, filtered to the feeds an app can pull without a key.
class Wzdx {
  Wzdx(this._client, {this.registryUrl = wzdxRegistryUrl});
  final http.Client _client;
  final String registryUrl;

  Future<String> _get(String url) async {
    final r = await _client.get(Uri.parse(url), headers: {'User-Agent': appUserAgent});
    if (r.statusCode != 200) throw http.ClientException('WZDx $url -> ${r.statusCode}');
    return r.body;
  }

  /// Feed URLs for a two-letter state, from the live registry.
  Future<List<String>> feedUrlsFor(String stateAbbr) async {
    final name = _stateNames[stateAbbr.toUpperCase()];
    if (name == null) return const [];
    return feedUrlsIn(await _get(registryUrl), name);
  }

  static List<String> feedUrlsIn(String registryBody, String stateName) {
    final needle = stateName.toLowerCase();
    return [
      for (final r in jsonDecode(registryBody) as List)
        if (r['active'] == true &&
            r['needapikey'] != true &&
            (r['state'] as String? ?? '').toLowerCase().contains(needle) &&
            r['url']?['url'] is String)
          r['url']['url'] as String,
    ];
  }

  /// Work zones within [meters] of [center], from every keyless feed for [stateAbbr].
  /// ponytail: statewide feeds run to ~10 MB (WI, NC); call this on state change /
  /// every 30 min, not on the 5-min weather tick. Bbox-filtered feeds if that hurts.
  Future<List<WorkZone>> near(LatLng center, double meters, String stateAbbr) async {
    final urls = await feedUrlsFor(stateAbbr);
    final zones = <WorkZone>[];
    for (final url in urls) {
      try {
        zones.addAll(WorkZone.parse(await _get(url)).where((z) => z.within(center, meters)));
      } on Exception {
        // One dead feed must not blank the others; registry entries rot (5 of 43 on 2026-09-14).
      }
    }
    return zones;
  }
}

const _stateNames = {
  'AL': 'alabama', 'AK': 'alaska', 'AZ': 'arizona', 'AR': 'arkansas', 'CA': 'california',
  'CO': 'colorado', 'CT': 'connecticut', 'DE': 'delaware', 'DC': 'district of columbia',
  'FL': 'florida', 'GA': 'georgia', 'HI': 'hawaii', 'ID': 'idaho', 'IL': 'illinois',
  'IN': 'indiana', 'IA': 'iowa', 'KS': 'kansas', 'KY': 'kentucky', 'LA': 'louisiana',
  'ME': 'maine', 'MD': 'maryland', 'MA': 'massachusetts', 'MI': 'michigan', 'MN': 'minnesota',
  'MS': 'mississippi', 'MO': 'missouri', 'MT': 'montana', 'NE': 'nebraska', 'NV': 'nevada',
  'NH': 'new hampshire', 'NJ': 'new jersey', 'NM': 'new mexico', 'NY': 'new york',
  'NC': 'north carolina', 'ND': 'north dakota', 'OH': 'ohio', 'OK': 'oklahoma', 'OR': 'oregon',
  'PA': 'pennsylvania', 'RI': 'rhode island', 'SC': 'south carolina', 'SD': 'south dakota',
  'TN': 'tennessee', 'TX': 'texas', 'UT': 'utah', 'VT': 'vermont', 'VA': 'virginia',
  'WA': 'washington', 'WV': 'west virginia', 'WI': 'wisconsin', 'WY': 'wyoming',
};
