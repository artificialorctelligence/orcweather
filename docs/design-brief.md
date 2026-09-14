# orcweather — design brief

Working notes from the initial scoping conversation. Captures verified research and
open questions so later sessions don't have to re-derive them. Not a spec — supersede
freely.

## Product intent

A driving-oriented weather app. Shows current position, a 50-mile radius ring around
it (zoomable via button and voice), radar, storm warnings, wind speed and general
conditions. Mobile first — Android first — with a separately-designed desktop client
later. Should work in any phone orientation and integrate with Android Auto / CarPlay.

## Data source: LibreWXR

https://github.com/JoshuaKimsey/LibreWXR — AGPL-3.0, self-hostable, Rain Viewer v2
API-compatible. Public instance at `api.librewxr.net`.

Endpoints:

| Endpoint | Purpose |
| --- | --- |
| `/v2/radar/{ts}/{size}/{z}/{x}/{y}/{color}/{smooth}_{snow}.{ext}` | Radar tiles |
| `/v2/satellite/{ts}/{size}/{z}/{x}/{y}/0/0_0.{ext}` | Satellite composite |
| `/v2/alerts` | Active alerts, GeoJSON + CAP metadata |
| `/v2/storm-cells` | Storm cell detection overlay |
| `/v2/coverage/` | Radar coverage visualization |
| `/health` | Health check |

Radar coverage: MRMS (US incl. AK/HI/PR/Guam), MSC (Canada), OPERA (27 European
countries), plus El Salvador, Taiwan, Japan, Malaysia, Philippines. Global
satellite-derived precipitation (NOAA RRQPE, 60S–70N) as fallback.

Alert feed is WMO CAP globally, NWS directly in the US. Features carry polygon plus
severity, urgency, certainty, event, headline, sender, expiry.

### Known gap

**LibreWXR serves no point observations.** No wind speed, temperature, humidity, or
pressure for a lat/lon — precipitation, reflectivity and imagery only. A second source
is required for the "wind speed and other relevant weather information" requirement:

- US-only: `api.weather.gov` — free, no key, pairs naturally since LibreWXR already
  uses NWS for US alerts.
- Global: Open-Meteo or similar.

Coverage decision is unresolved and blocks this choice.

### Deployment note

Self-host for anything shipping; don't build the critical path on a free community
endpoint. AGPL-3.0 means server modifications must be offered as source to its users.

## Constraint: Android Auto / CarPlay may not permit this app

Flagged as a product-level risk, not a technical detail. **Verify against current
developer docs before committing design work** — these policies shift, and this was
assessed in Sept 2026 against knowledge with an earlier cutoff.

Both platforms admit third-party apps only in approved categories. Android Auto:
navigation, media, messaging, EV charging, parking, POI. CarPlay: audio,
communication, navigation, parking, EV charging, fueling, food ordering, driving task.
Neither has a weather category.

Map-drawing surfaces are separately gated. Android Auto's navigation template is
restricted to accepted navigation apps; drawing a map on CarPlay needs Apple's CarPlay
navigation entitlement, which is hard to obtain. Both enforce driver-distraction rules
that disfavor animated, freely-pannable content — i.e. a zoomable radar loop.

Likely outcome: a zoomable radar map on the head unit is not approvable. A minimal
template-based surface (text severe-weather alerts, "storm ahead in N miles") is
plausible. Recommendation: treat car integration as a later phase behind an explicit
feasibility spike, and keep the car surface a thin module over a shared core. If it is
a hard requirement, resolve the entitlement question first.

## Proposed stack

- **Kotlin + Jetpack Compose**, native. Android Auto and CarPlay both need native
  template code, so a cross-platform UI layer costs more than it saves here.
- **Kotlin Multiplatform** for the core (fetching, alert parsing, units, tile URL
  construction, domain models). Reused by the desktop client while its UI stays
  separate — matches the "desktop gets a different interface" plan.
- **MapLibre GL Native** for the map. Open source, no API key, no per-tile billing,
  good raster overlay support, runs on desktop.
- Adaptive layout via `WindowSizeClass` from the first commit; never lock orientation.
  Car mounts are frequently landscape and retrofitting rotation is painful.

## Open design points

- "Current position on the road" is assumed to mean a GPS dot on a map. True
  road-snapping is map-matching, a nav-grade feature — confirm which is meant.
- Voice: push-to-talk preferred over always-listening. Continuous hotword detection
  costs battery, raises privacy questions, and draws Play Store scrutiny.
  Android `SpeechRecognizer` covers "zoom in / zoom out / show radar".
- Warnings push vs pull. Push implies backend infrastructure well beyond a client app.
- **Safety framing.** The app must not present itself as an authoritative alerting
  channel — networks drop, GPS drifts, polling lags. Needs a clear disclaimer
  deferring to Wireless Emergency Alerts and NWS.
- Background location while driving: foreground service, battery budget, and Play
  Store's restricted-permission review all need planning.

## Suggested first milestone

Phone-only Android: map, location, LibreWXR radar overlay with time animation, 50-mile
ring, zoom buttons, alert polygons from `/v2/alerts` with tap-for-detail. No voice, no
car integration, no push. Useful on its own and de-risks the data layer.

## Open questions

1. Coverage area — US-only or global? Blocks the point-observation source choice.
2. Is Android Auto / CarPlay a hard requirement or a nice-to-have?
3. Push or pull for storm warnings?
