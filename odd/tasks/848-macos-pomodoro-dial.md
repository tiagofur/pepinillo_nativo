# 848 — macOS touch dial on Pomodoro (rest of #797 S1)
Objective: The focus-ring rotary dial answers in Pomodoro mode too (5…120, same kitchen-timer gain), with the ±5 steppers as its non-gesture twin on Mac and iOS, sharing the Time Block dial's in-memory next-session semantics.
Branch: `feat/macos-pomodoro-dial` (worktree, off origin/main `59448f31`) | Delivery: `complete` | Test runners: `xcodebuild test -scheme "Pepinillo Dev"`, `xcodebuild build -scheme "PepinilloMac Dev"` (Xcode-beta)

## Specs

- **S1**: Idle in Pomodoro, the direct-touch dial adjusts the work length in 5 min steps within `5...120` (same 1 turn = 60 min gain, wrap-safe), updating the idle display; Flowtime/Stopwatch stay inert; mouse/trackpad unchanged.
- **S2**: The ±5 steppers flank Start in Pomodoro on Mac (`MacFocusView`) and iOS (`FocusView`) with per-mode bounds (TimeBlock 5…480 / Pomodoro 5…120), keeping the gesture-twin a11y story.
- **S3**: Reducer tests cover clamping, start-uses-dialled-duration, and the documented ephemerality (`configUpdated` hydration overwrites the dialled value).

## UX Brief

Published as an issue comment before implementation: https://github.com/tiagofur/pepinillo_nativo/issues/848#issuecomment-6933544190

### Assumptions

- A1: **Ephemeral semantics** (in-memory next-session override, Settings hydration overwrites on relaunch/settings-save) — mirrors the shipped Time Block dial exactly. Pending explicit confirmation from Tiago; a persistent variant would need a focus→settings forward + autosave debounce (a write per 5-min detent) and would diverge from Time Block.
- A2: Steppers extend to Pomodoro on both Mac and iOS (engine parity invariant); no watch change (no duration UI exists there).
- A3: No new user-facing strings — steppers keep their existing labels.

## Allowed edit surfaces

- `ios/Features/Focus/FocusFeature.swift` (new action + reducer case)
- `ios/Mac/MacFocusRingTouch.swift`
- `ios/Mac/MacFocusView.swift`
- `ios/Features/Focus/FocusView.swift` (iOS stepper twin — parity)
- `ios/Tests/FocusFeatureTests/FocusFeatureReducerTests.swift`
- `odd/tasks/848-macos-pomodoro-dial.md`

## Tasks

- [x] **T1** (`S3`, risk: `V1`): `pomodoroDurationChanged` action + reducer case (clamp 5…120, `config.pomodoroDuration`, `updateIdleDisplay`) — tests first in the batch.
- [x] **T2** (`S1`, risk: `V1`): per-mode `DialTarget` in `MacFocusRingTouch` (range/base/action per mode).
- [x] **T3** (`S2`, risk: `V1`): steppers twin on Mac + iOS with per-mode bounds/action.

## Log

- **L1 (2026-11-17)**: Issue #848 created from #797 L2 (S1 partial). UX brief published (A1 ephemeral chosen unattended — reversible; Tiago did not answer the A/B question before execution).
- **L2 (2026-11-17)**: Implemented in isolated worktree `../pepinillo-848` off origin/main (the main checkout carries unrelated soundscape WIP from a parallel session). Tests were written against the new action in the same batch as the reducer case (compile-gated RED).
- **L3 (2026-11-17)**: Budget note: `FocusFeature.swift` (~1500) and `FocusView.swift` (~950) already exceed the ~500-line budget; the additions are a reducer case and a stepper seam that cannot live outside their features. No new monolith growth beyond ~15 lines each.
- **L4 (2026-11-17)**: Verified: `Pepinillo Dev` tests (iPhone 18 Pro simulator) + `PepinilloMac Dev` build on Xcode 27.3 beta. Real-touch pass (dial with a finger) pending labs 18-19 nov.
