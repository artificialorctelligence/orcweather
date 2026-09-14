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

## #5: Linux desktop toolchain missing on the dev machine

`flutter doctor` 2026-09-14: clang++, CMake and ninja absent, so `flutter build linux` cannot run
here. Only matters when the desktop milestone starts; `sudo apt install clang cmake ninja-build
libgtk-3-dev` fixes it. Android and tests are unaffected.
