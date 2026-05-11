# CommuteWidget — Setup

The Swift files in this folder make up a Widget Extension target containing
two widgets and one Live Activity. The target itself has to be added through
Xcode (Xcode generates project metadata that's not safe to hand-edit). One-time
steps:

## 1. Create the widget extension target

In Xcode:

1. **File → New → Target → Widget Extension** (under iOS).
2. **Product Name:** `CommuteWidget`.
3. **Bundle Identifier:** `com.rommelsim.commute.CommuteWidget` (must be a child of the main app's bundle ID).
4. **Include Live Activity:** ☑️ ON.
5. **Include Configuration Intent:** OFF (we don't use one).
6. When prompted to activate the new scheme — click **Activate**.

Xcode generates default widget files. **Delete** them all from the new
`CommuteWidget` group (move to trash):
- `CommuteWidget.swift`
- `CommuteWidgetBundle.swift`
- `CommuteWidgetLiveActivity.swift`
- `CommuteWidgetControl.swift`
- `AppIntent.swift`
- the auto-generated `Assets.xcassets` (or keep, your call)

## 2. Drop in the real files

In Finder, this folder already has the right Swift files:
- `CommuteWidgetBundle.swift`
- `QuickActionsWidget.swift`
- `MRTStatusWidget.swift`
- `BusTrackingLiveActivity.swift`
- `Info.plist`

In Xcode, drag the four Swift files into the `CommuteWidget` group. In the
"Add files" prompt, **only** check the `CommuteWidget` target (not the main
`Commute` target).

For the `Info.plist` either replace the auto-generated one with this file
or merge the keys (`APP_GROUP_ID` is the only addition).

## 3. Add the shared files to **both** targets

These files live in `Commute/` (main app) but the widget extension also
needs to compile them. Open each, then in the **File Inspector → Target
Membership** check both `Commute` and `CommuteWidget`:

- `Commute/Models/BusTrackingActivity.swift` — required for the Live Activity.
- `Commute/Services/SharedSnapshot.swift` — required for the MRT Status widget.

## 4. Set the deployment target

Select the `CommuteWidget` target → General → **Minimum Deployments** →
iOS 17.0. (Anything ≥ 16.2 works for ActivityKit, but Dynamic Island wants 17+.)

## 5. App Groups capability

The MRT Status widget reads a snapshot from a shared App Group. Add the
capability to **both** targets:

1. Select `Commute` → **Signing & Capabilities** → **+ Capability** → **App Groups**.
2. Click **+** under the App Groups list, add `group.com.rommelsim.commute`.
3. Repeat on the `CommuteWidget` target with the **same** group ID.

If you use a different ID, set `APP_GROUP_ID` in both Info.plists to match.

## 6. Deep links (optional but expected by Quick Actions widget)

The Quick Actions widget opens URLs like `commute://plan`. The main app needs
to declare and handle the scheme:

1. Main app target → **Info** tab → **URL Types** → **+** → URL Schemes: `commute`.
2. In `CommuteApp.swift`, handle `.onOpenURL { url in ... }` to switch to the
   matching tab. (Wire this up when you want the widget tiles to actually open
   a specific tab.)

## 7. Build & run

- Build the `Commute` scheme (main app) — installs the app, the widget
  extension, and registers the Live Activity attribute.
- On the simulator's Home Screen: long-press → **Edit** → **Add Widget** →
  search "Commute" → pick **Quick actions** or **MRT line status**.
- For the Live Activity: open Bus tracking in the app, toggle **"Track on
  Lock Screen"** ON, lock the simulator (`⌘ + L`), wait for the Lock Screen
  card to appear. On a device with Dynamic Island, the compact / expanded
  presentations show automatically.

## What lives where

| File | Target |
|---|---|
| `CommuteWidgetBundle.swift` | `CommuteWidget` only |
| `QuickActionsWidget.swift` | `CommuteWidget` only |
| `MRTStatusWidget.swift` | `CommuteWidget` only |
| `BusTrackingLiveActivity.swift` | `CommuteWidget` only |
| `Info.plist` | `CommuteWidget` only |
| `Commute/Models/BusTrackingActivity.swift` | **Both** |
| `Commute/Services/SharedSnapshot.swift` | **Both** |
| `Commute/Services/LiveActivityManager.swift` | `Commute` only |
