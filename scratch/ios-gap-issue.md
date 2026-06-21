### Pre-flight Checks
- [x] I searched existing issues and this is not a duplicate
- [x] I understand this issue needs `status:approved` before a PR can be opened

## Summary

iOS/watchOS has **no `WaitingForNext` state** in the focus engine. The `autoStartBreaks` and `autoStartWork` toggles exposed in Settings are **dead code** — the engine always auto-advances through Pomodoro phases regardless of those settings. This is a **cross-platform parity gap**: Android supports a manual start between phases (the user taps to begin the break / next focus), iOS does not.

Discovered via a dual blind adversarial review ("Judgment Day") run after fixing the equivalent Android bug. Both reviewers confirmed the finding independently.

## Problem Description

- Users who turn **off** "auto-start breaks" or "auto-start next focus" in Settings expect a manual-start gate between phases. On iOS those toggles have **no effect** — the engine auto-advances every time.
- The capability the Android fix was about (a correctly-labeled "Start Break" / "Start Long Break" CTA when waiting for the next phase) **cannot exist on iOS** because the waiting moment is never surfaced to the UI.

### Root cause (file:line evidence)

- `ios/Features/Focus/Modes/PomodoroStrategy.swift:13` — `supportsAutoAdvance = true` is hardcoded.
- `ios/Features/Focus/FocusEngine.swift:438` — `phaseComplete()` calls `advancePhase()` whenever `strategy.supportsAutoAdvance` is true; it never consults `FocusConfig.autoStartBreaks` / `autoStartWork`.
- `ios/Features/Focus/FocusModels.swift:135-136` — `autoStartBreaks` / `autoStartWork` exist, are persisted, and flow into the engine via `FocusConfig`, but are never read.
- `ios/Features/Settings/SettingsFeature.swift:252-258` — the toggles are exposed to the user.

## Proposed Solution

Introduce a first-class "waiting for next phase" state in the iOS focus engine so the autoStart settings become operative and reach parity with Android:

1. Replace the per-strategy `supportsAutoAdvance` constant with a runtime decision, e.g. `shouldAutoAdvance(nextPhase:config:) -> Bool` that checks `config.autoStartBreaks` (when next is a break) and `config.autoStartWork` (when next is work).
2. When auto-start is disabled, park the engine in a waiting state that keeps the session alive (do **not** call `stop(completed:)` / tear down the Live Activity) and expose the **pending** next phase to the reducer.
3. Add a `pendingPhase` (or equivalent) field to `FocusFeature.State` and derive the CTA label from it: break → "Start Break" / "Start Long Break", work → "Start Focus". Today `ios/Features/Focus/FocusView.swift:587` hardcodes `"Start \(selectedMode.displayName)"` and would show the wrong label the moment manual-start exists.
4. Carry a typed `isBreakPhase: Bool` (and the pending-phase info) through `WatchSessionState` so the watch never parses locale-sensitive label text.

> ⚠️ `ios/Features/Focus/FocusFeature.swift` is currently under active edit by a concurrent session. This work touches that file — coordinate / wait before implementing. The engine, view, and watch files are otherwise clean.

## Related sub-issues uncovered in the same review

These can be split into their own issues if preferred:

- [ ] **Watch Skip button broken in es/pt (real bug, surgical, clean file)** — `ios/PepinilloWatch/Views/WatchTimerView.swift:116` decides whether to show the Skip button via `store.phaseLabel.contains("Break")`. In Spanish ("Pausa/Descanso") and Portuguese the substring is absent, so the Skip button **never appears** for those locales during break phases. Fix: drive it off a typed `isBreakPhase` flag, not the localized string. This is independent of the feature above and low-risk.
- [ ] **CTA / mode-name not localized** — `String(localized: "Start \(mode)")` at `ios/Features/Focus/FocusView.swift:587` and `ios/PepinilloWidget/FocusWidgetViews.swift:249` generate dynamic keys absent from `Localizable.xcstrings`, so es/pt users see "Start Pomodoro" untranslated.
- [ ] **Missing es/pt strings** in `ios/Shared/Resources/Localizable.xcstrings` for several analytics/streak keys; "Ready" is hardcoded in the widget idle layout.

## Acceptance Criteria

- [ ] Disabling "auto-start breaks" in Settings causes iOS to pause after a work phase and wait for the user to start the break.
- [ ] Disabling "auto-start next focus" causes iOS to pause after a break and wait for the user to start the next focus.
- [ ] The start CTA shows the correct phase-aware label ("Start Break" / "Start Long Break" / "Start Focus") in all three locales (en/es/pt).
- [ ] The Apple Watch Skip button appears during break phases in en/es/pt.
- [ ] Behavior matches Android's WaitingForNext flow.

## Affected Area

iOS app, watchOS app, Live Activity, focus widget.

## Platform parity reference

Android counterpart already fixed — see commit `ababfc8` (`fix(android): correct WaitingForNext CTA labels and complete focus i18n`).
