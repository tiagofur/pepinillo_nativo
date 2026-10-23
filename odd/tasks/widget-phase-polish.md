# Widget phase polish — hold timing, break color, next-phase control, 5-min floor

Prompt (2026-10-23, live testing on the Mac desktop): three defects at phase boundaries.
(1) After a 2-min break ends, the widget shows 1:59 instead of the next Pomodoro's 5:00;
after a 5-min Pomodoro it shows ~4:58 — the widget never re-anchors to the new phase.
(2) During breaks the countdown stays work-red instead of switching to the break color.
(3) Settings pomodoro stepper allows 1 min and stepping up jumps to 6 (1+5) — the
product floor should be 5 minutes.

- Branch: `feat/widget-phase-polish` (stacked on `feat/widget-free-tier` / PR #676 —
  Tiago's Xcode builds from the stack)

## Root causes

1. **Stale hold display**: in the waiting hold (`waitingForNextPhase`) FocusFeature
   correctly nils the countdown anchors (no timer runs) but publishes nothing about
   what comes next. The widget provider's snapshot fallback (`activeSessionLiveElapsed/
   LiveRemaining`) then renders the *finished* phase's leftover — the break's 1:59 that
   Tiago saw. The app shows the pending phase target; the widget showed the dead one.
2. **Phase color never matched**: `ModeColors.color(for:phase:)` matches English
   strings ("Short Break") against `activeSessionPhase`, which is a *localized* label
   ("Descanso corto") — never matches outside English, and no widget view called it
   anyway. Views color by mode only (pomodoro = red, always).
3. **Stepper floor 1 with step 5**: SwiftUI `Stepper(value:in: 1...120, step: 5)` snaps
   from 1 to 6 on first increment; reducer clamped to `max(1,…)`.

## Changes

- **Typed phase bools in AppGroupDefaults** (same pattern the watch snapshot already
  uses: `isBreakPhase`): `activeSessionPhaseIsBreak`, `activeSessionPhaseIsLongBreak`,
  written by FocusFeature in `startTapped` (initial phase), `timerTicked`,
  `phaseCompleted`, `waitingForNextPhase` (the pending phase's kind), `startNextPhaseTapped`,
  `extendSessionTapped`, and the ghost-adopt path; cleared by `clearActiveSession`.
- **Pending-phase target**: `activeSessionNextPhaseTarget` written on entering the hold,
  cleared when the next phase starts or the session ends. The widget provider's
  waiting branch shows this (e.g. the 5:00 coming up), with anchors forced nil,
  elapsed 0, progress 0 — no more phase-to-phase bleed.
- **Widget "start next phase" control**: new `StartNextPhaseFromWidgetIntent` optimisti-
  cally anchors the pending phase live (or timer-less for open-ended phases) and raises
  `externalNextPhaseRequested` (posts the Darwin signal via the setter); `consumeExternal-
  Commands` routes it to `FocusFeature.startNextPhaseTapped` behind the same guard the
  app button uses. The widget control row now shows the green Play CTA during the hold
  instead of hiding everything (matching the app + the watch). TTL check extended to
  the new command.
- **Phase-aware widget color**: new `phaseAccentColor()` helper in FocusWidgetViews
  switches small/medium/large active layouts to the short/long break variants while
  `isBreakPhase` holds (paused/ring/text all follow). Tinted mode unchanged.
- **5-minute floor**: Mac + iOS pomodoro steppers `5...120, step: 5`; reducer clamp
  `max(5,…)`; preferences load clamps legacy 1–4 values up to 5. Break steppers keep
  `1...30` (Tiago's verdict: only the pomodoro floor moves).
- Test: `testPomodoroDurationClampedMin` updated to the new floor (0 and 1 → 5).

## Log

- L1 (2026-10-23): Implemented. Builds: signed `PepinilloMac Dev` SUCCEEDED; `Pepinillo
  Dev` + AppGroupContainer + WidgetProGating + FocusFeatureReducer + SettingsFeature
  suites TEST SUCCEEDED on iPhone 17 Pro. Caught mid-work: my AppGroupContainer edit
  had briefly duplicated `activeModeName` and dropped `activeSessionPhase` — fixed
  before building. Manual gap remains end-to-end: Tiago runs Pomodoro with test
  durations — the desktop should now show the pending phase's full target + Play CTA
  during every hold, and break-colored countdowns during breaks.
