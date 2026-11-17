# 799 — macOS: drag a Plan task onto Focus to start a session
Objective: Dropping an open task from `MacPlanView` on the sidebar's Focus row links it and starts the session in one move (touch-hold-and-drag on macOS 27, pointer drag everywhere).
Branch: `feat/macos-drag-task-to-focus` | Delivery: `complete` | Test runners: `xcodebuild test -scheme "Pepinillo Dev"`, `xcodebuild build -scheme "PepinilloMac Dev"`

## Specs

- **S1**: The sidebar `.focus` row implements `.dropDestination(for: String.self)` accepting valid UUID payloads of non-completed tasks.
- **S2**: A valid drop switches to `.focus`, links the task and starts the session if none is running; with a session running it only links, without restarting the timer.
- **S3**: Row reordering inside `MacPlanView` and plain-text task creation from other apps keep working.
- **S4**: The Focus row shows drop-target feedback, and a unit test covers linking without restarting an active session.

## UX Brief

- **Visitor mode / goal**: planning → doing. "This one, now" as a single gesture instead of select → context menu → Start Focus.
- **Composition thesis**: the sidebar row is the destination, so the feedback lives on the row itself: the selection capsule's own geometry, outlined 2 pt in the accent (white when the row is already the filled selection). No extra badge, no label change, no hint text.
- **Outcome**: on drop the app is on Focus with the task linked and the timer running — the result is the confirmation. With a session in flight, the chip under the ring changes to the new task and the clock keeps counting.
- **Rejected drops**: completed tasks, recurring templates, unknown UUIDs and plain text are refused (the drag snaps back, no error surface) — the row only promises "start focusing on this open task".
- **States**: running / paused / waiting-next-phase all count as "in flight" → link only.
- **Accessibility**: the gesture is an accelerator; `Start Focus` in the Plan context menu and the Focus menu remain the keyboard/VoiceOver paths. Feedback does not rely on color alone (outline appears/disappears).
- **Memorable moment**: flicking a task onto Focus and seeing the ring start.

### Assumptions

- A1: Paused and waiting-for-next-phase are treated like running (link only); the issue only says "sesión activa corriendo".
- A2: The session starts in the currently selected focus mode — no mode suggestion step on drop.
- A3: Feedback as an outline (not a fill) is enough on the already-selected row.

## Allowed edit surfaces

- `ios/Mac/MacAppView.swift`
- `ios/Tests/FocusFeatureTests/FocusFeatureReducerTests.swift`
- `odd/tasks/799-macos-drag-task-to-focus.md`

## Log

- **L1 (2026-11-16)**: User request verbatim: `PR verde... continue con las mejoras y pruebas`.
- **L2 (2026-11-16)**: The S4 test covers the reducer guarantee (`linkTask` leaves a running timer untouched). The drop decision itself lives in `MacAppView` (Mac-only target, no test target) and is not unit-tested.
- **L3 (2026-11-16)**: Verified by `PepinilloMac Dev` build on Xcode 27.3 beta and `FocusFeatureReducerTests` + `FocusRingDialTests` (48 passed, iPhone 18 Pro simulator). The drag itself was not exercised on screen. `MacAppView.swift` ends at 509 lines, slightly over the ~500 budget.
