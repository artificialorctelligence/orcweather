import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:orcweather/librewxr.dart';
import 'package:orcweather/map_logic.dart';

WeatherAlert alert(String title, {String severity = 'Moderate'}) =>
    WeatherAlert(title: title, severity: severity, expires: DateTime(2030), description: '', polygons: const []);

void main() {
  group('classifyGesture', () {
    test('zoom change is a pinch, however far the centre drifted', () {
      expect(classifyGesture(zoomStart: 9.50, zoomEnd: 7.81, movedPx: 8.5), GestureOutcome.pinch);
      expect(classifyGesture(zoomStart: 9.50, zoomEnd: 9.56, movedPx: 300), GestureOutcome.pinch);
    });
    test('centre moved with no zoom change is a drag', () {
      expect(classifyGesture(zoomStart: 9.50, zoomEnd: 9.50, movedPx: 25), GestureOutcome.drag);
      expect(classifyGesture(zoomStart: 9.50, zoomEnd: 9.52, movedPx: 400), GestureOutcome.drag);
    });
    test('a thumb-wobble (first finger of a pinch) is neither', () {
      expect(classifyGesture(zoomStart: 9.50, zoomEnd: 9.50, movedPx: 3.5), GestureOutcome.none);
      expect(classifyGesture(zoomStart: 9.50, zoomEnd: 9.50, movedPx: 24), GestureOutcome.none);
    });
  });

  group('roadsDue', () {
    final t0 = DateTime(2026, 9, 15, 20, 0);
    test('never fetched → due; unknown state → not due', () {
      expect(roadsDue(state: 'IL', lastState: null, lastAt: null, now: t0), isTrue);
      expect(roadsDue(state: null, lastState: null, lastAt: null, now: t0), isFalse);
    });
    test('same state, fresh → not due; 31 min later → due', () {
      expect(roadsDue(state: 'IL', lastState: 'IL', lastAt: t0, now: t0.add(const Duration(minutes: 29))), isFalse);
      expect(roadsDue(state: 'IL', lastState: 'IL', lastAt: t0, now: t0.add(const Duration(minutes: 31))), isTrue);
    });
    test('crossing into another state → due immediately', () {
      expect(roadsDue(state: 'IA', lastState: 'IL', lastAt: t0, now: t0.add(const Duration(minutes: 1))), isTrue);
    });
  });

  group('worstAlert', () {
    test('empty → null', () => expect(worstAlert(const []), isNull));
    test('NWS priority wins over list order and CAP severity', () {
      final w = worstAlert([
        alert('Flood Watch issued today by NWS Lincoln IL', severity: 'Severe'),
        alert('Tornado Warning issued today by NWS Lincoln IL', severity: 'Moderate'),
        alert('Heat Advisory issued today by NWS Lincoln IL'),
      ]);
      expect(w!.event, 'Tornado Warning');
    });
    test('unknown events rank below every NWS event', () {
      final w = worstAlert([alert('yellow advisory - frost - in effect'), alert('Frost Advisory issued today by NWS X')]);
      expect(w!.event, 'Frost Advisory');
    });
  });

  group('skyIcon', () {
    test('maps forecast text to an icon, thunder before rain', () {
      expect(skyIcon('Chance Showers And Thunderstorms'), Icons.thunderstorm);
      expect(skyIcon('Light Rain'), Icons.water_drop);
      expect(skyIcon('Snow Showers'), Icons.ac_unit);
      expect(skyIcon('Patchy Fog'), Icons.foggy);
      expect(skyIcon('Mostly Cloudy'), Icons.cloud);
      expect(skyIcon('Sunny'), Icons.wb_sunny);
      expect(skyIcon('Mostly Clear'), Icons.wb_sunny);
    });
  });

  group('briefDescription', () {
    test('drops the product code line and collapses whitespace', () {
      expect(briefDescription('SVRILX\n\n* At 615 PM CDT, a severe thunderstorm\n  was located near Elmwood.\n\nHAZARD...60 mph.'),
          '* At 615 PM CDT, a severe thunderstorm was located near Elmwood. HAZARD...60 mph.');
    });
    test('keeps a first line that is not a product code', () {
      expect(briefDescription('Conditions are favourable for frost.\nLocations: Carleton County.'),
          'Conditions are favourable for frost. Locations: Carleton County.');
    });
    test('empty in, empty out', () => expect(briefDescription('\n  \n'), ''));
  });

  group('zoomBadge', () {
    test('miles across the short side at Peoria, zoom 9, 1080 px', () {
      // 156543.03 * cos(40.69°) / 2^9 = 232.0 m/px; × 1080 px = 250.6 km = 155.7 mi
      expect(zoomBadge(zoom: 9, latitude: 40.69, shortSidePx: 1080), 'Zoom 9.0 · 156 mi across');
    });
    test('each zoom step halves the distance', () {
      expect(zoomBadge(zoom: 10, latitude: 40.69, shortSidePx: 1080), 'Zoom 10.0 · 78 mi across');
    });
  });

  group('movingFix', () {
    test('GPS course counts only above walking pace with a valid heading', () {
      expect(movingFix(speedMps: 15, heading: 270), isTrue);
      expect(movingFix(speedMps: 1.5, heading: 270), isFalse);
      expect(movingFix(speedMps: 15, heading: -1), isFalse);
    });
  });

  group('fitBounds', () {
    test('30-mile view is a square ~60 mi across centred on the point', () {
      final b = fitBounds(const LatLng(40.69, -89.59), 30 * 1609.344);
      const d = Distance();
      expect(d(b.northWest, b.southEast) / 1609.344, closeTo(84.9, 0.5)); // diagonal of a 60-mi square
      expect(b.center.latitude, closeTo(40.69, 0.01));
    });
  });
}
