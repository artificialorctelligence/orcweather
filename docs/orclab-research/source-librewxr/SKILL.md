---
name: source-librewxr
description: Background knowledge for any app that shows weather radar, precipitation nowcast, storm cells or weather alerts from LibreWXR - what its API serves and does not serve, the public instance's terms, self-hosting cost, and the tile URL shapes a map client needs. Not a command; Claude reads it when LibreWXR is in play.
user-invocable: false
---

# LibreWXR — radar, nowcast, storm cells and alerts as a Rain Viewer-shaped API

**Checked against live sources on 2026-09-14.** Repository last commit 2026-09-10; `pyproject.toml`
`version = "0.1.0"`, **no tagged GitHub release** (`/releases/latest` is empty) — the project
versions by commit, so "current" means `main`. Public instance `https://api.librewxr.net`
answered `/health` with `"status":"ok"` and 548,065 s uptime at check time. Terms of Use last
updated 2026-06-20.

**No Orclab project has shipped against LibreWXR yet.** This is researched knowledge in the
BACKLOG #33 sense; orcweather is the first real use and corrects it.

## What it is

Self-hosted, AGPL-3.0-or-later Python service (Python ≥ 3.11) that is *"a drop-in replacement
for the Rain Viewer API"*: it aggregates government radar composites, a regional NWP chain and
satellite imagery into Web-Mercator PNG/WebP tiles, and serves WMO CAP + NWS alerts as GeoJSON.
Its reason to exist: Rain Viewer restricted its free tier on 2026-01-01.

## What it serves — and what it does not

| Serves (confirmed live 2026-09-14) | Does **not** serve |
|---|---|
| Radar/precip tiles, past + nowcast | **Point weather**: temperature, wind speed/direction, humidity, pressure, forecasts. Nothing in the API or docs returns these — an app needing them pairs LibreWXR with a second source (see `## Companion sources`). |
| Satellite tiles (NOAA GMGSI, hourly) | Lightning |
| Coverage overlay tiles | Road conditions |
| Alerts as GeoJSON polygons (point / bbox query) | |
| Storm cells as GeoJSON (point + radius query) | |
| `/health`, and an MCP endpoint (`POST /mcp`) | |

## API shapes (from the README; all confirmed live 2026-09-14 against api.librewxr.net)

- **Frame index** — `GET /public/weather-maps.json` → Rain Viewer v2 shape:
  `{"version":"2.0","generated":<unix>,"host":"https://api.librewxr.net","radar":{"past":[{"time":<unix>,"path":"/v2/radar/<unix>"},…],"nowcast":[…]},"colorSchemes":[{"id":0,"name":"Black and White"},…]}`.
  Live: **12 past frames + 6 nowcast frames, 600 s apart** (2 h back, 1 h ahead). Poll this,
  then build tile URLs from `host + path`.
- **Radar tile** — `GET /v2/radar/{timestamp}/{size}/{z}/{x}/{y}/{color}/{smooth}_{snow}.{ext}`
  — `size` 256|512, `color` 0–14 (255 = raw), `smooth` 0|1, `snow` 0|1, `ext` png|webp.
  Optional `?arrows=light|dark` (motion vectors), `?cells=light|dark` (storm-cell markers).
  Live tile answered `200 image/png` with **`cache-control: public, max-age=300`**.
  Fifteen colour schemes; id 1 is "Rainviewer Original", id 2 "Universal Blue", id 6 "NEXRAD
  Level III", id 11 "MRMS CREF".
- **Point-centred tile** — `GET /v2/radar/{timestamp}/{size}/{z}/{lat}/{lon}/{color}/{smooth}_{snow}.{ext}`
  (a single image centred on a coordinate — a dependency-free widget, not a map layer).
- **Satellite** — `GET /v2/satellite/{timestamp}/{size}/{z}/{x}/{y}/0/0_0.{ext}`.
- **Coverage** — `GET /v2/coverage/0/{size}/{z}/{x}/{y}/0/0_0.png`.
- **Alerts** — `GET /v2/alerts` (all), `?lat=&lon=` (containing a point), `?bbox=west,south,east,north`
  (intersecting). GeoJSON `FeatureCollection`; geometries seen live: `Polygon` (186) and
  `MultiPolygon` (37) of 223 CONUS-bbox features. **Every feature's `properties` had exactly
  these keys**: `title`, `severity`, `time` (unix), `expires` (unix), `description`, `regions`
  (list of strings), `uri` (source CAP XML). `severity` values seen: `Minor`, `Moderate`,
  `Severe`, `Extreme`. The README's mention of `urgency`/`event` fields did **not** appear in
  live output — code against what is served, not the README. `HEAD` on `/v2/alerts` returns
  405; use `GET`.
- **Storm cells** — `GET /v2/storm-cells`, `?lat=&lon=&radius_km=`. GeoJSON.
- **Health** — `GET /health`: `cluster.memory.container.{anon_mb,file_mb,limit_mb}`, worker
  counts, `requests.hit_rate`, tile latency. The sizing doc calls it "the source of truth".

## Data behind the tiles (README, confirmed live 2026-09-14)

Radar composites for 15 regions — US via **NCEP MRMS** (IEM fallback), Canada MSC GeoMet,
Europe EUMETNET OPERA (27 countries) + DPC Italy, Japan JMA, Taiwan CWA, Malaysia, Philippines,
El Salvador; global fill 60°S–70°N from **NOAA RRQPE** (satellite-derived, observed). Nowcast
comes from a specificity-first NWP chain: **HRRR (3 km) over CONUS**, HRRR-Alaska, HRDPS, DMI
HARMONIE, ICON-EU, AROME, JMA MSM, ECMWF IFS (9 km) globally. Alerts: WMO CAP
(`severeweather.wmo.int`, 5-min refresh) + NWS API with zone-polygon resolution.

## The public instance — terms that bind an app (librewxr.net/terms.html, updated 2026-06-20)

- **As-is, no SLA**: *"I may change, rate-limit, throttle, or take the service offline at any
  time, with or without notice."*
- **Not safety-critical**: *"must not be relied upon as the sole basis for safety-of-life or
  safety-critical decisions. Always defer to your national meteorological or emergency
  service."* → A driving weather app must say so in-app and must not present LibreWXR alerts
  as the official warning; the `uri` field points at the official CAP.
- **Licence**: output is **CC-BY-4.0**, except tiles that include Italian DPC radar, which are
  **CC-BY-SA-4.0**.
- **Attribution, mandatory**: *"Weather data via LibreWXR (librewxr.net)"* **plus** the
  underlying agencies' credits — *"You are responsible for carrying those attributions through
  to your users."* RRQPE asks for *"Precipitation data from NOAA Enterprise Rain Rate (RRQPE)"*.
- **Acceptable use**: personal projects, apps and prototypes are explicitly allowed;
  *"Normal interactive use, including animation playback, is always fine"*; caching and a CDN
  in front are *"encouraged"*. Forbidden: bulk download / archive mirroring, circumventing
  rate limits, re-exposing the hosted endpoint as your own API. Commercial use of the *data* is
  allowed; commercial-scale *traffic* on the public instance is not — email the operator or
  self-host.
- **Privacy**: no analytics, no cookies, no fingerprinting; IPs handled transiently in memory
  for rate limiting; served through Cloudflare. → Play Data safety / App Privacy: the app's
  location is sent to LibreWXR only if you use the `lat`/`lon` query forms; tile requests
  reveal the viewed area by tile coordinate.

## Self-hosting (docs/self-host-sizing.md, confirmed live 2026-09-14)

`git clone … && cp .env.example .env && docker compose up -d`. Two shapes: **single** (one
process; the doc says the Python GIL serialises renders, so *"not recommended for
public-facing instances"*) and **multi** (`COMPOSE_PROFILES=multi`, one pipeline sidecar + N
render workers). Sizing tiers, all "rough estimates" from one reference deployment at ~15
req/s: **minimum public 8 vCPU / 16 GiB / 50 GiB SSD**; recommended 16 vCPU / 32 GiB; heavy
(no CDN) 32 vCPU / 64 GiB. A single-region personal instance (`LIBREWXR_ENABLED_REGIONS`)
behind a caching proxy is the "honest shape" below that floor. Public instance at check time:
20 workers, 64 GiB container limit, ~36 GiB anon.

## Using it from a map client

Any Rain Viewer-capable client works unchanged: point it at `api.librewxr.net` (or your host)
and consume `weather-maps.json`. In Flutter that is a second `TileLayer` over the base map
(see `map-openstreetmap`), with `urlTemplate` =
`<host><path>/256/{z}/{x}/{y}/<color>/1_1.png` and an `Opacity` wrapper; animation is swapping
`<path>` through the `past`+`nowcast` list on a timer, re-fetching `weather-maps.json` every
few minutes (frames are 600 s apart, tiles cache 300 s). Alerts and storm cells are one GeoJSON
polygon layer each. Send a distinct `User-Agent` — the terms do not demand it, but it is how
the operator contacts you before blocking.

## Companion sources for point weather (each confirmed live 2026-09-14)

LibreWXR has no temperature/wind endpoint, so a "current conditions" panel needs one of:

- **NWS `api.weather.gov`** — US only, free, no key, **requires a `User-Agent` identifying the
  app**. `/points/{lat},{lon}` → `properties.forecastHourly` URL → hourly `periods[]` with
  `temperature`, `temperatureUnit`, `windSpeed` (`"17 mph"`, a string), `windDirection`,
  `shortForecast`, `probabilityOfPrecipitation.value`, `relativeHumidity.value`. Official
  source for US warnings too (`/alerts/active?point=`), which is the "defer to your national
  service" the LibreWXR terms ask for.
- **Open-Meteo** — global, free for **non-commercial** use, **CC-BY 4.0**, limits *"Less than
  10'000 API calls per day, 5'000 per hour and 600 per minute"*. One call:
  `/v1/forecast?latitude=&longitude=&current=temperature_2m,wind_speed_10m,wind_gusts_10m,wind_direction_10m,weather_code,precipitation,visibility&wind_speed_unit=mph&temperature_unit=fahrenheit`
  returns numeric fields with units. Commercial use needs its paid tier.

Which one is a project decision (US-only official data vs global non-commercial); record it in
the project's own docs.

## Sources (live on 2026-09-14)

- Repository and README: `https://github.com/JoshuaKimsey/LibreWXR`; version: `https://raw.githubusercontent.com/JoshuaKimsey/LibreWXR/main/pyproject.toml`; last commit: `https://api.github.com/repos/JoshuaKimsey/LibreWXR/commits?per_page=1`; releases: `https://api.github.com/repos/JoshuaKimsey/LibreWXR/releases/latest` (empty)
- Site and docs index: `https://librewxr.net/`, `https://librewxr.net/docs/`; sizing: `https://raw.githubusercontent.com/JoshuaKimsey/LibreWXR/main/docs/self-host-sizing.md`; examples (Leaflet, MapLibre): `https://librewxr.net/examples/`
- Terms of the public instance: `https://librewxr.net/terms.html`
- Live probes: `https://api.librewxr.net/public/weather-maps.json`, `https://api.librewxr.net/health`, `https://api.librewxr.net/v2/alerts?bbox=-125,24,-66,50`, `https://api.librewxr.net/v2/storm-cells?lat=35.5&lon=-97.5&radius_km=80`, a `/v2/radar/…/256/6/15/25/2/1_1.png` tile
- Companions: `https://api.weather.gov/points/35.47,-97.52` and its `forecastHourly`; `https://api.open-meteo.com/v1/forecast?…`; `https://open-meteo.com/en/terms`
