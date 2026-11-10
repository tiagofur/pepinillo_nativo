# macOS research: notch notifications + top-activity tracking

> STATUS 2026-10-22: implemented. Notch side required no code (boring.notch
> mirrors our standard notifications); the "+5 min" action shipped as T21
> (`feat/notification-extend-action`, PR #664). Top activity shipped as T22
> (`feat/macos-top-activity`) with one deviation from the plan below: the
> persistence chose a local JSON daily rollup (mac-shell file, no schema
> migration) over a per-session `FocusSessionRecord` column — see
> `odd/tasks/macos-native-v1.md` L27-L28.

Date: 2026-10-22. Trigger: Kofe Flow shows its "Focus complete" alert inside the
notch (user has boring.notch installed) and a "TOP ACTIVITY" row of app icons in
its usage statistics. Two questions: (1) how does an app get its notification
into the notch, (2) how do these apps know which app is being used.

## 1. Notifications in the notch (boring.notch mirroring)

**Answer: Kofe Flow does nothing notch-specific.** boring.notch ≥ **v2.8-rc.0**
("Dapper Crab", 2026-09-23) mirrors *any* app's standard macOS user
notifications into the notch. Release notes: "Mirrors visible notification
banners in the notch with the sending application's icon", with app filtering,
a notification queue, and a closed-notch activity indicator.

Implementation (repo `TheBoredTeam/boring.notch`, tag v2.8-rc.2):

- `Shared/NotificationPanelDetection.swift` — detects Notification Center
  banners through the **Accessibility API**: it watches the Notification Center
  process and matches AX subroles (`AXNotificationCenterBanner`,
  `AXNotificationCenterAlert`, `AXNotificationCenterPanel`, …) plus structural
  AX events (`AXWindowCreated`, `AXChildrenChanged`, …). No public macOS API
  exposes other apps' notifications; AX scraping of Notification Center is the
  technique.
- `BoringNotchXPCHelper/NotificationWatcher.swift` — the AX watcher runs in a
  separate privileged/XPC helper ("banner discovery, XPC delivery" in release
  notes).
- `boringNotch/managers/SystemNotificationManager.swift` — mirrors
  `{appName, bundleID, title, subtitle, body}` into the notch UI with an 8 s
  display window and a queue of 5.
- boring.notch (the listener) is the side that needs Accessibility permission.
  The **sending app needs nothing special** — a plain `UNUserNotificationCenter`
  notification.

**Implication for Pepinillo:** already done. `NotificationClient.registerCategories()`
(called from both `PepinilloApp.swift` and `PepinilloMacApp.swift`) registers
action categories (`SESSION_COMPLETE` → "Start Break Timer"/"End Session",
`BREAK_END` → "Start Session", …). Our "focus complete" notifications will be
mirrored by boring.notch ≥ v2.8 exactly like Kofe Flow's. Without boring.notch
they render as regular system banners. Follow-ups worth considering:

- Add a `+5 min` style extend action to the session-complete category for
  parity with Kofe Flow's alert (needs a small reducer action wired to the
  notification-action delegate).
- Do NOT invest in custom notch drawing: the notch is not programmatically
  accessible; every notch app either draws over that screen area with a
  borderless `NSWindow` (NotchDrop-style) or, like boring.notch, mirrors
  system state. Mirroring already covers us for free.

## 2. Detecting the app in use (top activity statistics)

Kofe Flow's stats ("focus hours, streaks, top apps, and websites from your
sessions", kofeflow.com) are built on foreground-app detection. On macOS there
are two standard approaches, both permission-free at the app-name level:

1. **`NSWorkspace.shared.frontmostApplication`** → `NSRunningApplication`
   (`bundleIdentifier`, `localizedName`, `icon`). Poll on a timer (1 Hz is the
   usual granularity, same cadence as our `MacStatusBarController` sampler) or
   subscribe to `NSWorkspace.didActivateApplicationNotification` (event-driven,
   but misses "user went idle / stopped switching" so polling gives dwell time).
   No permission prompt for name/bundle ID of `.regular` apps.
2. **`CGWindowListCopyWindowInfo`** (ActivityWatch's aw-watcher-window approach):
   frontmost window = lowest `kCGWindowLayer == 0`, read `kCGWindowOwnerName` +
   `kCGWindowOwnerPID`. Window *titles* (`kCGWindowName`) require Screen
   Recording permission on ≥ 10.15 — avoid for v1.

Websites (browser URL/tab) need per-browser AppleScript or Accessibility
reading of the URL bar — out of scope for v1; app-level tracking covers the
"TOP ACTIVITY" icon row in Kofe Flow's screenshot.

### Implementation plan for Pepinillo macOS (proposed, not yet built)

- New `MacActivitySampler` (mirrors the `MacStatusBarController` 1 Hz pattern):
  started/stopped with focus sessions, accumulates
  `[bundleIdentifier: seconds]` in memory; on session end persists a per-session
  aggregate (new SwiftData model or a codified field on the session), keeping
  only bundle ID + seconds — no window titles, local-only like Kofe Flow.
- Icon resolution for non-running apps:
  `NSWorkspace.shared.urlForApplication(withBundleIdentifier:)` +
  `NSWorkspace.shared.icon(forFile:)`.
- UI: "Top activity" HStack of app icons in `MacStatisticsView.summaryHeader`,
  fed by a new `AnalyticsFeature` derived state (top N bundle IDs by seconds in
  the selected period); en/es/pt strings in `Localizable.xcstrings`.
- Settings toggle (opt-in, default on during sessions only) in
  `MacSettingsView` — matches Kofe Flow's "app names remain local" privacy
  stance and our PRD privacy bar.

## Sources

- boring.notch repo: https://github.com/TheBoredTeam/boring.notch (tag v2.8-rc.2)
- boring.notch v2.8-rc.0 release notes (Notification Mirroring section)
- Kofe Flow: https://www.kofeflow.com (local-only top apps + websites claim)
- ActivityWatch window watcher (CGWindowList approach): aw-watcher-window
