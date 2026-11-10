# iOS port candidates — from the macOS v1 work

Date: 2026-10-23. Trigger: after landing T21–T23 on macOS, the question was
what from that work makes sense on iPhone/iPad. Decision: **plan only** —
actionable candidates are filed as issues; nothing is scheduled.

## 1. Already on iOS for free (no work needed)

The recent Mac passes were built cross-platform from the start, so iOS
already received them through the shared PRs (#664/#666/#667):

- **"+5 min" notification action (T21)** — `EXTEND_SESSION` category,
  `NotificationDelegate` mapping, and the `AppFeature` bridge are shared code;
  iOS compiles them today.
- **Completion sounds + picker (T23c)** — `CompletionSound` lives in
  `Shared/Design`, the .caf clips in `Shared/Sounds`, and the picker is
  already in the iOS `SettingsView`; iOS plays them through the same
  `HapticManager` path.
- **Spotlight task indexing** — pre-existing on iOS (`SpotlightClient`);
  the Mac indexer (T14) was the port *of* this feature, not the reverse.
- **Dashboard periods (7D/30D/Year)** — shared `AnalyticsFeature` periods
  already drive the iPhone Dashboard picker.
- **Presence surfaces** — iOS already has the equivalents that macOS had to
  build: widgets, Live Activity / Dynamic Island, Control Center controls.

## 2. Actionable candidates (filed as issues)

### #669 — Share Extension "Add Task to Pepinillo" (medium, priority:medium)

The one true gap. macOS v1 shipped capture-from-anywhere (Services menu T12,
global Quick Capture ⌃⌥T T13); iOS has no Share Extension target at all
(verified in `project.yml`: widgets, watch, ControlCenter only). Capture is
the activation loop. Implementation sketch: new app-extension target,
Quick-Capture-style minimal UI over `public.plain-text` + `public.url`, and
process handoff through the existing `AppGroupDefaults` external-command
queue that widgets already use (enqueue in the extension, drain on app
activation). Free tier — not a Pro feature.

### #670 — iPad hardware-keyboard shortcut parity (small, priority:low)

iPad + hardware keyboard is a first-class surface, but only `space` and `⌘.`
exist in `FocusView`. Port the rest of the Mac set declaratively
(`⌘→` skip/next-phase, `⌘⌥1–4` modes with the existing Pro gate, `⌘N` new
task); `.keyboardShortcut` surfaces them in the iPadOS ⌘-overlay with no
extra UI. Keep semantics identical to the Mac menu.

Recommended order if both are picked up: #670 first (half-day warm-up),
then #669 as the headline unit of the next cycle.

## 3. Explicitly not porting (and why)

- **Top activity statistics (T22)** — iOS exposes no public API for the
  frontmost app (sandbox). A distant alternative is the Screen Time /
  `DeviceActivity` stack (FamilyControls entitlement, heavy, very
  privacy-sensitive): documented here as "not now", revisit only with
  evidence users want app-level focus insights on iPhone.
- **Menu bar status styles (T23b)** — no menu bar on iOS; the Dynamic Island
  Live Activity is already the minimal presentation by design. Not inventing
  a cosmetic Pro surface on iOS for parity's sake.
- **Dock progress arc / badge (T12/T14)** — on iOS the same job is done by
  Live Activity + lock-screen widget + watch complications, which predate
  the Mac work.
- **Notch notification mirroring** — boring.notch is a macOS-only concept;
  iOS notifications already render system-wide (that was the point of the
  research: standard `UNUserNotification` is the portable part, and T21
  already rode it).
