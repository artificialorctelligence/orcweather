import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'config.dart';
import 'librewxr.dart';
import 'nws_colors.dart';

/// Pure decisions the map screen makes, kept out of the widget so they can be tested.

enum GestureOutcome { pinch, drag, none }

/// A pinch reaches flutter_map as up to three gestures (first-finger "drag", multi-finger,
/// last-finger "drag"), so judge by outcome: zoom changed → pinch; centre moved more than a
/// thumb-wobble with no zoom change → drag; otherwise nothing worth reacting to.
GestureOutcome classifyGesture({required double zoomStart, required double zoomEnd, required double movedPx}) {
  if ((zoomEnd - zoomStart).abs() > 0.05) return GestureOutcome.pinch;
  if (movedPx > 24) return GestureOutcome.drag;
  return GestureOutcome.none;
}

/// Road layers are statewide downloads (up to ~10 MB): fetch on state change or every [every].
bool roadsDue({
  required String? state,
  required String? lastState,
  required DateTime? lastAt,
  required DateTime now,
  Duration every = const Duration(minutes: 30),
}) {
  if (state == null) return false;
  if (state != lastState || lastAt == null) return true;
  return now.difference(lastAt) > every;
}

/// Most urgent alert by NWS display priority (ties keep the earlier one).
WeatherAlert? worstAlert(List<WeatherAlert> alerts) =>
    alerts.isEmpty ? null : alerts.reduce((a, b) => hazardPriority(a.event) <= hazardPriority(b.event) ? a : b);

/// Course over ground is trustworthy only while actually moving (~4.5 mph) with a valid heading.
bool movingFix({required double speedMps, required double heading}) => speedMps > 2 && heading >= 0;

IconData skyIcon(String forecast) {
  final f = forecast.toLowerCase();
  if (f.contains('thunder')) return Icons.thunderstorm;
  if (f.contains('snow') || f.contains('sleet') || f.contains('ice')) return Icons.ac_unit;
  if (f.contains('rain') || f.contains('shower') || f.contains('drizzle')) return Icons.water_drop;
  if (f.contains('fog') || f.contains('haze') || f.contains('smoke')) return Icons.foggy;
  if (f.contains('cloud') || f.contains('overcast')) return Icons.cloud;
  return Icons.wb_sunny;
}

/// First readable chunk of a CAP description: drop a leading product-code line, collapse whitespace.
String briefDescription(String d) {
  final lines = d.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
  if (lines.isNotEmpty && RegExp(r'^[A-Z]{3,6}$').hasMatch(lines.first)) lines.removeAt(0);
  return lines.join(' ').replaceAll(RegExp(r'\s+'), ' ');
}

/// "Zoom 9.0 · 156 mi across": ground width of the screen's short side at this latitude.
String zoomBadge({required double zoom, required double latitude, required double shortSidePx}) {
  final metersPerPixel = 156543.03 * math.cos(latitude * math.pi / 180) / math.pow(2, zoom);
  final miles = shortSidePx * metersPerPixel / metersPerMile;
  return 'Zoom ${zoom.toStringAsFixed(1)} · ${miles.round()} mi across';
}

/// Bounding box of the circle of [radiusMeters] around [center], so `fitCamera` shows the whole circle.
LatLngBounds fitBounds(LatLng center, double radiusMeters) {
  const d = Distance();
  return LatLngBounds(
    LatLng(d.offset(center, radiusMeters, 0).latitude, d.offset(center, radiusMeters, 270).longitude),
    LatLng(d.offset(center, radiusMeters, 180).latitude, d.offset(center, radiusMeters, 90).longitude),
  );
}

/// Ray-casting point-in-ring test (ring may or may not repeat its first point at the end).
bool pointInRing(LatLng p, List<LatLng> ring) {
  var inside = false;
  for (var i = 0, j = ring.length - 1; i < ring.length; j = i++) {
    final a = ring[i], b = ring[j];
    final crosses = (a.latitude > p.latitude) != (b.latitude > p.latitude) &&
        p.longitude < (b.longitude - a.longitude) * (p.latitude - a.latitude) / (b.latitude - a.latitude) + a.longitude;
    if (crosses) inside = !inside;
  }
  return inside;
}

/// Alerts whose polygons contain [p], most urgent first.
List<WeatherAlert> alertsAt(LatLng p, List<WeatherAlert> alerts) =>
    alerts.where((a) => a.polygons.any((ring) => pointInRing(p, ring))).toList()
      ..sort((a, b) => hazardPriority(a.event).compareTo(hazardPriority(b.event)));

/// Unicode stand-in for the phone strip's icon: car templates ignore icon spans in text.
String skyGlyph(String forecast) => switch (skyIcon(forecast)) {
      Icons.thunderstorm => '⛈',
      Icons.ac_unit => '❄',
      Icons.water_drop => '🌧',
      Icons.foggy => '🌫',
      Icons.cloud => '☁',
      _ => '☀',
    };

/// Glyph for an estimated road risk (see roadRisk()): ice, snow, flooding, fog, wet.
String roadRiskGlyph(String risk) {
  final r = risk.toLowerCase();
  if (r.startsWith('ice')) return '🧊';
  if (r.startsWith('snow')) return '❄';
  if (r.startsWith('flood')) return '🌊';
  if (r.startsWith('low visibility')) return '🌫';
  return '💧';
}

/// One line for the car card, the phone strip in glyphs: "71°F ⛈ · ENE 5 · ⚠ 2 · ❄ 1 · 🚧 3".
/// Reported snow/ice sections count as "❄ N"; an estimated risk shows its own glyph alone.
String stripLine({required String? temp, required String? sky, required String? wind, int alerts = 0, int badRoads = 0, String? roadRisk, int workZones = 0}) {
  if (temp == null) return 'Locating…';
  return [
    '$temp${sky == null ? '' : ' ${skyGlyph(sky)}'}',
    if (wind != null) wind.replaceAll(' mph', ''),
    if (alerts > 0) '⚠ $alerts',
    if (badRoads > 0) '❄ $badRoads' else if (roadRisk != null) roadRiskGlyph(roadRisk),
    if (workZones > 0) '🚧 $workZones',
  ].join(' · ');
}

/// Car zoom button: one press steps the view out, wrapping back to the closest.
const carViewMiles = [30.0, 60.0, 120.0];
double nextCarViewMiles(double current) {
  final i = carViewMiles.indexWhere((m) => (m - current).abs() < 0.5);
  return carViewMiles[(i + 1) % carViewMiles.length];
}

/// What the megaphone says. Units spelled out; "mph" reads badly aloud.
String spokenConditions({required String? temp, required String? sky, required String? wind, required List<WeatherAlert> alerts, String? roads}) {
  if (temp == null) return 'Still locating you.';
  final parts = <String>[
    temp.replaceAll('°F', ' degrees').replaceAll('°C', ' degrees celsius'),
    ?sky,
    if (wind != null) 'wind ${_spokenWind(wind)}',
  ];
  if (alerts.isNotEmpty) {
    final sorted = [...alerts]..sort((a, b) => hazardPriority(a.event).compareTo(hazardPriority(b.event)));
    final names = sorted.map((a) => a.event).toSet().join(', ');
    parts.add(alerts.length == 1 ? 'one alert: $names' : '${alerts.length} alerts: $names');
  }
  if (roads != null) parts.add(roads.replaceFirst('(estimate)', 'estimated'));
  return '${parts.join('. ')}.';
}

String _spokenWind(String wind) => wind
    .replaceAll(RegExp(r'\bN\b'), 'north').replaceAll(RegExp(r'\bS\b'), 'south')
    .replaceAll(RegExp(r'\bE\b'), 'east').replaceAll(RegExp(r'\bW\b'), 'west')
    .replaceAll(RegExp(r'\bNE\b'), 'northeast').replaceAll(RegExp(r'\bNW\b'), 'northwest')
    .replaceAll(RegExp(r'\bSE\b'), 'southeast').replaceAll(RegExp(r'\bSW\b'), 'southwest')
    .replaceAll(' mph', ' miles per hour');

/// What a tap on an alert says: event, expiry, then the NWS "WHAT" bullet (or the first sentence).
/// NWS text is bulleted "* WHAT...", "* WHERE...", "* WHEN...", "* IMPACTS..."; read the WHAT line as prose.
String spokenAlert(WeatherAlert a, {required String until}) {
  final brief = briefDescription(a.description);
  final what = RegExp(r'\*\s*WHAT\.{2,}\s*(.+?)(?=\s\*\s*[A-Z]{3,}\.{2,}|$)').firstMatch(brief)?.group(1);
  final body = (what ?? brief.split(RegExp(r'(?<=[.!?])\s')).first).replaceAll(RegExp(r'^\*\s*'), '');
  return '${a.event}, until $until. ${body.trim()}';
}
