import 'package:flutter/material.dart';

/// NWS hazard colors and display priority, from https://www.weather.gov/help-map (read 2026-09-15).
/// Priority 1 is the most urgent (Tsunami Warning); Tornado Warning is 2, Severe Thunderstorm Warning 4.
class NwsHazard {
  const NwsHazard(this.priority, this.color);
  final int priority;
  final Color color;
}

const nwsHazards = <String, NwsHazard>{
  'Tsunami Warning': NwsHazard(1, Color(0xFFFD6347)),
  'Tornado Warning': NwsHazard(2, Color(0xFFFF0000)),
  'Extreme Wind Warning': NwsHazard(3, Color(0xFFFF8C00)),
  'Severe Thunderstorm Warning': NwsHazard(4, Color(0xFFFFA500)),
  'Flash Flood Warning': NwsHazard(5, Color(0xFF8B0000)),
  'Flash Flood Statement': NwsHazard(6, Color(0xFF8B0000)),
  'Severe Weather Statement': NwsHazard(7, Color(0xFF00FFFF)),
  'Shelter In Place Warning': NwsHazard(8, Color(0xFFFA8072)),
  'Evacuation Immediate': NwsHazard(9, Color(0xFF7FFF00)),
  'Civil Danger Warning': NwsHazard(10, Color(0xFFFFB6C1)),
  'Nuclear Power Plant Warning': NwsHazard(11, Color(0xFF4B0082)),
  'Radiological Hazard Warning': NwsHazard(12, Color(0xFF4B0082)),
  'Hazardous Materials Warning': NwsHazard(13, Color(0xFF4B0082)),
  'Fire Warning': NwsHazard(14, Color(0xFFA0522D)),
  'Civil Emergency Message': NwsHazard(15, Color(0xFFFFB6C1)),
  'Law Enforcement Warning': NwsHazard(16, Color(0xFFC0C0C0)),
  'Storm Surge Warning': NwsHazard(17, Color(0xFFB524F7)),
  'Hurricane Force Wind Warning': NwsHazard(18, Color(0xFFCD5C5C)),
  'Hurricane Warning': NwsHazard(19, Color(0xFFDC143C)),
  'Typhoon Warning': NwsHazard(20, Color(0xFFDC143C)),
  'Special Marine Warning': NwsHazard(21, Color(0xFFFFA500)),
  'Blizzard Warning': NwsHazard(22, Color(0xFFFF4500)),
  'Snow Squall Warning': NwsHazard(23, Color(0xFFC71585)),
  'Ice Storm Warning': NwsHazard(24, Color(0xFF8B008B)),
  'Heavy Freezing Spray Warning': NwsHazard(25, Color(0xFF00BFFF)),
  'Winter Storm Warning': NwsHazard(26, Color(0xFFFF69B4)),
  'Lake Effect Snow Warning': NwsHazard(27, Color(0xFF008B8B)),
  'Dust Storm Warning': NwsHazard(28, Color(0xFFFFE4C4)),
  'Blowing Dust Warning': NwsHazard(29, Color(0xFFFFE4C4)),
  'High Wind Warning': NwsHazard(30, Color(0xFFDAA520)),
  'Tropical Storm Warning': NwsHazard(31, Color(0xFFB22222)),
  'Storm Warning': NwsHazard(32, Color(0xFF9400D3)),
  'Tsunami Advisory': NwsHazard(33, Color(0xFFD2691E)),
  'Tsunami Watch': NwsHazard(34, Color(0xFFFF00FF)),
  'Avalanche Warning': NwsHazard(35, Color(0xFF1E90FF)),
  'Earthquake Warning': NwsHazard(36, Color(0xFF8B4513)),
  'Volcano Warning': NwsHazard(37, Color(0xFF2F4F4F)),
  'Ashfall Warning': NwsHazard(38, Color(0xFFA9A9A9)),
  'Flood Warning': NwsHazard(39, Color(0xFF00FF00)),
  'Coastal Flood Warning': NwsHazard(40, Color(0xFF228B22)),
  'Lakeshore Flood Warning': NwsHazard(41, Color(0xFF228B22)),
  'Ashfall Advisory': NwsHazard(42, Color(0xFF696969)),
  'High Surf Warning': NwsHazard(43, Color(0xFF228B22)),
  'Extreme Heat Warning': NwsHazard(44, Color(0xFFC71585)),
  'Tornado Watch': NwsHazard(45, Color(0xFFFFFF00)),
  'Severe Thunderstorm Watch': NwsHazard(46, Color(0xFFDB7093)),
  'Flash Flood Watch': NwsHazard(47, Color(0xFF2E8B57)),
  'Gale Warning': NwsHazard(48, Color(0xFFDDA0DD)),
  'Flood Statement': NwsHazard(49, Color(0xFF00FF00)),
  'Extreme Cold Warning': NwsHazard(50, Color(0xFF0000FF)),
  'Freeze Warning': NwsHazard(51, Color(0xFF483D8B)),
  'Red Flag Warning': NwsHazard(52, Color(0xFFFF1493)),
  'Storm Surge Watch': NwsHazard(53, Color(0xFFDB7FF7)),
  'Hurricane Watch': NwsHazard(54, Color(0xFFFF00FF)),
  'Hurricane Force Wind Watch': NwsHazard(55, Color(0xFF9932CC)),
  'Typhoon Watch': NwsHazard(56, Color(0xFFFF00FF)),
  'Tropical Storm Watch': NwsHazard(57, Color(0xFFF08080)),
  'Storm Watch': NwsHazard(58, Color(0xFFFFE4B5)),
  'Tropical Cyclone Local Statement': NwsHazard(59, Color(0xFFFFE4B5)),
  'Winter Weather Advisory': NwsHazard(60, Color(0xFF7B68EE)),
  'Avalanche Advisory': NwsHazard(61, Color(0xFFCD853F)),
  'Cold Weather Advisory': NwsHazard(62, Color(0xFFAFEEEE)),
  'Heat Advisory': NwsHazard(63, Color(0xFFFF7F50)),
  'Flood Advisory': NwsHazard(64, Color(0xFF00FF7F)),
  'Coastal Flood Advisory': NwsHazard(65, Color(0xFF7CFC00)),
  'Lakeshore Flood Advisory': NwsHazard(66, Color(0xFF7CFC00)),
  'High Surf Advisory': NwsHazard(67, Color(0xFFBA55D3)),
  'Dense Fog Advisory': NwsHazard(68, Color(0xFF708090)),
  'Dense Smoke Advisory': NwsHazard(69, Color(0xFFF0E68C)),
  'Small Craft Advisory': NwsHazard(70, Color(0xFFD8BFD8)),
  'Brisk Wind Advisory': NwsHazard(71, Color(0xFFD8BFD8)),
  'Hazardous Seas Warning': NwsHazard(72, Color(0xFFD8BFD8)),
  'Dust Advisory': NwsHazard(73, Color(0xFFBDB76B)),
  'Blowing Dust Advisory': NwsHazard(74, Color(0xFFBDB76B)),
  'Lake Wind Advisory': NwsHazard(75, Color(0xFFD2B48C)),
  'Wind Advisory': NwsHazard(76, Color(0xFFD2B48C)),
  'Frost Advisory': NwsHazard(77, Color(0xFF6495ED)),
  'Freezing Fog Advisory': NwsHazard(78, Color(0xFF008080)),
  'Freezing Spray Advisory': NwsHazard(79, Color(0xFF00BFFF)),
  'Low Water Advisory': NwsHazard(80, Color(0xFFA52A2A)),
  'Local Area Emergency': NwsHazard(81, Color(0xFFC0C0C0)),
  'Winter Storm Watch': NwsHazard(82, Color(0xFF4682B4)),
  'Rip Current Statement': NwsHazard(83, Color(0xFF40E0D0)),
  'Beach Hazards Statement': NwsHazard(84, Color(0xFF40E0D0)),
  'Gale Watch': NwsHazard(85, Color(0xFFFFC0CB)),
  'Avalanche Watch': NwsHazard(86, Color(0xFFF4A460)),
  'Hazardous Seas Watch': NwsHazard(87, Color(0xFF483D8B)),
  'Heavy Freezing Spray Watch': NwsHazard(88, Color(0xFFBC8F8F)),
  'Flood Watch': NwsHazard(89, Color(0xFF2E8B57)),
  'Coastal Flood Watch': NwsHazard(90, Color(0xFF66CDAA)),
  'Lakeshore Flood Watch': NwsHazard(91, Color(0xFF66CDAA)),
  'High Wind Watch': NwsHazard(92, Color(0xFFB8860B)),
  'Extreme Heat Watch': NwsHazard(93, Color(0xFF800000)),
  'Extreme Cold Watch': NwsHazard(94, Color(0xFF5F9EA0)),
  'Freeze Watch': NwsHazard(95, Color(0xFF00FFFF)),
  'Fire Weather Watch': NwsHazard(96, Color(0xFFFFDEAD)),
  'Extreme Fire Danger': NwsHazard(97, Color(0xFFE9967A)),
  '911 Telephone Outage': NwsHazard(98, Color(0xFFC0C0C0)),
  'Coastal Flood Statement': NwsHazard(99, Color(0xFF6B8E23)),
  'Lakeshore Flood Statement': NwsHazard(100, Color(0xFF6B8E23)),
  'Special Weather Statement': NwsHazard(101, Color(0xFFFFE4B5)),
  'Marine Weather Statement': NwsHazard(102, Color(0xFFFFDAB9)),
  'Air Quality Alert': NwsHazard(103, Color(0xFF808080)),
  'Air Stagnation Advisory': NwsHazard(104, Color(0xFF808080)),
  'Hazardous Weather Outlook': NwsHazard(105, Color(0xFFEEE8AA)),
  'Hydrologic Outlook': NwsHazard(106, Color(0xFF90EE90)),
  'Short Term Forecast': NwsHazard(107, Color(0xFF98FB98)),
  'Administrative Message': NwsHazard(108, Color(0xFFC0C0C0)),
  'Test': NwsHazard(109, Color(0xFFF0FFFF)),
  'Child Abduction Emergency': NwsHazard(110, Color(0xFFFFFFFF)),
  'Blue Alert': NwsHazard(111, Color(0xFFFFFFFF)),
};

/// Event name for a LibreWXR alert title: NWS titles read `Event issued date ... by NWS office`;
/// WMO titles are used as-is.
String eventOf(String title) {
  final i = title.indexOf(' issued ');
  return (i > 0 ? title.substring(0, i) : title).trim();
}

enum HazardKind { warning, watch, other }

HazardKind kindOf(String event) {
  if (event.endsWith('Warning')) return HazardKind.warning;
  if (event.endsWith('Watch')) return HazardKind.watch;
  return HazardKind.other;
}

/// Colors for anything not in the NWS table (WMO alerts), by CAP severity.
Color severityFallback(String severity) => switch (severity) {
      'Extreme' => const Color(0xFF9400D3),
      'Severe' => const Color(0xFFFF0000),
      'Moderate' => const Color(0xFFFFA500),
      _ => const Color(0xFFFFFF00),
    };

Color hazardColor(String event, String severity) => nwsHazards[event]?.color ?? severityFallback(severity);
int hazardPriority(String event) => nwsHazards[event]?.priority ?? 200;
