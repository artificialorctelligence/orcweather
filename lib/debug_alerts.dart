import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import 'librewxr.dart';

/// Synthetic alerts for testing the map when the sky is quiet.
/// Debug builds only, and only with `--dart-define=FAKE_ALERTS=true`.
const fakeAlertsEnabled = kDebugMode && bool.fromEnvironment('FAKE_ALERTS');

List<WeatherAlert> fakeAlertsAround(LatLng p) {
  final expires = DateTime.now().add(const Duration(hours: 3));
  List<LatLng> box(double dLat, double dLon) => [
        LatLng(p.latitude - dLat, p.longitude - dLon),
        LatLng(p.latitude - dLat, p.longitude + dLon),
        LatLng(p.latitude + dLat, p.longitude + dLon),
        LatLng(p.latitude + dLat, p.longitude - dLon),
        LatLng(p.latitude - dLat, p.longitude - dLon),
      ];
  return [
    WeatherAlert(
      title: 'Severe Thunderstorm Watch issued (FAKE) until later today by NWS Lincoln IL',
      severity: 'Severe',
      expires: expires,
      description: 'FAKE for testing.\n\nSEVERE THUNDERSTORM WATCH 999 IN EFFECT UNTIL 9 PM CDT FOR THE FOLLOWING COUNTIES: PEORIA, TAZEWELL, WOODFORD, FULTON, KNOX.',
      polygons: [box(0.55, 0.75)], // ~75 x 80 mi box
    ),
    WeatherAlert(
      title: 'Severe Thunderstorm Warning issued (FAKE) until soon by NWS Lincoln IL',
      severity: 'Severe',
      expires: DateTime.now().add(const Duration(minutes: 45)),
      description: 'SVRILX\n\nFAKE for testing.\n\n* At 615 PM CDT, a severe thunderstorm was located near Elmwood, moving east at 40 mph.\n\nHAZARD...60 mph wind gusts and quarter size hail.',
      polygons: [
        [
          LatLng(p.latitude + 0.05, p.longitude - 0.45),
          LatLng(p.latitude + 0.25, p.longitude - 0.15),
          LatLng(p.latitude + 0.05, p.longitude + 0.05),
          LatLng(p.latitude - 0.15, p.longitude - 0.25),
          LatLng(p.latitude + 0.05, p.longitude - 0.45),
        ],
      ],
    ),
    WeatherAlert(
      title: 'Flood Advisory issued (FAKE) by NWS Lincoln IL',
      severity: 'Minor',
      expires: expires,
      description: 'FAKE for testing. Minor flooding of low-lying areas along the Illinois River.',
      polygons: [box(0.12, 0.08)],
    ),
  ];
}
