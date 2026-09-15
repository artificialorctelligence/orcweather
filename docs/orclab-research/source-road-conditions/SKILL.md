---
name: source-road-conditions
description: Background knowledge for any app that wants to show road conditions (icy, snow-covered, wet, closed, work zones) in the US - there is no free national feed; what exists is per-state 511 APIs, one paid aggregator, the free federal work-zone registry, and inference from weather data already in hand. Not a command; Claude reads it when road conditions are in play.
user-invocable: false
---

# Road conditions (US) — sources, and the absence of a national one

**Checked against live sources on 2026-09-14.** No Orclab project has consumed any of these;
researched knowledge (BACKLOG #33), first real use corrects it.

## The shape of the problem

"Road conditions" are reported by **state DOTs**, each through its own 511 system, each with its
own API (or none). NWS does not produce them — its "United States Road Conditions" page is a
list of links to state 511 sites. There is **no free, national, normalized feed** of reported
surface conditions. Four real options:

## 1. State 511 APIs — free, per state, heterogeneous

Many states expose a developer API behind a free key. Verified example, Wisconsin:
`https://511wi.gov/api/getwinterroadconditions?key={key}&format={format}` returning per
segment `Condition`, `AreaName`, `LocationDescription`, `RoadwayName`, `Polyline` (*"Encoded
polyline describing the geometry of the roadway segment"*), `LastUpdated` (unix). Key via the
site's Developer Resources registration. Several other states run the same vendor platform
with the same URL shape (`/api/getwinterroadconditions`, `/api/getevents`, `/api/getcameras`)
— **verify each state individually before assuming**; others (Iowa) publish through ArcGIS
open-data feature services instead, and some have no API at all. Coverage is "the states you
integrated", nothing else. Right choice when the user drives in one or two known states.

## 2. Road511 — paid aggregator, all states, one GeoJSON contract

`road511.com` (© 2026): *"All 51 US jurisdictions (50 states + DC), and 13 Canadian provinces
and territories"*, *"64 Jurisdictions normalized"*, RFC 7946 GeoJSON, API key in header.
Endpoints `GET /api/v1/events`, `GET /api/v1/features`, `POST /api/v1/routing/route`. Returns
*"incidents, construction, closures, weather"*, *"road conditions"*, cameras, restrictions.
Pricing: 14-day trial (20 RPM, 1k req/day, 2 jurisdictions), then **Starter $29/mo**, Pro
$99/mo, Enterprise $299/mo. Right choice when national coverage matters more than $29/mo; a
dependency on a small vendor is the risk.

## 3. WZDx — free federal work-zone registry (work zones only)

USDOT's Work Zone Data Exchange feed registry
(`https://datahub.transportation.gov/resource/69qe-yiui.json`, Socrata, no key) listed **43
feeds** on 2026-09-14. Probed every one that day with a distinct `User-Agent`: **26 fetchable
without a key** (AZ, DE, HI, ID, IN, IA, KS, KY, LA, MD, MN, MS, MO, NH/VT/ME, NJ, NY, NC, ND,
OK, TX-Austin, UT, WA, WI, plus Québec and two non-state feeds); **12 need an API key**
(`needapikey: true` — CA, CO, IL ×2, MA, MI, OH, OR, PA, TX statewide, VA, NPS); the rest are
broken (bad TLS, 503, no URL, Florida serves undeclared gzip). Registry `state` values are
free-text and inconsistently cased (`"Illinois"` and `"illinois"`, one row is `"New Hampshire,
Vermont, Maine"`) — match case-insensitively by substring. Oklahoma returns 403 without a
User-Agent. Feeds are **statewide, unfiltered**: Wisconsin 10 MB and North Carolina 11 MB
uncompressed with no gzip; New York 527 KB gzipped for 6,917 features. Schema: GeoJSON
`FeatureCollection`, `road_event_feed_info.version` (4.0–4.2 seen), features with
`geometry` LineString or MultiPoint and `properties.core_details.{event_type, road_names[],
direction, description}`. Covers construction/work zones — **not** surface conditions.

State-from-GPS is free: NWS `/points/{lat},{lon}` already returns
`properties.relativeLocation.properties.state` (`"IL"` for Peoria, confirmed 2026-09-14).

## 3b. Illinois specifically — IDOT reported winter road conditions, free, keyless

`https://services2.arcgis.com/aIrBD8yn1TDTEXoz/arcgis/rest/services/IL_DOT_Winter_Road_Conditions_/FeatureServer/2`
(layer `WrcMaintenanceSectionRoutes`, polyline, 410 features statewide, `maxRecordCount` 2000,
data last edited 2026-04-15 — i.e. the previous winter season). Field `Condition` has a coded
domain of exactly four values: `Clear`, `Partly Covered with ice or snow`, `Mostly Covered with
ice or snow`, `Covered with ice or snow`; plus `WrcMntSectionName`, `COUNTY_NAM`, `DIST`. The
ArcGIS `query` endpoint does the radius filter server-side
(`geometry=lon,lat&geometryType=esriGeometryPoint&inSR=4326&distance=80467&units=esriSRUnit_Meter&outSR=4326&f=geojson`)
and returns `MultiLineString` GeoJSON. Confirmed live: three sections within 50 mi of Peoria.
Listed on `gis-idot.opendata.arcgis.com` as "IL DOT Winter Road Conditions"; the public map is
gettingaroundillinois.com. This is the pattern to look for in other states: **a DOT ArcGIS
Open Data portal** often exposes what the 511 site draws, keyless.

## 4. Infer road risk from weather already in hand — free, national, honest if labelled

With NWS hourly (temperature, precipitation probability) and LibreWXR/NWS alerts (Winter Storm
Warning, Ice Storm Warning, Winter Weather Advisory, Flood Warning, Dense Fog Advisory), an app
can show **"road risk"** — freezing temperature + precipitation ⇒ ice risk; active winter/fog
alert ⇒ hazard — without any DOT data. This is what commercial "road weather" products sell
(Xweather road weather, OpenWeatherMap Road Risk API — both paid, model-derived surface state
dry/wet/slush/snow/ice). Label it as an estimate, not a report. Right first step: zero new
sources, and it degrades gracefully to option 1 or 2 where reported data exists.

## Not options

Waze for Cities data (partner agreements only); Google/Apple Maps traffic layers (not exposed
to third parties as data); scraping 511 websites (terms).

## Sources (live on 2026-09-14)

- NWS links page: `https://www.weather.gov/cys/unitedstatesroadconditions`
- Wisconsin 511 API: `https://511wi.gov/developers/help/api/get-api-getwinterroadconditions_key_format`
- Road511: `https://road511.com/`
- WZDx registry: `https://datahub.transportation.gov/resource/69qe-yiui.json`; spec `https://github.com/usdot-jpo-ode/wzdx`
- Iowa DOT open data: `https://data.iowadot.gov/` (Iowa 511 Winter Road Conditions)
- IDOT winter road conditions: `https://gis-idot.opendata.arcgis.com/datasets/il-dot-winter-road-conditions/about`, service `https://services2.arcgis.com/aIrBD8yn1TDTEXoz/arcgis/rest/services/IL_DOT_Winter_Road_Conditions_/FeatureServer/2?f=json`
- NWS `/points` state field: `https://api.weather.gov/points/40.6936,-89.5890`
- Paid model-derived: `https://xweather.com/weather-api/road-weather`, `https://openweathermap.org/api/road-risk`
- Data.gov tag: `https://catalog.data.gov/dataset/?tags=road-conditions`
