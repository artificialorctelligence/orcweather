---
name: car-carplay
description: Background knowledge for putting an app on Apple CarPlay - which app categories Apple accepts (weather is not one), that only navigation apps may draw a map on the car screen, the entitlement request, and the iOS 26 widget / Live Activity path that reaches CarPlay with no entitlement. Not a command; Claude reads it when CarPlay is in play.
user-invocable: false
---

# Apple CarPlay — categories, the map window, and the widget path

**Checked against live sources on 2026-09-14** at developer.apple.com/carplay and the CarPlay
framework documentation (read through Apple's `tutorials/data/documentation/*.json`, since the
HTML is script-rendered). Apple dates neither page; the CarPlay page is "© 2026 Apple Inc."

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
requires-iOS-26 detail for CarPlay display should be confirmed in the CarPlay Developer Guide
PDF (linked from the same page) before promising it.

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
- Framework docs (JSON of the script-rendered pages): `https://developer.apple.com/tutorials/data/documentation/carplay.json`, `https://developer.apple.com/tutorials/data/documentation/carplay/displaying-content-in-carplay.json`
- Entitlement request: `https://developer.apple.com/contact/carplay/`
- `home_widget`: `https://pub.dev/api/packages/home_widget`; `flutter_carplay`: `https://github.com/oguzhnatly/flutter_carplay`
