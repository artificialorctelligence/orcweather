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
