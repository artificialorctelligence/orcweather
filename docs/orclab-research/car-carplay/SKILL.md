---
name: car-carplay
description: Background knowledge for putting an app on Apple CarPlay - which app categories Apple accepts (weather is not one), that only navigation apps may draw a map on the car screen, the entitlement request, and the iOS 26 widget / Live Activity path that reaches CarPlay with no entitlement. Not a command; Claude reads it when CarPlay is in play.
user-invocable: false
---

# Apple CarPlay — categories, the map window, and the widget path

**Checked against live sources on 2026-09-14**: developer.apple.com/carplay, the CarPlay framework
documentation (read through Apple's `tutorials/data/documentation/*.json`, since the HTML is
script-rendered), and the **CarPlay App Programming Guide PDF dated 2026-06-08**, which is the
authoritative category and entitlement list.

**No Orclab project has shipped to CarPlay yet.** Researched knowledge (BACKLOG #33); the first
real app corrects it.

## Categories Apple accepts (developer.apple.com/carplay, confirmed live 2026-09-14)

Audio; video (parked); messaging and VoIP (via SiriKit); navigation; EV charging; fueling;
parking; public safety; quick food ordering; voice-based conversational apps; driving task apps;
and — new — widgets and Live Activities. **Weather is not a CarPlay app category.** Every
templated CarPlay app also needs an entitlement Apple grants per app: *"Request CarPlay app
entitlement to let us know if your app has the potential to be supported by CarPlay"*
(`developer.apple.com/contact/carplay/`).

## Only navigation apps get the map window (CarPlay framework docs, confirmed live 2026-09-14)

*"Navigation apps are the only app category that have access to this window, and use it to draw
their map content. All other categories of apps use only the scene's interface controller to
manage their user interface."* And even there: *"Use the window's root view controller to draw
only map content. Don't render alerts, overlays, or any other user interface elements."*

Consequence for a weather app: **a radar map on the CarPlay screen is not available** unless
the app is a turn-by-turn navigation app holding the navigation entitlement. A weather app that
"can also provide navigation" (Android's framing) would have to *be* a navigation app in
Apple's review.

## How CARROT Weather, MyRadar and Storm Radar are on CarPlay anyway (confirmed 2026-09-14)

All three hold the **navigation entitlement** (`com.apple.developer.carplay-maps`) by shipping
real turn-by-turn navigation, and the radar is drawn in the navigation map window:

- CARROT Weather, 2025-01-16: *"When accessed via CarPlay, CARROT Weather becomes a navigation
  app like Google Maps, allowing you to enter your destination and receive turn-by-turn
  directions, while viewing the weather along your driving route."* (MacRumors / 9to5Mac)
- MyRadar 7.81, 2024-01-18: *"CarPlay with RouteCast-powered navigation!"* and *"animation
  restricted for essential safety compliance"* — the radar is a static frame. (9to5Mac)
- Storm Radar 4.0.19, 2026-08-30: *"turn-by-turn directions, automatic rerouting and weather
  alerts."* (9to5Mac, Cult of Mac)

What the guide requires of that entitlement (PDF 2026-06-08, "Additional guidelines for CarPlay
navigation (turn-by-turn directions) apps"): *"1. Navigation apps must provide turn-by-turn
directions with upcoming maneuvers. 2. The base view must be used exclusively to draw a map. Do
not draw windows, alerts, panels, overlays, or user interface elements in the base view."* Plus
voice-prompt audio-session rules, panning-mode button, and *"Immediately terminate route
guidance when requested."* Apple grants the entitlement per app after review of the request.

**So a weather app reaches the CarPlay screen by becoming a navigation app** — routing engine,
maneuver templates, voice prompts, rerouting — with radar as a layer on its own map. That is a
second product, not a feature. There is no lighter path: the guide's driving-task category says
*"Other kinds of CarPlay UI (for example, custom maps, real-time video) are not possible."*

## Notifications in CarPlay (guide PDF 2026-06-08)

*"Notifications are supported in CarPlay communication, EV Charging, parking, and public safety
apps. Starting in iOS 18.4, notifications are also supported in CarPlay driving task apps."* Not
navigation apps' own notifications (route guidance is handled by the framework), and not
non-CarPlay apps. Request with the `.carPlay` authorization option. *"In general, notifications
are not read aloud in CarPlay."* → A weather app without an entitlement gets no CarPlay
notifications; its Live Activity is the sanctioned equivalent.

## The path that does exist: widgets and Live Activities (iOS 26)

Apple's CarPlay page: *"Widgets appear to the left of CarPlay Dashboard and support interaction
on touchscreen vehicle, and Live Activities are automatically shown in CarPlay Dashboard, or as a
notification."* And: *"If your app includes a small widget or Live Activity, it will
automatically appear in CarPlay with no changes required. And if your widget is not functional
or suitable for use in the car, you can indicate that it's not optimized for CarPlay to prevent
it from being shown."*

So the CarPlay deliverable for a weather app is a **small WidgetKit widget** (current conditions,
wind, nearest alert) and optionally a **Live Activity** for an active warning — no CarPlay
entitlement, no templates. Both are Swift/WidgetKit code in an iOS extension target; the
guide PDF (2026-06-08) confirms the version and the mechanics: *"Widgets are supported in CarPlay
Ultra, and with iOS 26 in CarPlay"*; *"Live Activities are supported with iOS 26 in CarPlay and
CarPlay Ultra"*; *"Your app does not need to be a CarPlay app to support widgets and Live
Activities in CarPlay."* Widget: `.supportedFamilies([.systemSmall])`; Live Activity: the
`.small` supplemental activity family (*"If you already support Apple Watch, the same Live
Activity will work in CarPlay"*). *"Your widget can only launch your app in CarPlay if your app
is also a CarPlay app"* — tapping it does nothing for a non-CarPlay app. Test with **CarPlay
Simulator** (Additional Tools for Xcode → Hardware), which needs a Mac.

## Flutter and CarPlay

- **Widgets**: `home_widget` **0.9.4** (pub.dev 2026-09-03) is the bridge — Dart writes the
  values, a native WidgetKit extension renders them. The widget UI itself is SwiftUI, not
  Flutter, and needs Xcode (a Mac or Codemagic per `stack-flutter` "Building without a Mac").
- **Templates** (if the app ever fits a real category): `flutter_carplay` 1.6.5 (2026-08-21,
  MIT, 315 stars) covers List/Grid/Tab Bar/Alert/Information/POI/Search/Now Playing on
  CarPlay; iOS 14+; map template is on its road map, not shipped. Still needs Apple's
  entitlement.

## Where this lands in Flutter's build

Widget extension target in `ios/` (Xcode: File → New → Target → Widget Extension), an App
Group shared between Runner and the extension for `home_widget`'s data, the extension's own
`PrivacyInfo.xcprivacy`. Nothing in `pubspec.yaml` beyond `home_widget`. CarPlay entitlement
(templated apps only) is a provisioning-profile capability, granted by Apple after the request.

## Sources (live on 2026-09-14)

- CarPlay overview, categories, widgets: `https://developer.apple.com/carplay/`
- CarPlay App Programming Guide (PDF, 2026-06-08): `https://developer.apple.com/carplay/documentation/CarPlay-App-Programming-Guide.pdf` — categories p.3, entitlement table p.12, navigation guidelines, widgets p.9, Live Activities, notifications p.26
- Weather apps that are navigation apps: `https://www.macrumors.com/2025/01/16/carrot-weather-carplay/`, `https://9to5mac.com/2025/01/16/carrot-weather-adds-new-carplay-app-for-driving-routes-plus-upgraded-live-activities/`, `https://9to5mac.com/2024/01/18/myradar-carplay/`, `https://9to5mac.com/2026/08/30/apple-carplay-just-added-a-major-weather-app/`
- Framework docs (JSON of the script-rendered pages): `https://developer.apple.com/tutorials/data/documentation/carplay.json`, `https://developer.apple.com/tutorials/data/documentation/carplay/displaying-content-in-carplay.json`
- Entitlement request: `https://developer.apple.com/contact/carplay/`
- `home_widget`: `https://pub.dev/api/packages/home_widget`; `flutter_carplay`: `https://github.com/oguzhnatly/flutter_carplay`
