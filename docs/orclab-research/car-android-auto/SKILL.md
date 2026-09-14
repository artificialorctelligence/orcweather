---
name: car-android-auto
description: Background knowledge for putting an app on Android Auto or Android Automotive OS through the Car App Library - which categories exist (weather is one), what a weather app may draw, the manifest lines, the quality rules it is reviewed against, and how a Flutter app reaches the car surface. Not a command; Claude reads it when Android Auto is in play.
user-invocable: false
---

# Android Auto / Android Automotive OS — templated car apps, weather category

**Checked against live sources on 2026-09-14.** Car App Library (`androidx.car.app`) latest
**stable 1.7.0 (2025-07-16)**; latest pre-release 1.9.0-alpha02 (2026-09-09). Overview page
updated 2026-06-18, weather guide 2026-05-28, draw-maps guide 2026-03-05, quality guidelines
2026-09-14.

**No Orclab project has shipped to a car yet.** Researched knowledge (BACKLOG #33); the first
real app corrects it.

## The model

Car apps do not draw their own UI. They hand the host *templates* (lists, grids, panes, maps
with content) and the host renders them to driver-distraction rules. Overview: *"Use the
Android for Cars App Library, androidx.car.app, to bring your navigation, point of interest
(POI), Internet of Things (IoT), and weather apps to the car."* Those four are the Car App
Library categories; media/messaging use other APIs. **Weather is a first-class category.**

The app is an Android `Service` — a `CarAppService` returning a `Session` returning `Screen`s —
that lives in the phone app's APK and is reviewed against the car quality guidelines at Play.

## Weather apps specifically (weather guide, confirmed live 2026-09-14)

*"Weather apps let users see relevant weather information related to their current location or
along their route."*

Manifest, verbatim shape:
```xml
<service android:name=".MyCarAppService" android:exported="true">
  <intent-filter>
    <action android:name="androidx.car.app.CarAppService" />
    <category android:name="androidx.car.app.category.WEATHER"/>
  </intent-filter>
</service>
```
plus, to draw a map, **exactly one** of
`<uses-permission android:name="androidx.car.app.MAP_TEMPLATES"/>` (no navigation) or
`androidx.car.app.NAVIGATION_TEMPLATES` (app also navigates) — *"Don't include both … or your
app will be rejected during review."* Drawing to the surface also needs
`androidx.car.app.ACCESS_SURFACE`. An app that navigates too adds `category.NAVIGATION`
alongside `WEATHER` in the same intent filter.

Template: *"Weather apps can access the `MapWithContentTemplate`, which can be used to display
lists and other types of content alongside a map that is rendered by your app."* `MapTemplate`,
`PlaceListNavigationTemplate` and `RoutePreviewNavigationTemplate` are **deprecated** in favour
of `MapWithContentTemplate` (release notes, 1.7.0-alpha01 onward).

## Quality rules a weather app is reviewed against (car-app-quality, updated 2026-09-14)

- **WE-1** content relevant to *"the user's current location or a user specified location."*
- **WE-2** *"Weather information on map tiles must be readable and may not include complex
  legends. Apps may include a maximum of three legends. Apps with multiple legends may have a
  maximum of three colors, whereas single legend apps may have more than three colors."* → A
  radar overlay with one legend may keep its full colour ramp; adding a wind legend caps every
  legend at three colours.
- **WE-3** forecast icons/symbols easily readable. **WE-4** no forecast-interval customisation
  via templates.
- **WE-5** *"must not show more than five unique weather map annotations in a given view (for
  example: Temperature markers, wind speed markers, humidity, radar overlay, lightning
  indicators, road conditions all in the same view)."*
- **MR-1** draw a light or dark map when the host says so (`CarContext.isDarkMode`, redraw on
  `Session.onCarConfigurationChanged`); users may pin one theme.

## Drawing the map (draw-maps guide, confirmed live 2026-09-14)

`carContext.getCarService(AppManager::class.java).setSurfaceCallback(surfaceCallback)`; the
host hands a raw `android.view.Surface` in `onSurfaceAvailable(SurfaceContainer)`, tells you
the unobstructed rect via `onVisibleAreaChanged` and the always-visible rect via
`onStableAreaChanged`. Two sanctioned ways to paint: *"In addition to rendering directly into
the Surface using the Canvas API, you can also render Views into the Surface using the
VirtualDisplay and Presentation APIs."*

## Flutter and the car

Flutter has no car support of its own; the `CarAppService` is Kotlin in `android/app/src/main/`.
Options, in order of least code:

1. **Templates only, no map** — `flutter_carplay` 1.6.5 (pub.dev 2026-08-21; GitHub pushed
   2026-08-21, 315 stars, MIT) drives Android Auto List/Grid/Tab/Alert/Message/Pane templates
   from Dart. Its README lists **"Map Template" as a road-map item on both platforms** — no
   radar on the car screen through it today. The older `flutter_android_auto_os` (24 stars,
   last push 2023-04-05, not on pub.dev) is dead.
2. **Map via VirtualDisplay + Presentation** — the documented Android path above: a second
   `FlutterEngine` (different Dart entrypoint, e.g. `carMain`) attached to a `FlutterView`
   inside a `Presentation` on a `VirtualDisplay` backed by the car `Surface`, sized from
   `SurfaceContainer`. The car screen then shows the same `flutter_map` radar the phone does,
   while `MapWithContentTemplate`'s list/pane content stays native-templated. Hand-written
   Kotlin; no package does this. Untested by Orclab — mark as the first thing to prove.
3. **Native Kotlin map** on the car surface (e.g. a Canvas or an Android map SDK) with Dart
   only feeding data over a `MethodChannel` — most code, most control.

Cache the engine (`FlutterEngineCache`) so the car service reuses the running app's engine when
the app is foregrounded and creates one otherwise.

## Testing without a car

Android Auto's **Desktop Head Unit (DHU)** from the SDK Manager (Extras) drives a phone app
over ADB; Android Automotive OS has emulator images. Both live under developer.android.com
`training/cars/testing` — not re-verified in detail on 2026-09-14.

## Where this lands in Flutter's build

Car App Library is a Gradle dependency in `android/app/build.gradle.kts`
(`androidx.car.app:app:1.7.0`, plus `app-projected` for Android Auto, `app-automotive` for
AAOS); its default minSdk moved to **API 23** in 1.8.0-alpha02 (Flutter's default is 24, so no
conflict). The manifest lines above go in `android/app/src/main/AndroidManifest.xml`; Play's
car review is opted into per-form-factor in Play Console.

## Sources (live on 2026-09-14)

- Overview / categories: `https://developer.android.com/training/cars/apps`
- Weather guide: `https://developer.android.com/training/cars/apps/weather`
- Draw maps: `https://developer.android.com/training/cars/apps/library/draw-maps`
- Quality guidelines (WE-*, MR-1): `https://developer.android.com/docs/quality-guidelines/car-app-quality`
- Release notes / versions: `https://developer.android.com/jetpack/androidx/releases/car-app`
- Flutter packages: `https://github.com/oguzhnatly/flutter_carplay`, `https://pub.dev/api/packages/flutter_carplay`, `https://api.github.com/repos/oguzhnatly/flutter_carplay`, `https://api.github.com/repos/Flutter-Auto-Technologies/flutter_android_auto_os`
