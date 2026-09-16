import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum TempUnit { f, c }

enum MapTheme { auto, light, dark }

/// User settings, persisted with shared_preferences. Defaults: °F, map theme auto.
class Settings extends ChangeNotifier {
  Settings(this._prefs);
  final SharedPreferencesAsync _prefs;

  TempUnit tempUnit = TempUnit.f;
  MapTheme mapTheme = MapTheme.auto;
  bool centerOnZoom = false; // after a pinch or zoom button, recenter on the position and follow again

  Future<void> load() async {
    tempUnit = TempUnit.values.byName(await _prefs.getString('tempUnit') ?? 'f');
    mapTheme = MapTheme.values.byName(await _prefs.getString('mapTheme') ?? 'auto');
    centerOnZoom = await _prefs.getBool('centerOnZoom') ?? false;
    notifyListeners();
  }

  Future<void> setTempUnit(TempUnit u) async {
    tempUnit = u;
    notifyListeners();
    await _prefs.setString('tempUnit', u.name);
  }

  Future<void> setMapTheme(MapTheme t) async {
    mapTheme = t;
    notifyListeners();
    await _prefs.setString('mapTheme', t.name);
  }

  Future<void> setCenterOnZoom(bool v) async {
    centerOnZoom = v;
    notifyListeners();
    await _prefs.setBool('centerOnZoom', v);
  }

  /// "74°F" or "23°C" from a Fahrenheit reading.
  String formatTemp(int fahrenheit) =>
      tempUnit == TempUnit.f ? '$fahrenheit°F' : '${((fahrenheit - 32) * 5 / 9).round()}°C';

  /// Whether the map should be dark, given the platform brightness for auto.
  bool darkMap(Brightness platform) => switch (mapTheme) {
        MapTheme.dark => true,
        MapTheme.light => false,
        MapTheme.auto => platform == Brightness.dark,
      };
}
