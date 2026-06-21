### Pre-flight Checks
- [x] I searched existing issues and this is not a duplicate
- [x] I understand this issue needs `status:approved` before a PR can be opened

## Bug Description

The "waiting for next phase" hold introduced for iOS in commit `805b4b1` (feat: respect auto-start settings) is **not reflected on the Apple Watch**. When `autoStartBreaks`/`autoStartWork` is OFF and the engine enters the hold, the phone UI correctly shows a "Start Break / Start Focus" CTA — but the watch shows a stale, misleading, and non-actionable screen.

Found during a dual blind adversarial review of `805b4b1`; **both reviewers independently flagged this same gap** as the only confirmed CRITICAL.

## Root Cause

- `WatchSessionState` (`ios/Domain/Clients/WatchConnectivityClient.swift`) has **no `isWaiting` field**, so the watch cannot tell a running session apart from a waiting hold.
- The factory `WatchSessionState.init(from:)` (`ios/App/AppFeature.swift` ~1246-1272) sets `isActive = focusState.isRunning` (stays `true` during the hold) and `isPaused = focusState.isPaused` (stays `false` because the reducer guards block `pauseTapped` during the hold). The watch therefore sees a live, unpaused session.
- There is **no watch sync trigger** on the `.waitingForNextPhase` event. `AppFeature` only pushes watch state on `.timerTicked`, `.phaseCompleted`, `.pauseTapped`, `.resumeTapped`, `.stopTapped`, `.sessionCompleted`. Since the tick loop is suspended during the hold, the watch receives **no update at all** when the hold begins.

## Steps to Reproduce

1. On iPhone, disable "auto-start breaks" in Settings.
2. Start a Pomodoro session so the Apple Watch mirrors it.
3. Let a focus phase complete so the engine enters the waiting hold.
4. Look at the Apple Watch.

## Expected Behavior

The watch reflects the hold: hide/disable Pause/Resume, show a phase-aware **"Start Break" / "Start Long Break" / "Start Focus"** CTA that calls `startNextPhase()`, and indicate the pending phase (mirroring the Android Wear `WaitingForNextLayout`).

## Actual Behavior

- The watch shows the active-session view with a **live Pause/Resume button**.
- Tapping Pause sends `pauseSession` → the phone engine no-ops (guarded) but the watch plays a success haptic, falsely implying it worked.
- **No CTA exists** to start the next phase from the watch — the user is stuck.
- `displayTime` is frozen (no ticks during the hold) with an active-looking progress ring and no "waiting" indication.

## Suggested Fix

Mirror the typed-flag pattern already used for `isBreakPhase` (#42):

1. Add `isWaiting: Bool = false` to `WatchSessionState`; encode/decode it with a safe legacy default (`?? false`).
2. Populate it in `WatchSessionState.init(from:)` from `focusState.isWaitingForNextPhase`.
3. Add a `case .focus(.waitingForNextPhase):` handler in `AppFeature` that pushes fresh watch state (so the watch updates when the hold begins, despite no ticks).
4. In `WatchTimerView`, when `isWaiting`: suppress Pause/Resume and show a "Start …" CTA (phase-aware, using the existing `isBreakPhase`/`isLongBreakPhase` flags from #42) that sends a start command resolving to `startNextPhase()`.
5. Guard `pauseResumeTapped` in `WatchTimerFeature` against `isWaiting`.

## Operating System

watchOS (Apple Watch) — driver code is in the iOS/watchOS codebase.

## Affected Area

watchOS app (focus timer), WatchConnectivity bridge.

## Related

- Parity counterpart of #41 (iOS WaitingForNext feature) — the phone side is done; the watch side is missing.
- Builds directly on the typed-flag DTO pattern from #42 (`isBreakPhase`), same files.
- Android reference: Android Wear already has a dedicated `WaitingForNextLayout` with a phase-aware CTA (note: it currently shows "Start break" for long breaks too — a separate minor Wear parity gap noted in #41).
