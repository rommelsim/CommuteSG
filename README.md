# Commute

Native SwiftUI iOS app for Singapore public transport, built per `CLAUDE.md` and the visual spec in `prototype/index.html`.

## Run it

1. Open `Commute.xcodeproj` in Xcode 16 or newer.
2. The project's base configuration points at `Secrets.xcconfig` (gitignored). Confirm it has your LTA DataMall key:
   ```
   LTA_API_KEY = your-key-here
   ```
   If you cloned this somewhere fresh, copy `Secrets.example.xcconfig` to `Secrets.xcconfig` and fill in your key. Get one at https://datamall.lta.gov.sg/content/datamall/en/request-for-api.html.
3. Pick the iPhone 15 simulator (or any iPhone running iOS 17+).
4. Cmd+R.

First launch goes through 3-step onboarding. After that you land on Home with live data populated.

## Project layout

```
Commute.xcodeproj/         hand-rolled, uses Xcode 16 synchronized file groups
Secrets.xcconfig             gitignored — your real keys live here
Secrets.example.xcconfig     committed template
Commute/
├── CommuteApp.swift       @main, injects AppState
├── Info.plist               references $(LTA_API_KEY) for runtime read
├── Models/                  pure data + DTOs (BusArrival, MRTLine, …, LTAResponses)
├── ViewModels/              @Observable VMs + global AppState
├── Services/
│   ├── LTAService.swift     actor wrapping LTA DataMall (BusArrivalv2, TrainServiceAlerts)
│   ├── MockDataService.swift fallback / non-API data
│   └── Secrets.swift        Bundle.main reader for xcconfig values
├── DesignSystem/            Colors (light+dark), Typography, Spacing
├── Views/
│   ├── RootView.swift       onboarding-or-main routing + theme
│   ├── MainTabView.swift    4 tabs, each with own NavigationStack
│   ├── Home / Plan / Fares / Alerts / Detail / Onboarding / Components
└── Assets.xcassets/         AppIcon (empty) + AccentColor
```

## What's real vs mocked

Real (live LTA DataMall):

- **Bus arrivals** — Home cards, bus stop detail, live tracking. Pulled from `BusArrivalv2?BusStopCode=...`. ETAs derive from each service's `EstimatedArrival` ISO timestamp; crowd from `Load` (SEA/SDA/LSD).
- **MRT line status** — Home MRT card derives from `TrainServiceAlerts`.
- **MRT alerts** — top of Alerts screen if any disruptions are live.

Mocked (no public LTA endpoint exists):

- **MRT next-train arrivals** (the 2 min / 5 · 9 min card)
- **Plan journey** results
- **Fare values** ($1.89 / $0.81 / $0.55 / $0.55) — Fares screen has a "Calculate exact fare at LTA →" button that opens [LTA's official calculator](https://www.lta.gov.sg/content/ltagov/en/map/fare-calculator.html) in Safari for real numbers.
- **Bus alerts** (e.g. detours)
- **Station exits, amenities, line map**

Each mocked screen carries a small "Demo data" pill so it's clear at a glance. When LTA is unreachable, real-data screens fall back to mock + show "Demo data" instead of the "Live" pill.

## Behaviors implemented

- 3-step onboarding (`@AppStorage` flag), replayable from Profile as a sheet
- Theme cycles Auto → Light → Dark (Profile → Dark mode), persisted, applied on RootView via `.preferredColorScheme(...)`
- Live ETA on tracking: `Timer.publish(every: 1)`, decrements until 1 min then loops to 3 min, with `.contentTransition(.numericText())`
- Map pulse: `.scaleEffect(1→2.5).opacity(0.6→0)`, `.repeatForever(autoreverses:false)`, 2 s
- Pull-to-refresh on Home, Bus stop detail, Alerts (forces fresh LTA calls bypassing the 30 s cache)
- Filter pills (Plan, Alerts, Bus stop detail) — visual selection only
- Fare calculator: live update with `.snappy` animation when card type changes
- Saved places + favorite stops/lines — persisted JSON in `UserDefaults` via `AppState`
- Haptics: light impact on every card/row tap (`CardButtonStyle`), medium on primary CTAs, `.selection` on filter pills and toggles
- Tab bar hidden on detail screens via `.toolbar(.hidden, for: .tabBar)`
- Swipe-from-left-edge back works automatically (NavigationStack default)

## Adding more API keys

The xcconfig pattern scales. To add a new key (e.g. Google Maps):

1. Add a line to `Secrets.xcconfig` (and the example file with a placeholder):
   ```
   GOOGLE_MAPS_API_KEY = AIza...
   ```
2. Mirror it in `Info.plist`:
   ```xml
   <key>GOOGLE_MAPS_API_KEY</key>
   <string>$(GOOGLE_MAPS_API_KEY)</string>
   ```
3. Add an accessor in `Services/Secrets.swift`:
   ```swift
   static let googleMapsAPIKey = value(for: "GOOGLE_MAPS_API_KEY")
   ```

No Swift code changes anywhere else.

## Security note

Any key shipped in an iOS app binary is extractable by anyone with the `.app` bundle (run `strings Commute.app/Commute | grep LTA`). The xcconfig pattern keeps the key out of source control and source files but does **not** make the running app secure — it's still in the binary. For production, route LTA calls through a backend you control.

The LTA key was pasted in chat history during development. **Rotate it before shipping** at the LTA DataMall portal.

## Caveats

- **Bus stop codes are hardcoded** — the spec lists `Stop 84009` (Blk 416) and uses "Bedok Town Park" (mapped to `84029` as a best guess). The Home screen will show whatever services LTA actually returns for those codes; if the codes are wrong for current operations the cards will be empty and you'll see "Demo data".
- **No location services** — the spec called for hardcoded "near Bedok" data; we honor that. The onboarding location permission card is a visual mock.
- **No real-time MRT arrival data** in the station detail — LTA doesn't expose this publicly; the 2 / 5 · 9 minute values are static.

## Built without

Tests, CI, fastlane, Firebase, analytics, third-party SDKs.

## What I couldn't replicate exactly from the prototype

- The HTML prototype runs in a fixed `390 × 844` "device frame" with a faux notch and status bar. The native app uses the real iOS chrome — your actual notch, your actual battery icon, your actual time. SwiftUI's TabView renders the bottom tab bar slightly differently from the CSS `.tab-bar` (item label sizes, blur effect) — close but not pixel-identical.
- The HTML maps are pure CSS shapes. Native versions are SwiftUI shapes inside a GeometryReader. The "road" lines are drawn correctly but the bus/stop marker positions are percentage-based and may look slightly different at non-iPhone-15 sizes.
- The HTML alert dot on the bell tab uses a custom CSS pseudo-element. The native version uses SwiftUI's `.badge(1)`, which renders a numeric "1" rather than a plain dot. Close enough for spec purposes.
