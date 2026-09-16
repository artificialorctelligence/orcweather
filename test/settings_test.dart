import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orcweather/settings.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  setUp(() => SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty());

  test('defaults: °F and auto', () async {
    final s = Settings(SharedPreferencesAsync());
    await s.load();
    expect(s.tempUnit, TempUnit.f);
    expect(s.mapTheme, MapTheme.auto);
  });

  test('formats and converts temperature', () {
    final s = Settings(SharedPreferencesAsync());
    expect(s.formatTemp(74), '74°F');
    s.tempUnit = TempUnit.c;
    expect(s.formatTemp(74), '23°C');
    expect(s.formatTemp(32), '0°C');
    expect(s.formatTemp(-40), '-40°C');
  });

  test('changes persist across instances', () async {
    final a = Settings(SharedPreferencesAsync());
    await a.setTempUnit(TempUnit.c);
    await a.setMapTheme(MapTheme.dark);
    final b = Settings(SharedPreferencesAsync());
    await b.load();
    expect(b.tempUnit, TempUnit.c);
    expect(b.mapTheme, MapTheme.dark);
  });

  test('dark map decision', () {
    final s = Settings(SharedPreferencesAsync());
    expect(s.darkMap(Brightness.light), isFalse); // auto + light phone
    expect(s.darkMap(Brightness.dark), isTrue); // auto + dark phone
    s.mapTheme = MapTheme.light;
    expect(s.darkMap(Brightness.dark), isFalse);
    s.mapTheme = MapTheme.dark;
    expect(s.darkMap(Brightness.light), isTrue);
  });
}
