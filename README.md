# orcweather

Weather around your position on the road: OpenStreetMap base, LibreWXR radar + alert polygons,
NWS current conditions, a 50-mile circle, zoom buttons. Flutter; Android first, iOS and desktop
from the same code.

```bash
flutter pub get
flutter analyze && flutter test
flutter run            # on whatever `flutter devices` lists
```

Endpoints and the swappable base-map URL live in `lib/config.dart`. The research behind each
source (LibreWXR, NWS, OSM, WZDx, IDOT, Android Auto, CarPlay) was written as orclab background
skills and moved there on 2026-09-14: `orclab/skills/{source-librewxr,source-road-conditions,
map-openstreetmap,car-android-auto,car-carplay}`.
