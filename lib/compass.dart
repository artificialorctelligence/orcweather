import 'dart:async';
import 'dart:math' as math;

import 'package:sensors_plus/sensors_plus.dart';

/// Magnetic heading (degrees, 0 = north, clockwise) of the direction the phone is "facing":
/// the back of the phone when held upright (any rotation), the top edge when lying flat.
/// Same construction as Android's SensorManager.getRotationMatrix + getOrientation.
class Compass {
  Compass({Stream<AccelerometerEvent>? accel, Stream<MagnetometerEvent>? mag})
      : _accel = accel ?? accelerometerEventStream(samplingPeriod: const Duration(milliseconds: 100)),
        _mag = mag ?? magnetometerEventStream(samplingPeriod: const Duration(milliseconds: 100));

  final Stream<AccelerometerEvent> _accel;
  final Stream<MagnetometerEvent> _mag;
  List<double>? _a, _m;
  static const _alpha = 0.2; // low-pass; sensors are noisy

  Stream<double> get headings {
    late StreamController<double> out;
    StreamSubscription? sa, sm;
    out = StreamController<double>(
      onListen: () {
        sa = _accel.listen((e) {
          _a = _smooth(_a, [e.x, e.y, e.z]);
          _emit(out);
        });
        sm = _mag.listen((e) {
          _m = _smooth(_m, [e.x, e.y, e.z]);
          _emit(out);
        });
      },
      onCancel: () async {
        await sa?.cancel();
        await sm?.cancel();
      },
    );
    return out.stream;
  }

  void _emit(StreamController<double> out) {
    final a = _a, m = _m;
    if (a == null || m == null) return;
    final h = headingFrom(a, m);
    if (h != null) out.add(h);
  }

  static List<double> _smooth(List<double>? prev, List<double> next) =>
      prev == null ? next : [for (var i = 0; i < 3; i++) prev[i] + _alpha * (next[i] - prev[i])];

  /// Pure function so it can be tested. Device axes: x right, y top edge, z out of the screen.
  static double? headingFrom(List<double> accel, List<double> mag) {
    final a = _norm(accel);
    if (a == null) return null;
    final h = _norm(_cross(mag, a)); // east
    if (h == null) return null; // magnetometer parallel to gravity: no heading
    final n = _cross(a, h); // north
    // forward: back of the phone (-z) when upright, top edge (+y) when flat.
    // ponytail: a phone lying flat in landscape reports its top edge, not the road; dash mounts are upright.
    final upright = a[2].abs() < 0.7;
    final f = upright ? [0.0, 0.0, -1.0] : [0.0, 1.0, 0.0];
    final east = _dot(h, f), north = _dot(n, f);
    final deg = math.atan2(east, north) * 180 / math.pi;
    return (deg + 360) % 360;
  }

  static List<double> _cross(List<double> u, List<double> v) =>
      [u[1] * v[2] - u[2] * v[1], u[2] * v[0] - u[0] * v[2], u[0] * v[1] - u[1] * v[0]];
  static double _dot(List<double> u, List<double> v) => u[0] * v[0] + u[1] * v[1] + u[2] * v[2];
  static List<double>? _norm(List<double> v) {
    final len = math.sqrt(_dot(v, v));
    return len < 1e-6 ? null : [v[0] / len, v[1] / len, v[2] / len];
  }
}
