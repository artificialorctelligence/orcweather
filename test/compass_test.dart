import 'package:flutter_test/flutter_test.dart';
import 'package:orcweather/compass.dart';

// Device axes: x right, y top edge, z out of the screen. Gravity reads +9.8 on the axis pointing up.
// Earth field (northern hemisphere): points north and down; use north=20, down=40 (µT-ish).
List<double> field({required double north, required double east, required double down}) => [north, east, down];

void main() {
  const g = 9.8;

  group('upright phone (back facing forward)', () {
    test('screen facing south → back faces north → 0°', () {
      // Upright: y up (gravity +y). Back (-z) toward north means +z points south.
      // Field north component lands on device -z; down component on device -y.
      final h = Compass.headingFrom([0, g, 0], [0, -40, -20]);
      expect(h, closeTo(0, 1));
    });
    test('back faces east → 90°', () {
      // +z points west. North is then along device +x? Facing east: right hand (+x) points south.
      // north field → -x; down → -y.
      final h = Compass.headingFrom([0, g, 0], [-20, -40, 0]);
      expect(h, closeTo(90, 1));
    });
    test('back faces west → 270°', () {
      final h = Compass.headingFrom([0, g, 0], [20, -40, 0]);
      expect(h, closeTo(270, 1));
    });
    test('landscape upright still uses the back of the phone', () {
      // Rotated so +x is up (gravity +x). Back (-z) faces north: north field → -z, down → -x.
      final h = Compass.headingFrom([g, 0, 0], [-40, 0, -20]);
      expect(h, closeTo(0, 1));
    });
  });

  group('flat phone (top edge forward)', () {
    test('top edge north → 0°', () {
      // Flat, screen up: gravity +z. north field → +y, down → -z.
      final h = Compass.headingFrom([0, 0, g], [0, 20, -40]);
      expect(h, closeTo(0, 1));
    });
    test('top edge east → 90°', () {
      // Facing east: north is to the left (-x).
      final h = Compass.headingFrom([0, 0, g], [-20, 0, -40]);
      expect(h, closeTo(90, 1));
    });
  });

  test('degenerate input → null', () {
    expect(Compass.headingFrom([0, 0, 0], [1, 0, 0]), isNull);
    expect(Compass.headingFrom([0, 0, g], [0, 0, 5]), isNull); // field parallel to gravity
  });
}
