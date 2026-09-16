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
