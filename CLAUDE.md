# Build TransitSG — Native iOS App

Build a native SwiftUI iOS app for Singapore public transport called **TransitSG**, based on the interactive HTML prototype in `prototype/index.html`. The prototype is the source of truth for visual design, screen layouts, navigation flows, and interaction patterns.

## Project setup

Create a new Xcode project:
- **Name:** TransitSG
- **Interface:** SwiftUI
- **Language:** Swift
- **Minimum deployment:** iOS 17.0
- **Bundle ID:** com.example.transitsg
- **Orientation:** Portrait only

Use Swift Package Manager for any dependencies. Do not add Firebase, analytics, or third-party SDKs unless I ask for them.

## Architecture

Use a clean, minimal MVVM structure. No external state libraries — `@Observable` (iOS 17+) and `@State` are sufficient.

```
TransitSG/
├── TransitSGApp.swift            # @main entry, sets up RootView
├── Models/
│   ├── BusStop.swift
│   ├── BusArrival.swift
│   ├── MRTStation.swift
│   ├── JourneyOption.swift
│   ├── Alert.swift
│   └── SavedPlace.swift
├── ViewModels/
│   ├── HomeViewModel.swift
│   ├── PlanViewModel.swift
│   ├── FaresViewModel.swift
│   ├── AlertsViewModel.swift
│   └── AppState.swift            # global app state (theme, onboarding, saved places)
├── Views/
│   ├── RootView.swift            # decides onboarding vs main tab
│   ├── MainTabView.swift         # the 4-tab bar
│   ├── Onboarding/
│   │   ├── OnboardingFlowView.swift
│   │   ├── WelcomeStepView.swift
│   │   ├── LocationStepView.swift
│   │   └── PlacesStepView.swift
│   ├── Home/
│   │   ├── HomeView.swift
│   │   ├── ShortcutCard.swift
│   │   ├── NearbyBusStopCard.swift
│   │   └── NearbyMRTCard.swift
│   ├── Plan/
│   │   ├── PlanView.swift
│   │   └── JourneyOptionCard.swift
│   ├── Fares/
│   │   └── FaresView.swift
│   ├── Alerts/
│   │   ├── AlertsView.swift
│   │   └── AlertCard.swift
│   ├── Detail/
│   │   ├── BusStopDetailView.swift
│   │   ├── MRTStationDetailView.swift
│   │   ├── LiveTrackingView.swift
│   │   └── ProfileView.swift
│   └── Components/
│       ├── LineBadge.swift       # colored MRT line badges (EW, NS, etc.)
│       ├── ArrivalPill.swift     # the green/grey arrival time chips
│       ├── CrowdIndicator.swift  # 3-bar crowd gauge
│       ├── FilterPills.swift     # horizontal scrolling filter chips
│       └── SectionLabel.swift    # uppercase section headers in Profile
├── DesignSystem/
│   ├── Colors.swift              # semantic color tokens, light + dark
│   ├── Typography.swift
│   └── Spacing.swift
├── Services/
│   └── MockDataService.swift     # returns the same mock data shown in the prototype
└── Assets.xcassets/
    ├── AppIcon.appiconset
    └── AccentColor.colorset
```

## Design system

Match the prototype exactly. The HTML uses CSS variables for theming — translate these to a `Color` extension that switches on color scheme:

**Light mode:**
- Background: `#F1EFE8` (page) / `#FFFFFF` (surface)
- Text: `#1A1A1C` primary / `#5F5E5A` secondary / `#888780` tertiary
- Info (primary action): `#185FA5` / bg `#E6F1FB`
- Success: `#3B6D11` / bg `#EAF3DE`
- Warning: `#854F0B` / bg `#FAEEDA`
- Danger: `#A32D2D` / bg `#FCEBEB`
- Purple (Work shortcut): `#534AB7` / bg `#EEEDFE`
- Border: `rgba(0,0,0,0.08)`

**Dark mode:**
- Background: `#050507` / surface `#0F0F11` / surface-2 `#1A1A1C`
- Text: `#F1EFE8` / `#B4B2A9` / `#888780`
- Info: `#85B7EB` / bg `#042C53`
- Success: `#97C459` / bg `#173404`
- Warning: `#EF9F27` / bg `#412402`
- Danger: `#F09595` / bg `#501313`
- Purple: `#AFA9EC` / bg `#26215C`
- Border: `rgba(255,255,255,0.08)`

**MRT line colors** (use these official LTA colors for `LineBadge`):
- East-West (EW): `#009645`
- North-South (NS): `#D42E12`
- North-East (NE): `#9900AA`
- Circle (CC): `#FA9E0D` with text `#4A1B0C`
- Downtown (DT): `#005EC4`
- Thomson-East Coast (TE): `#9D5918`
- Changi Extension (CE): `#FA9E0D` with text `#4A1B0C`

**Typography:** SF Pro (system default).
- Title: 26pt, semibold, -0.5 letter-spacing
- Section heading: 15pt, semibold
- Body: 14pt, regular
- Card title: 14pt, semibold
- Meta/caption: 12pt, regular

**Spacing:** 20pt horizontal padding for screens, 10–14pt internal card padding, 8–12pt between cards.

**Corner radius:** 10pt for cards/buttons, 16pt for large surfaces.

## Screens to build

All 9 screens from the prototype — match the layouts and contents exactly:

1. **Onboarding step 1 — Welcome**: hero icon, app name, 4 feature bullets, "Get started" button
2. **Onboarding step 2 — Location**: hero, fake iOS permission card with 3 buttons (Allow once / While using / Don't allow), Skip link
3. **Onboarding step 3 — Save places**: pre-filled Home (highlighted), empty Work card, "Add another place" dashed card, notifications toggle, "Start using TransitSG" CTA
4. **Home**: greeting + avatar (tap → Profile), search bar, Home/Work shortcuts, "Near you" section with bus stop and MRT cards
5. **Plan journey**: from/to stack, filter pills (Fastest/Cheapest/Less walk), 3 route cards (one highlighted as "Best")
6. **Fares**: MRT/Bus mode toggle, from/to with line badges, card-type pills (Adult/Senior/Student/Child), big result tile, breakdown card, early-bird tip card
7. **Alerts**: filter pills (All/MRT/Bus/For you), 4 alert cards (danger/warning/info/success)
8. **Bus stop details**: stop name + code header, mini map placeholder, filter pills, list of bus services with arrival pills and crowd info
9. **MRT station details**: line badge + name header, line status banner, 4-station horizontal line map with interchange marker, train arrivals card, exit grid (4 exits), amenities list
10. **Live tracking**: bus number header, animated map with pulse, big ETA card, bus details (type/operator/crowd), upcoming stops timeline
11. **Profile**: user card, Saved places group, Preferences group (with theme toggle that actually works and notifications toggle), About group with "Replay onboarding" link

## Navigation flows

Use `NavigationStack` (NOT `NavigationView`). Each tab gets its own `NavigationStack`. Cross-tab navigation flows should use `selectedTab` binding on `MainTabView`.

**Flows to implement:**
- App launch → if onboarding incomplete (stored in `@AppStorage`), show `OnboardingFlowView`; else `MainTabView`
- Home → tap bus stop card → push `BusStopDetailView`
- Home → tap MRT card → push `MRTStationDetailView`
- Home → tap avatar → push `ProfileView`
- Home → tap shortcut or search → switch to Plan tab
- Bus stop detail → tap a bus row → push `LiveTrackingView`
- Plan → tap a route card → push `LiveTrackingView`
- Profile → "Replay onboarding" → reset `@AppStorage` flag and present `OnboardingFlowView` as a sheet
- Bottom tab bar visible on all 4 main screens, hidden on detail screens (use `.toolbar(.hidden, for: .tabBar)`)
- Swipe-from-left-edge back gesture works automatically with `NavigationStack`

## Interactive behaviors

- **Theme:** Default to system (`.preferredColorScheme(nil)`). Profile toggle cycles through System / Light / Dark, stored in `@AppStorage("colorScheme")`. Apply via `.preferredColorScheme(...)` on `RootView`.
- **Live ETA countdown:** On `LiveTrackingView`, the ETA decrements every second using a `Timer.publish` that drives `@State`. Loop back to 3 minutes when it hits 1.
- **Map pulse animation:** On the live tracking map, the bus marker has an outward-radiating ring that animates `scale(1 → 2.5)` and `opacity(0.6 → 0)` over 2s, repeating forever. Use `.repeatForever(autoreverses: false)`.
- **Filter pills:** Tapping a pill in any pill group sets it active and deactivates the others. Visual only — no actual filtering needed.
- **Fare calculator:** Tapping Adult/Senior/Student/Child updates the displayed fare using these values: Adult $1.89, Senior $0.81, Student $0.55, Child $0.55. Use a smooth `.animation(.snappy)` on the change.
- **Search bar / shortcut tap:** Switch tab to Plan (via `selectedTab` binding).
- **Saved places & favourites:** Track in `AppState`, persist with `@AppStorage` using JSON encoding.
- **Status bar time:** SwiftUI's status bar shows real time automatically — don't fake it like the HTML.

## Mock data

Hardcode the data shown in the prototype. `MockDataService` returns:

- **Nearby bus stops:** "Blk 416" (Stop 84009, 80m, buses 2/5/14), "Bedok Town Park" (220m, buses 15/22)
- **Nearby MRT:** "Bedok" EW5 (340m, normal status)
- **Bus 14 live tracking:** Double-deck, SBS Transit, "Seats" crowd, next stops: Bedok Sth Ave 3 (3 min), Tanah Merah (7 min), Simei (12 min), Tampines (18 min)
- **Plan results (Bedok MRT → Marina Bay Sands):** 28 min / $1.89 / Best (EW→CE), 34 min / $1.69 (Bus 12 → EW), 41 min / $1.45 (Bus 36)
- **Bedok station exits:** A (Bedok Mall, Lift+Escalator), B (Bus Int., Lift+Stairs), C (Heartbeat, Escalator), D (Bedok Pl., Stairs only)
- **Bedok station next stations westbound:** Bedok EW5 (current), Kembangan EW6, Eunos EW7, Paya Lebar EW8/CC9 (interchange)
- **Train arrivals:** Next 2 min, Following 5 min · 9 min
- **Alerts (4):**
  - DANGER · "East-West Line" · "Delays of up to 15 min between Bugis and Tanah Merah. Service recovery in progress." · Now
  - WARNING · "Bus 14 detour" · "Diverted via Marine Parade Rd until 11pm tonight." · 12 min
  - INFO (For you) · "Free off-peak ride" · "Tap in before 7:30am tomorrow on the NEL for a free trip." · 2h ago
  - SUCCESS · "Circle Line lift at Bayfront restored." · 3h ago
- **User profile:** Name "Aisyah", "Adult · Joined Mar 2024"

## Components to nail

- **LineBadge:** rounded rect, 3pt vertical / 7pt horizontal padding, 4pt corner radius, 11pt semibold uppercase text. Takes a `MRTLine` enum that returns the right bg + text color.
- **CrowdIndicator:** 3 vertical bars (5×12pt, 2pt corner) where N bars are filled with the level color, rest are border-strong gray. Plus a label ("Seats" / "Standing" / "Limited").
- **ArrivalPill:** small rounded card showing minutes + secondary line. Variants: `urgent` (green bg, ≤3 min), `warning` (amber bg, standing-only), `default` (gray bg).
- **MRT line map (in MRTStationDetailView):** horizontal `HStack` with 4 `StationNode`s, a horizontal line drawn behind them using `ZStack { Rectangle().frame(height: 4) }` positioned at the same y as the markers. The interchange node is taller and rounded (14×22pt rounded rect) with a small Circle Line dot attached at the bottom.

## Quality bar

- **No print statements**, no commented-out code, no TODOs left in the final commit.
- All views must build without warnings.
- All copy is sentence case (never Title Case, never ALL CAPS except the section labels which use the same uppercase tracking as the prototype).
- Test in both light and dark mode at every step — both must look polished.
- Test on iPhone 15 simulator (390pt wide). The prototype is built for this exact viewport.
- All tappable elements need at least 44×44pt hit area.
- Use `.contentTransition(.numericText())` for the live ETA countdown to get the nice digit animation.
- Use SF Symbols where they map cleanly. The prototype uses Tabler Icons; here are direct SF Symbol replacements:
  - `ti-home` → `house.fill`
  - `ti-route` → `point.topleft.down.curvedto.point.bottomright.up`
  - `ti-calculator` → `function`
  - `ti-bell` → `bell.fill`
  - `ti-bus` → `bus.fill`
  - `ti-train` → `tram.fill`
  - `ti-search` → `magnifyingglass`
  - `ti-arrow-left` → `chevron.left`
  - `ti-chevron-right` → `chevron.right`
  - `ti-star` / `ti-star-filled` → `star` / `star.fill`
  - `ti-walk` → `figure.walk`
  - `ti-users` → `person.2.fill`
  - `ti-clock` → `clock.fill`
  - `ti-alert-circle` → `exclamationmark.triangle.fill`
  - `ti-info-circle` → `info.circle.fill`
  - `ti-circle-check` → `checkmark.circle.fill`
  - `ti-bulb` → `lightbulb.fill`
  - `ti-map-pin` → `mappin.circle.fill`
  - `ti-briefcase` → `briefcase.fill`
  - `ti-moon` → `moon.fill`
  - `ti-language` → `globe`

## Build steps

1. Read `prototype/index.html` end-to-end before writing code. Reference it whenever a layout question comes up.
2. Set up the project structure and design system (Colors, Typography) first.
3. Build leaf components (`LineBadge`, `CrowdIndicator`, `ArrivalPill`) before the screens that use them.
4. Build screens in this order: Home → Plan → Fares → Alerts → BusStopDetail → MRTStationDetail → LiveTracking → Profile → Onboarding.
5. Wire up `MainTabView` with all 4 tabs, then add navigation pushes.
6. Add `OnboardingFlowView` and `RootView` last.
7. Run on iPhone 15 simulator after each major step. Toggle dark mode (`Cmd+Shift+A`) and verify both modes.
8. Commit logical chunks: "Design system", "Home screen", "Plan + Fares", "Alerts", "Detail screens", "Onboarding", "Final polish".

## Final deliverable

A working Xcode project that:
- Launches into onboarding on first run
- After onboarding, shows Home with all data populated
- Lets me tap through every flow shown in the prototype
- Handles dark mode flawlessly
- Builds cleanly with zero warnings
- Has a brief `README.md` at the project root explaining how to run it

Don't add tests, CI, or fastlane — just the app itself.

When you're done, summarize what you built, anything you couldn't replicate exactly from the prototype, and any decisions you made independently.
