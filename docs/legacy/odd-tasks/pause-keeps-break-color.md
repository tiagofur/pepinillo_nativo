# Pause keeps break color — kill the `.paused` phase rewrite

Prompt (2026-10-23, follow-up to widget-phase-polish #678): in the app itself
(and by extension the widget), pausing a break repaints the countdown work-red
instead of keeping the break color. Long break included.

- Branch: `feat/pause-keeps-break-color` (stacked on `feat/widget-phase-polish` / PR #678)

## Root cause

`FocusEngine.pause()` and `applyExternalPause()` rewrote `current.phase = .paused`
while stashing the real phase in `phaseBeforePause` for resume. That synthetic phase
then flowed down every consumer:

- `FocusFeature.timerTicked` copies `sessionState.phase` into `state.phase`;
- The app ring asks `theme.color(for:mode, phase:)` → `.paused.isBreak == false` → work red;
- My own `activeSessionPhaseIsBreak` publish (PR #678) went false at pause, so the
  widget ALSO flipped to red — the defect Tiago predicted;
- The watch snapshot switch dumped `.paused` into the `isBreak = false` arm.

The engine itself had to remap `.paused` back in `takeTerminalResult` and `updateConfig`
— proof the public rewrite was debt, not design. Pause is orthogonal to phase:
`isPaused` is the only pause signal; the timed phase must survive untouched.

## Changes

- **Engine**: `pause()`/`applyExternalPause()` no longer touch `phase` (`isPaused` +
  `pausedAt` only). `resume()`/`applyExternalResume()` drop `restorePhaseAfterPause`.
  Deleted: `phaseBeforePause` field, `restorePhaseAfterPause` (~20 lines), both
  remap sites, the reset line. ~52 lines removed total.
- **FocusFeature**: `pauseTapped` and `externalPauseApplied` now explicitly publish
  the preserved phase kind (`activeSessionPhase` + `IsBreak`/`IsLongBreak`) so the
  widget's pause snapshot keeps the break color at the same instant it freezes.
- **AppFeature**: the watch-snapshot switch no longer parks `.paused` in the
  `isBreak = false` arm — it gets its own arm with `assertionFailure` so any future
  `.paused` leak is caught in debug instead of silently mislabeling the watch CTA.
- **Tests**: FocusEngineTests migrated — pause/resume pause-intermediates assert the
  *timed* phase (work/shortBreak/flow/block/freeform + flowBreak) survives, instead
  of the old `.paused` rewrite; reducer comment updated to match.

`FocusPhase.paused` still exists as a display-label-only case (`phaseLabel` "Paused")
— which is its only legitimate use left.

## Log

- L1 (2026-10-23): Implemented. Signed `PepinilloMac Dev` BUILD SUCCEEDED;
  FocusEngine + FocusFeatureReducer + AppGroupContainer + WidgetProGating +
  WatchConnectivityEncoding suites TEST SUCCEEDED on iPhone 17 Pro. Manual:
  pause any break on every surface (app ring, desktop widget, watch) — color
  holds mint (short) / teal (long); "Paused" label shows; resume continues.
