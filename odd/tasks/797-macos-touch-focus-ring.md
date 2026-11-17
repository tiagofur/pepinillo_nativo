# 797 — macOS touch focus ring: rotary dial, tap to pause, pinch Zen
Objective: Turn the focus ring in `MacFocusView` into an expressive touch surface (rotary duration dial at rest, direct tap to pause/resume, two-finger pinch for a minimal Zen stage) without changing its default look or its pointer/trackpad behaviour.
Branch: `feat/macos-touch-focus-ring` | Delivery: `exception-ok` | Test runners: `xcodebuild test -scheme "Pepinillo Dev"`, `xcodebuild build -scheme "PepinilloMac Dev"`

## Specs

- **S1**: Idle, configurable modes: a direct-touch-only `DragGesture` on the ring band adjusts minutes in 5 min steps (`5...480` Time Block, `5...120` Pomodoro) without interfering with mouse/trackpad clicks.
- **S2**: Active session: a direct tap inside the ring runs `FocusToggleCommand.toggle(focusStore:)`.
- **S3**: Two-finger pinch (`MagnifyGesture`) on the Focus stage toggles Zen (hides `todayStats` and `linkedTaskChip`), on touch and trackpad, with an accessible equivalent in the `View` menu.
- **S4**: Respects `accessibilityReduceMotion`, keeps the 4 Hz clock render untouched, builds on macOS 15–26 (`#available`).

## UX Brief

- **Visitor mode / goal**: mid-ritual, eyes on the ring. Before a session: "set how long" without hunting for a control. During a session: "pause now" with the largest possible target. Any time: "strip the stage to the clock".
- **Composition thesis**: nothing new is drawn. The ring already is the object; the gestures only make it answer. No permanent chrome, no hint labels on the stage (exclusion in the issue). Discoverability comes from the existing ±5 steppers (dial) and the `View ▸ Zen Mode` menu item (pinch).
- **Dial (S1)**: clock-face metaphor — one full turn = 60 min, so each 30° detent = 5 min; clockwise adds, counter-clockwise subtracts. Relative, not absolute: the value never jumps to where the finger lands. The drag only arms when it starts on the ring band (outer ~30% of the radius), so the interior stays free. Value clamps silently at the range ends, mirroring the disabled steppers. The existing timer digits are the only feedback — they already re-render from `customDurationMinutes`.
- **Tap (S2)**: the whole ring interior is the target (far above 36 pt). Same decision table as the primary button (pause / resume / next phase), so the stage has one behaviour, two ways in.
- **Zen (S3)**: any deliberate pinch (scale delta ≥ 15%) toggles; the choice persists across launches. Zen removes the link-task chip and today stats; ring, phase label, primary action and session controls stay — a paused user must never be stranded without Stop.
- **States**: idle / running / paused / waiting-next-phase all keep their current visuals. Zen has no empty/error state. Without touch hardware S1/S2 are inert by construction (`inputKinds: .directTouch`).
- **Accessibility**: every gesture has a non-gesture twin — steppers (dial), primary button + Space (tap), `View ▸ Zen Mode` with ⌃⌘Z (pinch). Reduce Motion: Zen swaps without animation. VoiceOver reads nothing new on the ring; the menu item is a checkmark toggle.
- **Memorable moment**: turning the ring like a kitchen timer and watching the digits follow.

### Assumptions

- A1: One turn = 60 min is the right gain (480 min = 8 turns); not validated on hardware.
- A2: Toggle-on-any-pinch (not directional) matches "alterna" in S3.
- A3: ⌃⌘Z is free in the app and does not collide with system shortcuts.
- A4: Zen keeps the primary action and Stop visible; the issue only names `todayStats` and `linkedTaskChip`.

## Allowed edit surfaces

- `ios/Mac/MacFocusView.swift`
- `ios/Mac/MacFocusRingTouch.swift` (new: keeps `MacFocusView.swift` under the ~500 line file budget)
- `ios/Features/Focus/FocusRingDial.swift` (pure angle→minutes helper; new file instead of growing the 1149-line `FocusView.swift`)
- `ios/App/MacCommands.swift` (the issue lists `ios/Mac/MacCommands.swift`; the file lives under `App/`)
- `ios/Shared/Resources/Localizable.xcstrings`
- `ios/Tests/FocusFeatureTests/FocusRingDialTests.swift`
- `odd/tasks/797-macos-touch-focus-ring.md`

## Tasks

- [x] **T1** (`S1`, risk: `V1`): `FocusRingDial` pure helper + `FocusRingDialTests` (RED → GREEN).
- [x] **T2** (`S1, S2, S4`, risk: `V1`): direct-touch dial and tap overlay on the ring in `MacFocusView`, gated `#available(macOS 27.0, *)`.
- [x] **T3** (`S3, S4`, risk: `V1`): pinch Zen + `View ▸ Zen Mode` command + EN/ES/PT strings.

## Log

- **L1 (2026-11-16)**: User request verbatim: `Sí, implementa #797`.
- **L2 (2026-11-16)**: S1 Pomodoro range is NOT implementable inside the allowed surfaces: `FocusFeature` exposes `customDurationChanged` for Time Block only; the Pomodoro length is owned by `SettingsFeature.pomodoroDurationChanged` (persisted prefs) and `MacFocusView` only holds `StoreOf<FocusFeature>`. Delivered: Time Block dial. Pomodoro needs a surface expansion (`FocusFeature.swift` or `MacAppView.swift`) decided by leader.
- **L3 (2026-11-16)**: S1/S2 cannot be exercised on this machine (macOS 27.2.1, no touch panel); verified by `PepinilloMac Dev` build on Xcode 27.3 beta and `FocusRingDialTests` (10 passed, iPhone 18 Pro simulator). The stable Xcode 27.2 Debug build already fails on `main` (ActivityKit behind `MAC_LIVE_ACTIVITIES` is unavailable in the macOS 27.2 SDK) — unrelated to this change. Zen pinch / menu not exercised on screen. Pending Sidecar / hardware pass.
