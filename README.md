# orcweather

Weather around your position on the road: OpenStreetMap base, LibreWXR radar + alert polygons,
NWS current conditions, a 50-mile circle, zoom buttons. Flutter; Android first, iOS and desktop
from the same code.

```bash
flutter pub get
flutter analyze && flutter test
flutter run            # on whatever `flutter devices` lists
```

Endpoints and the swappable base-map URL live in `lib/config.dart`. Research on LibreWXR, OSM,
Android Auto and CarPlay (written for orclab) is in `docs/orclab-research/`.
