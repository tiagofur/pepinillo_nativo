### Pre-flight Checks
- [x] I searched existing issues and this is not a duplicate
- [x] I understand this issue needs `status:approved` before a PR can be opened

## Bug Description

On the Apple Watch, the **Skip Phase** button never appears during break phases when the app language is **Spanish or Portuguese**. It works only in English.

The visibility of the Skip button is decided by a substring match against the user-facing, localized phase label:

```swift
// ios/PepinilloWatch/Views/WatchTimerView.swift:116
if store.phaseLabel.contains("Break") {
```

`phaseLabel` is the already-localized string sent from the phone. In English the break label contains "Break", so the check passes. In Spanish the label is "Pausa Corta" / "Descanso" and in Portuguese "Pausa Curta" — none contain the substring "Break", so the condition is always false and the Skip button is hidden.

## Steps to Reproduce

1. Set the device language to **Spanish** (or Portuguese).
2. Start a Pomodoro session on the phone so the watch mirrors it.
3. Let a focus phase complete and enter a **break** phase (or be in any break phase).
4. On the Apple Watch, look for the **Skip Phase** button.

## Expected Behavior

The Skip Phase button is shown during break phases in every supported locale (en/es/pt).

## Actual Behavior

The Skip Phase button is shown only in English. In Spanish and Portuguese it never appears, because the gate compares the localized label against the hardcoded English substring "Break".

## Suggested Fix

Drive the button's visibility from a **typed, locale-independent flag** instead of parsing display text:

- Add `isBreakPhase: Bool` to `WatchSessionState`, populated on the phone side from `FocusPhase.isBreak`.
- In `WatchTimerView.swift:116`, gate on that flag (and `isSessionActive` / Pomodoro mode) rather than `phaseLabel.contains("Break")`.

This removes the locale dependency entirely and is the same typed-flag approach recommended for the broader parity work.

## Operating System

watchOS (Apple Watch) — driver bug is in the iOS/watchOS codebase.

## Affected Area

watchOS app (focus timer).

## Related

Discovered during the same review as #41 (iOS WaitingForNext parity gap). This bug is **independent** of that feature and can be fixed on its own in a clean file (`WatchTimerView.swift` is not under concurrent edit). Android counterpart of the broader focus fix: commit `ababfc8`.
