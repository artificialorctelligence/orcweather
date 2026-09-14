---
name: map-openstreetmap
description: Background knowledge for any app that draws a map - the OpenStreetMap tile usage policy and what it forbids in a shipped app, the Flutter map widget that runs on all six Flutter targets, how to keep the base-tile provider swappable, and how a raster weather overlay stacks on top. Not a command; Claude reads it when a map or OSM tiles are in play.
user-invocable: false
---

# OpenStreetMap base map — policy, Flutter client, swappable provider

**Checked against live sources on 2026-09-14.** `flutter_map` **8.3.2** (published 2026-08-27;
Dart SDK `>=3.6.0 <4.0.0`; pub.dev platform tags android, ios, windows, linux, macos, web;
2,177 likes, 770k downloads/30 d). `maplibre_gl` **0.27.1** (2026-09-10; android, ios, web only;
128 likes, 104k/30 d). OSMF Tile Usage Policy page carries no date of its own.

**No Orclab project has shipped a map yet.** Researched knowledge (BACKLOG #33); the first real
app corrects it.

## The one thing to know about `tile.openstreetmap.org`

OSM's *data* is free for everyone; its *tile servers* are not. The policy's own words: *"Our tile
servers are not: they are funded by donations and sponsorship, and capacity is limited"*, and
*"We may block access, without notice, if your usage degrades the service."* Section 7 adds:
*"Commercial services, or those that seek donations, should be especially aware that access may
be withdrawn at any point."* `flutter_map`'s docs say the same more bluntly: *"The
OpenStreetMap public tile server is NOT free to use by everyone."*

So the default is: **prototype and personal use on `tile.openstreetmap.org`, following every rule
below; design the tile URL as configuration so a shipped app can move to another provider
without touching map code.** That is what "modular base layer" costs — one `TileLayer`
constructor argument, not an abstraction.

### Rules the policy states (confirmed live 2026-09-14)

Must:
- URL exactly `https://tile.openstreetmap.org/{z}/{x}/{y}.png` (HTTPS; there are no `{r}`
  retina or 512 px variants on this server).
- **Visible licence attribution on the map**, per the Attribution Guidelines — not *"beneath UI,
  behind toggles, or off-screen"*. Text: "© OpenStreetMap contributors" linking to
  `openstreetmap.org/copyright`.
- **A clear, unique `User-Agent` naming the app** (optionally with contact). *"Do not use a
  library default User-Agent"* — *"Traffic that uses these defaults will be blocked."*
  `flutter_map` warns that even `com.example.app` gets a blocked tile.
- **Cache tiles** per HTTP headers, or ≥ 7 days if the cache cannot read them; never send
  `no-cache` headers by default.

Must not:
- **Bulk download**: *"any pre-emptive fetching of tiles other than those a user is actively
  viewing"* — pre-seeding areas, building `.mbtiles` archives, wide automated scans. *"Offline
  use is not permitted on tile.openstreetmap.org."* → An offline-maps feature needs another
  provider or self-hosting; `flutter_map_tile_caching` (10.1.1, 2025-03-09) must not point here.
- Masquerade as another app's User-Agent; strip Referer (web); use HTTP.

No SLA; also covered by the OSMF Terms of Use.

### Where to go when it is time to move

The policy's own section 8: community raster providers
(`wiki.openstreetmap.org/wiki/Raster_tile_providers`), commercial providers
(`switch2osm.org/providers/`), running your own (`switch2osm.org`), or **vector tiles**, which
*"where the provider terms permit can be packaged for offline use"*. Pick when the app has users
or needs offline; not before.

## Flutter client: `flutter_map` (default), `maplibre_gl` (alternative)

**`flutter_map`** is pure Dart — no native code, so no privacy manifest, no 16 KB-page concern,
and it is the only one of the two that runs on Linux/Windows/macOS. Its self-description:
*"vendor-free, fully cross-platform, and 100% pure-Flutter."* Raster tiles only by default;
vector tiles via a plugin. What the docs say to do (confirmed live 2026-09-14):

- `TileLayer(urlTemplate: …, userAgentPackageName: '<applicationId>')` — sent as
  `flutter_map (<userAgentPackageName>)`. Use the real bundle/application id.
- Built-in tile caching since **8.2.0** (their OSM page: *"Enable caching (automatic in
  v8.2.0+)"*), which is what satisfies the 7-day rule.
- A long-lived HTTP client keeps connections open; `CancellableNetworkTileProvider` helps on web.
- 512 px tiles: `tileDimension: 512, zoomOffset: -1` — relevant for LibreWXR's `size=512`
  radar tiles, not for OSM.
- Attribution: `RichAttributionWidget` / `SimpleAttributionWidget` are the provided widgets.

**Overlay stacking**: `FlutterMap(children: [baseTileLayer, radarTileLayer, PolygonLayer(alerts),
MarkerLayer(position), attribution])` — children paint in order; wrap a layer in `Opacity` (or
use `TileLayer`'s tile display options) for a translucent radar. A weather overlay is therefore
a second `TileLayer` with a different `urlTemplate`, nothing more.

**`maplibre_gl`** is the alternative when vector styles, GPU rendering of large GeoJSON, or
offline regions matter; it is native (MapLibre Native on Android/iOS) so the store checks apply
(privacy manifest, 16 KB alignment), and it does **not** cover desktop — a project that ticks
Linux/Windows/Mac keeps `flutter_map`.

## Location and the 50-mile circle

`geolocator` **14.0.3** (2026-06-12) is the current position plugin; the circle is a
`CircleLayer` with `useRadiusInMeter: true` (50 mi = 80,467 m). Zoom-to-radius is arithmetic on
the map camera (`fitCamera` to the circle's bounds), no library. Voice control is
`speech_to_text` 7.5.0 (2026-09-14) feeding the same zoom function — a separate concern from
the map.

## Sources (live on 2026-09-14)

- OSMF Tile Usage Policy: `https://operations.osmfoundation.org/policies/tiles/`
- OSM attribution guidelines (linked from the policy): `https://osmfoundation.org/wiki/Licence/Attribution_Guidelines`
- `flutter_map`: `https://pub.dev/api/packages/flutter_map`, `https://pub.dev/api/packages/flutter_map/score`; docs `https://docs.fleaflet.dev/layers/tile-layer`, `https://docs.fleaflet.dev/tile-servers/using-openstreetmap-direct`
- `maplibre_gl`: `https://pub.dev/api/packages/maplibre_gl`, `/score`
- `flutter_map_tile_caching`, `geolocator`, `speech_to_text`: `https://pub.dev/api/packages/<name>`
- Alternatives named by the policy: `https://wiki.openstreetmap.org/wiki/Raster_tile_providers`, `https://switch2osm.org/providers/`
