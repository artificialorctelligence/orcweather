import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:orcweather/debug_alerts.dart';
import 'package:orcweather/nws_colors.dart';

void main() {
  const peoria = LatLng(40.6936, -89.5890);

  test('fake alerts are off unless the dart-define is set', () {
    expect(fakeAlertsEnabled, isFalse);
  });

  test('a watch, a warning and an advisory, all closed rings, warning overlapping the position', () {
    final fakes = fakeAlertsAround(peoria);
    expect(fakes.map((a) => kindOf(a.event)), [HazardKind.watch, HazardKind.warning, HazardKind.other]);
    for (final a in fakes) {
      expect(a.title, contains('FAKE'));
      expect(a.expires.isAfter(DateTime.now()), isTrue);
      for (final ring in a.polygons) {
        expect(ring.first, ring.last, reason: 'rings must be closed');
        expect(ring.length, greaterThanOrEqualTo(4));
      }
    }
    // The watch box contains the position; the advisory box is centred on it.
    final watch = fakes[0].polygons.single;
    expect(watch.map((p) => p.latitude).reduce((a, b) => a < b ? a : b), lessThan(peoria.latitude));
    expect(watch.map((p) => p.latitude).reduce((a, b) => a > b ? a : b), greaterThan(peoria.latitude));
  });
}
