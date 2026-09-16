# Backlog

Open items not yet scheduled into a task. Each entry keeps the context that
led to it - not just "what," but "why this matters" - so picking it up later
doesn't require re-deriving the reasoning from scratch.

## #1: OSM public tiles are the base map; must move providers before any public release

Scaffolded 2026-09-14 with `tile.openstreetmap.org` in `lib/config.dart` because it is free and
policy-compliant for prototypes. The OSMF policy (docs/orclab-research/map-openstreetmap) says
access may be withdrawn without notice, forbids offline use, and is not sized for distributed
apps. Consequence: a shipped app can go blank the day OSMF blocks it. Does not affect the
LibreWXR radar overlay, which has its own host. Fix: change `baseTileUrl`/`baseAttribution` to a
provider from switch2osm.org/providers/ (or self-host) before the first store release.

## #2: Voice zoom command not built

Requested at kickoff (2026-09-14): zoom by voice as well as buttons. Deferred until the map works
on a phone. Plan: `speech_to_text` 7.5.0 feeding the same `_zoomBy`/`_fitRadius` functions in
`lib/main.dart`; nothing else changes. Consequence of not doing it: hands-on-screen zoom only.

## #3: Android Auto: MapWithContentTemplate + Flutter map on the car surface unproven

Research (docs/orclab-research/car-android-auto, 2026-09-14) found the documented path —
VirtualDisplay + Presentation hosting a second FlutterEngine on the car Surface — but no package
does it and Orclab has never run it. Consequence: the AA milestone carries a real spike before
any feature work; WE-2/WE-5 quality rules also constrain legend colours and annotation count.
Needs the Desktop Head Unit to test. Not started.

## #4: CarPlay: only a WidgetKit widget / Live Activity is possible; needs a Mac

Apple does not have a weather category and only navigation apps may draw the map (research
2026-09-14, docs/orclab-research/car-carplay). The deliverable is a small widget + a Live
Activity for an active warning via `home_widget`, built in Xcode (Codemagic per stack-flutter).
Consequence: no CarPlay work is possible from this Linux machine alone. Not started.

**Update 2026-09-14:** verified against Apple's CarPlay App Programming Guide (2026-06-08).
CARROT Weather, MyRadar and Storm Radar are on CarPlay because they ship turn-by-turn
navigation and hold the navigation entitlement; that is the only route to a radar map on the
car screen. Widget + Live Activity remains the entitlement-free path.

## #5: Linux desktop toolchain missing on the dev machine

`flutter doctor` 2026-09-14: clang++, CMake and ninja absent, so `flutter build linux` cannot run
here. Only matters when the desktop milestone starts; `sudo apt install clang cmake ninja-build
libgtk-3-dev` fixes it. Android and tests are unaffected.

## #6: Road conditions: source undecided, no free national feed

Requested 2026-09-14. Research (docs/orclab-research/source-road-conditions): reported surface
conditions come only from per-state 511 APIs (free, heterogeneous) or Road511 ($29/mo, all
states, GeoJSON). Free national options are WZDx work zones (not surface state) and inferring
"road risk" from NWS temperature/precip + winter/fog alerts the app already fetches.
Consequence: the feature cannot be built as "reported conditions everywhere" without paying.
Decision needed: which state(s) the user drives in (→ 511), or Road511, or start with inferred
risk + WZDx.

**Update 2026-09-14:** built three of the four: inferred road risk (`lib/road_risk.dart`),
WZDx work zones chosen by the state NWS returns for the GPS position (`lib/wzdx.dart`, 26 of
43 registry feeds work keyless — neither Illinois feed does), and IDOT reported winter
conditions for Illinois (`lib/idot.dart`, free ArcGIS service, server-side radius query).
Still open: reported conditions outside Illinois (look for each state DOT's ArcGIS Open Data
portal first, then 511 API, then Road511), and Illinois work zones (IDOT/Tollway WZDx keys —
request them).

## #7: Simple audio controls for whatever app is playing (Spotify, Audible, …)

Requested 2026-09-14: play/pause/skip buttons on the map screen so the driver never has to
leave orcweather to control the podcast or music app already playing. Consequence of not
having it: the app is not a "leave it on the dash" app — every audio touch means switching apps.

Not researched yet; from memory, to be verified under currency-discipline before building:
Android can send media key events to the active media session with no special permission
(`AudioManager.dispatchMediaKeyEvent` with `KEYCODE_MEDIA_PLAY_PAUSE` / `_NEXT` / `_PREVIOUS`);
showing what is playing (title, app) needs `MediaSessionManager.getActiveSessions`, which
requires the notification-listener permission the user grants in Settings. iOS has no public
API to control another app's playback — `MPMusicPlayerController.systemMusicPlayer` reaches
only Apple Music — so the iPhone version likely cannot do this at all, and the writeup must say
so rather than promise it. Either way it is a small platform-channel plugin in
`android/app/src/main/kotlin/`, no Dart package needed unless one exists and is current.

## #8: Keep tracking and warning while backgrounded or screen locked

Asked 2026-09-15 after confirming the map follows the car. Today the geolocator stream and the
5-minute weather refresh only run while the app is in the foreground with the screen on; lock
the phone or switch apps and position, alerts and radar stop updating, so a new warning that
arrives while Spotify is in front is never noticed. Consequence: the app is only a "screen on,
app in front" tool.

What it takes: Android foreground service with a persistent notification (geolocator supports
`foregroundNotificationConfig` in `AndroidSettings`; needs `FOREGROUND_SERVICE_LOCATION` and
`ACCESS_BACKGROUND_LOCATION` handling and Play's background-location policy declaration), the
alert check moved into that service's tick, and a local notification (`flutter_local_notifications`,
per stack-flutter) when a warning polygon newly contains the position. iOS: "Always" location
plus background modes, reviewed by Apple. Battery and Play review are the costs; do it after the
foreground app is solid.

## #9: Radar animation (past + nowcast) on the phone, never while driving

Decided 2026-09-15: animate the LibreWXR frame list (12 past + 6 nowcast, 10 min apart, already
parsed in `RadarFrames`) behind a play button that is off by default, so a passenger can scrub
the loop and the default driving view stays a still frame. Not available while driving — same
reasoning as CarPlay/Android Auto's rules and MyRadar's "animation restricted for essential
safety compliance": a looping radar in peripheral vision is driver distraction. Gate on the
GPS speed the app already tracks (`_moving`), plus never on any car screen. Implementation is a
timer swapping the radar `TileLayer` urlTemplate through `past + nowcast`; prefetching the next
frame's tiles keeps the loop smooth. Consequence of not doing it: no storm-motion cue on the
phone; the still frame plus alerts remain.

## #10: Proxy server for keys and shared upstreams (direflail's Python-capable web server)

Decided 2026-09-15 while discussing how apps handle API keys. direflail has a web server that can
run Python and will set it up. The app then talks to that host instead of upstreams directly,
which solves three things at once:

1. Keys never ship in the APK (IDOT CWZ work-zone key first; any future paid source) — the
   proxy adds them server-side.
2. Abuse and blocking land on the proxy, not on every phone's User-Agent: it can cache and
   rate-limit per client, and OSM's tile policy and LibreWXR's terms both point heavy or
   distributed use at exactly this shape (a CDN/cache in front is "encouraged" by LibreWXR).
3. It is the natural home for the base-map switch (BACKLOG #1) — the proxy can front a
   different tile provider or a self-hosted tile server later without an app update.

Shape: a small FastAPI app (stack-web's back-end choice) with routes mirroring what
`lib/config.dart` calls — `/tiles/base/{z}/{x}/{y}.png`, `/radar/...`, `/alerts`, `/nws/...`,
`/workzones?state=`, `/roads?lat=&lon=` — each forwarding upstream with the right User-Agent
and key, honouring upstream Cache-Control and adding its own cache. Then `lib/config.dart`
hosts point at the proxy; nothing else in the app changes. Keep LibreWXR self-hosting
(8 vCPU / 16 GiB minimum) as a separate, later decision — the proxy caches its public
instance first. Consequence of not doing it: keys in the binary and every user hitting OSM
and LibreWXR directly under one User-Agent, which is how an app gets blocked.

**Update 2026-09-15:** first concrete consumer is lightning (#11) — the proxy owns the GOES GLM
poller and the `/lightning` endpoint; nothing else in the app can provide it.

## #11: Lightning layer from NOAA GLM via the proxy, with a settings toggle

Asked 2026-09-15. Research the same day (`docs/research/source-lightning.md`): Blitzortung forbids it
(raw data for participants only; "not allowed to use our lightning data for storm warning
systems"); commercial APIs (Xweather, Vaisala) cost money; NWS has no lightning product. The
free, public-domain source is NOAA's GOES-19 Geostationary Lightning Mapper on the public
bucket `noaa-goes19` (`GLM-L2-LCFA/YYYY/DDD/HH/*.nc`, one netCDF per 20 s, ~400 KB, created
~20 s after the period; GOES-18 covers the west). Verified live: 375 flashes in one file, 32
within 300 km of Peoria. `flash_lat`/`flash_lon` are scaled int16 (apply `scale_factor` +
`add_offset`); `flash_energy` in J; h5py + numpy read it in ~15 lines.

Blocked on BACKLOG #10: the phone must not poll 1.2 MB/min of HDF5. Proxy job: poll the bucket
every 20 s, keep a rolling 30 min of (lat, lon, time) in memory, serve
`GET /lightning?bbox=w,s,e,n&minutes=15` as GeoJSON points with an `age_s` property. App side:
a `MarkerLayer` of small bolts fading with age, refreshed on the 2-minute tick (or faster when a
warning is active), a `Settings.lightning` bool persisted like the others, default on once it
exists — a dead toggle is worse than none, so the setting lands with the layer, not before.
Attribution: "Lightning: NOAA GOES GLM" in the sources dialog.

## #12: Finish /orc-test generate round 2: kill the surviving mutants, clear TCE 70 (RESOLVED 2026-09-16)

Where it stopped 2026-09-15 night, to be picked up first. Round 1 raised coverage to 92.0% of
587 lines (all files measured) but TCE was 52% over everything. Round 2's diagnostic run
(`mutation_test.xml` at the project root — logic files only, colour table and debug fixture
excluded with the reason in the file; `dart run mutation_test mutation_test.xml -c
coverage/lcov.info -f xunit -o .orclab/test/dart/round2`) scored **65% killed, 127 of 362
survived**, report at `.orclab/test/dart/round2/mutation-test.xunit.xml` (per-file classname,
`LineNN_<mutation>` names).

What survives and the test that kills it:
- `lib/main.dart` (58): four `if`s — `_onMapEvent` follow/snap-back branches (lines ~194–228),
  `_snapBack` guard, `_refreshRoads` gate call, the strip's `roadsBad` chip (~553). Needs a
  widget test that performs a real one-finger drag (following stops, recenter button restores)
  and a two-pointer pinch with Center-on-zoom on/off (snap back vs not), plus a strip case with
  `roadRisk` set but `reportedBad == 0` (the `!` amber chip).
- `lib/map_logic.dart` (8): `skyIcon` alternatives (sleet, ice, drizzle, haze, smoke, overcast);
  `roadsDue` at exactly 30 min; `fitBounds` exact N/S/E/W distances.
- `lib/road_risk.dart` (2): boundaries — exactly 34°F with precip → ice; exactly 30% precip → wet.
- `lib/compass.dart` (6): assert the smoothed value after one sample is exactly 20% of the way
  (alpha 0.2) and the upright threshold at |az| = 0.7.
- `lib/librewxr.dart`/`wzdx.dart`/`idot.dart`/`nws.dart` (12): exact bbox edge distances
  (`Distance().offset` at 0/90/180/270 → ±0.72° lat at 80 km), lat/lon rounding to 4 dp.
- `lib/config.dart` (4): constants — leave; data.

Then: `flutter test` green, re-run the same mutation command (~21 min), show before → after
(65% → target ≥70%), commit with /orc-git. Rule: never a third round without asking.

Two orclab tooling findings to file in orclab's own backlog (not done): `run.py` treats
mutation_test's exit 255 (its own gate failed) as "not measurable" though the report exists,
and its `-f junit` report has no file names — `-f xunit` does (classname). `run.py` should
also accept a project `mutation_test.xml`.

**Resolved for real, not just tracked** (2026-09-16): 17 tests added (59 → 76) against the
survivor list — boundary assertions on `roadsDue` (30:00 vs 30:01), `movingFix` (2 m/s, heading
0), `roadRisk` (34/35°F, 29/30%), `skyIcon` alternatives, exact bbox edges via `Distance().offset`
in LibreWXR/fitBounds, compass alpha (14.04° after one smoothed step) and the |z| = 0.7 axis
flip, non-200 paths for NWS/WZDx/IDOT, and widget tests that drive a real one-finger drag and
a two-pointer pinch with Center-on-zoom off/on, the 2-minute tick (weather refetched, roads
not), and a cold quiet day (estimated `!` chip, work-zone chip, no alert chip). The old "second
fix does not refetch roads" test was replaced — it passed trivially because weather refreshes
only on the first fix. Re-ran the same mutation command: **72 of 362 undetected, 80.1% killed
(was 127 undetected, 64.9%)**; mutation_test's own 70 gate passed (exit 0). Per file, survivors
in main.dart 58 → 33, map_logic 8 → 3, road_risk 2 → 0. The remaining ones are constants
(alpha, colour-matrix rows, radius/metre conventions) and equivalent mutants (cos(−x), bearing
−0). Coverage unchanged at 92%. Hand check: raising the drag threshold 24 → 240 px made the
drag widget test fail before revert.

