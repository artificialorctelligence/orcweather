import 'librewxr.dart';
import 'nws.dart';

/// Road-hazard estimate from data already in hand. Not a DOT report — label it as such.
/// Returns null when nothing suggests a hazard.
String? roadRisk(Conditions? c, List<WeatherAlert> alerts) {
  final titles = alerts.map((a) => a.title.toLowerCase());
  for (final t in titles) {
    if (t.contains('ice') || t.contains('freezing')) return 'Ice risk (alert)';
    if (t.contains('blizzard') || t.contains('winter') || t.contains('snow')) return 'Snow risk (alert)';
    if (t.contains('flood')) return 'Flooding risk (alert)';
    if (t.contains('fog')) return 'Low visibility (alert)';
  }
  if (c == null) return null;
  final wet = (c.precipChance ?? 0) >= 30 || c.shortForecast.toLowerCase().contains('rain') || c.shortForecast.toLowerCase().contains('snow');
  if (wet && c.temperatureF <= 34) return 'Ice risk (≤34°F with precipitation)';
  if (wet) return 'Wet roads likely';
  return null;
}
