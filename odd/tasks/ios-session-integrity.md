# Sprint 1 iOS — Session integrity (focus)

Fix verified P0/P1 defects where tracked focus diverges from real focus:
Flowtime accumulation, widget-anchor pause, skip partial credit, hold
double-persist, kill/ghost abandonment, external-command consumption,
stop→start race. Authorized scope: "acumulador de focus total en
Flowtime, re-anclaje en pausa, persistencia parcial en skip,
deduplicación del hold, abandono persistido en ghost/kill, consumo real
de starts externos. Con tests por regla."

## Specs

- S1: Flowtime 40min → break → flow 10min → stop persists only 10min.
  `stop()` builds `actualDuration: current.elapsedSeconds`
  (FocusEngine.swift:233) while `applyPhaseTransition` resets
  `current.elapsedSeconds = 0` per phase (:629). Fix: accumulate
  session-total focus across phases; `stop()` persists the total.
- S2: Widget-anchored session paused mid-phase then resumed completes
  early and stats lie. `tick()` recomputes `remaining` from the stale
  `phaseTimerEnd` anchor (FocusEngine.swift:486-490); pause never shifts
  it. Fix: on resume/applyExternalResume, re-anchor
  `phaseTimerEnd = Date.now + actual remaining` (or drop the anchor).
- S3: Skipping a pomodoro work phase at 10min persists nothing; those
  10min vanish from stats. `advancePhase` emits no `.phaseCompleted`.
  Fix: persist partial credit (`wasCompleted=false`) for skipped work.
- S4: Stopping during the waiting-hold after a completed work phase
  persists a duplicate abandoned interval (`elapsedSeconds=target`,
  phase still `.work`) on top of the completed one. Fix: `stop()` marks
  already-persisted intervals; reducer skips them (FocusFeature.swift:779).
- S5: Force-quit mid-session evaporates it: ghost snapshot cleared at
  cold launch with nothing persisted (PepinilloApp.swift:210). Fix:
  persist an abandoned `FocusSessionResult` computed from anchors before
  `clearActiveSession()`.
- S6: Start from widget/Control Center with app not in foreground shows
  a phantom countdown; no engine consumes it (consumption only in
  `appLaunched`/`appBecameActive`; `CancelID.externalCommandObserver`
  declared AppFeature.swift:269, never used); TTL discards silently.
  Fix: on next activation, reconcile unconsumed external-start
  snapshots within TTL by backfilling the elapsed interval
  (completed if elapsed >= target else abandoned partial), mark
  consumed, never double-apply.
- S7: Rapid start after stop cancels the task carrying buffered
  `.sessionCompleted` (`startTapped` reuses
  `CancelID.engineObservation`; stop deliberately doesn't cancel it, #170)
  → abandoned session never persisted. Fix: drain/persist the buffered
  completion in the stop path (FocusFeature.swift:355).
- S8: Test-first per rule: one RED test per rule through the public
  interface (engine result / reducer actions + persisted record),
  asserting observable effect (persisted duration, record count,
  no duplicates). Existing-command regression coverage only for
  commands sharing changed code.

## Tasks

- T1 (S1): Flowtime session-total accumulator in FocusEngine. Route:
  inline parent (coupled engine state). Commit: fb99bb3c fix(ios):
  accumulate multi-phase focus total in session stop.
- T2 (S2): Pause re-anchor for anchored sessions. Route: inline parent.
  Commit: 2d779030 fix(ios): re-anchor widget timer end across pause
  on resume.
- T3 (S3): Skip-phase partial credit. Route: inline parent. Commit:
  34347d35 fix(ios): persist partial credit when skipping pomodoro
  work.
- T4 (S4): Stop-in-hold dedup. Route: inline parent. Commit: 07e56b4d
  fix(ios): skip persistence for stop during waiting hold.
- T5 (S5): Ghost/kill abandonment persistence. Route: inline parent.
  Commit: 879f98e7 fix(ios): persist abandoned record for killed
  mid-session ghost.
- T6 (S6): External-start reconcile on activation. Route: inline parent.
  Commit: 54007012 fix(ios): backfill stale widget starts instead of
  silently dropping.
- T7 (S7): Stop→start drain. Route: inline parent. Commit: d76cc7f9
  fix(ios): drain stop abandon directly instead of via observation.

## Log

- L0 (origen, verbatim): "hagamos una review de la app iOS buscando
  puntos de mejora sea de diseño, fallos de codigo, bugs, perdida de
  datos o memoria, funciones que no tienen la logica correcta o no hacen
  bien su funcion por estar incompleta o en algun punto hace algo que no
  es lo ideal o correcto, todo tipo de correcion o mejora, incluso
  sugerencias de cambios o nuevas features que pueden aportar a la app
  y que esten fltando"
- L1 (go-ahead sprint 1, verbatim): "empezamos con el sprint 1"
- L2 (alcance autorizado por parent, verbatim): "acumulador de focus
  total en Flowtime, re-anclaje en pausa, persistencia parcial en skip,
  deduplicación del hold, abandono persistido en ghost/kill, consumo
  real de starts externos. Con tests por regla."
- L3 (T1 done): engine acumula focus por fase en stop/transiciones
  (breaks excluidos, pausa resuelve fase subyacente); reducer persiste/
  journal/health-loguea el total en no-pomodoro; pomodoro intacto.
  Commit fb99bb3c (tests incluidos). Runner no disponible aquí (solo
  CLI tools, sin Xcode): FocusModels.swift pasa swiftc -typecheck;
  ejecutar FocusFeatureTests en Xcode/CI antes del merge.
- L4 (T2 done): resume() y applyExternalResume() desplazan phaseTimerEnd
  a Date.now + remaining congelado (solo si había ancla; sesiones sin
  ancla intactas). Commit 2d779030 (test incluido). Mismo caveat de
  runner que T1.
- L5 (T3 done): advancePhase() emite .phaseSkipped con partial
  wasCompleted=false y UUID fresco solo para work de pomodoro (tras el
  guard terminal para no duplicar con stop()); reducer lo persiste sin
  teardown/journal/efectos. Flowtime cubierto por acumulador S1.
  Commit 34347d35 (tests incluidos). Mismo caveat de runner.
- L6 (T4 done): stop() marca isHoldStop desde pendingNextPhase (lectura
  síncrona en el actor); reducer no persiste hold-stops en ninguna rama.
  El hold no pasa por applyPhaseTransition: plegado único. Commit
  07e56b4d (tests incluidos). Mismo caveat de runner.
- L7 (T5 done): SessionReconcilePolicy snapshottea el ghost (validador
  puro: excluye holds e inactivos, clamp a anclas, umbral 60s anti-streak)
  antes del clear; launch lo persiste como abandoned via
  FocusSessionResult(ghost:) (fases por modo, task UUID, target recuperado).
  Snapshot en primitivas (Shared compila en extensiones). Commit 879f98e7
  (6 tests en AppGroupContainerTests). Mismo caveat de runner.
- L8 (T6 done): take atómico snapshot+clear de starts stale (frescos
  adoptan normal); ventana servida = completed, parcial = abandoned,
  open-ended cap 12h. Acción reconcileStaleExternalStart concatenada
  antes de consume en launch/activation + cold launch antes del ghost
  takeoff; skip con engine corriendo. Commit 54007012 (7 tests +
  wiring AppFeature por diff review). Mismo caveat de runner.
- L9 (T7 done): stop() extraído a takeTerminalResult compartido;
  abandonSession() retorna sin emitir; stopTapped cancela + drena vía
  .stopAbandoned (persist-only, respeta isHoldStop, sin teardown/journal).
  Stream sin copia: ni drop ni doble. Commit d76cc7f9 (engine test +
  reducer test behavioral-RED + 2 tests actualizados). Mismo caveat.
