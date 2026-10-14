# Sprint 3 iOS — Correctness (stuck UI, calendar pollution, honest stats, fair merges)

Fix verified P2 defects where the app gets stuck, pollutes real user data,
or shows wrong numbers: unhandled effect errors, orphan Calendar events,
partial-vs-full month trends, inclusive-boundary double counts, timestamp
-blind overwrites (preferences + tasks), and Reminders import gaps.
Authorized scope: "Sprint 3 (correctness: try/catch effects, calendar
cleanup, fair monthly trend, exclusive boundaries, LWW prefs/tasks,
reminders import)". Deferred to later: NWPathMonitor fan-out, reconcile
coalescing, Spotlight deindex on logout, widget config params,
FocusFilterIntent deactivation, Siri/widget streak parity, insights
period text, watch refresh budgets, feature suggestions (resume-after-kill,
achievements, interactive complications, smart relevance, standalone watch).

## Specs

- S1: TCA `.run` with `try await` and no `do/catch` → `reportIssue` +
  dead effect → `isLoading` stuck forever, guard blocks retries
  (CalendarFeature.swift:110-111,152-153; TaskDetailFeature.swift:264;
  TaskListFeature.swift:256,271,638; TaskAnalyticsFeature.swift:37;
  FocusFeature.swift:561). Fix: do/catch → error action everywhere.
- S2: Calendar event created on focus start, never removed
  (`removeFocusEvent` zero callers; CalendarClient.swift:29,
  FocusFeature.swift:374 with `try?`, no eventIdentifier kept) →
  cancelling leaves a phantom busy block in the user's real calendar.
  Fix: persist eventIdentifier + remove/truncate on abort.
- S3: MonthlyReview compares partial current month vs full previous month
  (`minutesDelta`, MonthlyReviewFeature.swift:198) → trend "down" on day 3
  even when daily pace improved. Fix: same-N-days or daily averages.
- S4: `fetchSessions` inclusive end (`startedAt <= end`,
  SwiftDataPersistenceService.swift:189-194) + callers passing
  `end == nextStart` (WeeklyReviewFeature.swift:93,99) → sessions at
  exactly 00:00:00 count in two periods. Fix: exclusive predicate + callers.
- S5: `applyServerPreference` ignores its `updatedAt` parameter
  (SwiftDataPersistenceService.swift:981-1017) → any pull overwrites a
  newer unpushed local preference. Fix: compare per-key timestamps (LWW).
- S6: `upsertTaskFromServer` discards server updates for dirty tasks without
  comparing `updatedAt` and fabricates `completedAt = Date.now`
  (SwiftDataPersistenceService.swift:677-700). Fix: LWW by updatedAt +
  real completedAt (finishDate).
- S7: Reminders import partial failure desyncs the list and bypasses the
  free-tier cap (cap only in addTaskTapped:339; TaskListFeature.swift:
  655-684). Fix: refetch after partial error with imported count in the
  message + enforce the cap on import (same paywall as add).
- S8: Test-first per rule: one RED test per rule through the public
  interface. iOS runner unavailable here (CLI tools only, no Xcode) —
  tests run in Xcode/CI before merge.

## Tasks

- T1 (S1): do/catch in all throwing effects. Route: inline parent
  (reducers share error-action patterns). Commit: d0f231a9 fix(ios):
  handle errors in all throwing TCA effects.
- T2 (S2): Calendar event cleanup on abort. Route: inline parent.
  Commit: e7ad4890 fix(ios): remove calendar event when aborting a
  focus session.
- T3 (S3): Fair month-over-month comparison. Route: inline parent.
  Commit: 116d5576 fix(ios): compare day-equivalent windows in monthly
  review trends.
- T4 (S4): Exclusive fetchSessions boundary. Route: inline parent.
  Commit: 718877d3 fix(ios): use exclusive end in fetchSessions window
  predicate.
- T5 (S5): Preferences LWW per key. Route: inline parent. Commit:
  02a28d25 fix(ios): keep unpushed local preferences on server pull.
- T6 (S6): Task upsert LWW. Route: inline parent. Commit: 7e073704
  fix(ios): last-write-wins by updatedAt in task upsert from server.
- T7 (S7): Reminders import robustness + cap. Route: inline parent.
  Commit: 03dafe9c fix(ios): enforce free-tier cap and surface partials
  in reminders import.

## Log

- L0 (go-ahead sprint 3, verbatim): "arrancamos con el Sprint 3"
- L1 (alcance autorizado por parent, verbatim): "Sprint 3 (correctness:
  try/catch effects, calendar cleanup, fair monthly trend, exclusive
  boundaries, LWW prefs/tasks, reminders import)"
- L2 (T1 done): 6 effects con do/catch (Calendar ×2 con fallback vacío,
  TaskAnalytics con analyticsFailed, addSubtask con restore, dismiss con
  tasksLoadFailed, suggestion con nil). Commit d0f231a9 (6 tests
  test-first). Mismo caveat de runner (sin Xcode).
- L3 (T2 done): createFocusEvent retorna identifier (String); reducer lo
  guarda en State (nueva acción) y stopTapped lo remueve en teardown
  (clear en resetState). Residual: skip-terminal-completed y kill dejan
  el resto del bloque (sin tracking de fin). Commit e7ad4890 (test
  test-first). Mismo caveat de runner.
- L4 (T3 done): ventana previa day-equivalent (primeros N días, clamp a
  longitud del mes) vía helper puro; deltas/trends/view intactos.
  Commit 116d5576 (3 tests de fechas fijas). Mismo caveat de runner.
- L5 (T4 done): predicado `startedAt < end` (los 14 callers ya pasan
  rangos end-exclusive: partición limpia sin tocar callers; incluye el
  clamp de T3). Commit 718877d3 (test behavioral-RED de medianoche).
  Mismo caveat de runner.
- L6 (T5 done): dirty-wins en applyServerPreference (sin timestamps
  locales: dirty = no visto por server; clean acepta). Cubre los 3 pulls.
  Commit 02a28d25 (2 tests test-first). Mismo caveat de runner.
- L7 (T6 done): LWW por updatedAt (server gana empates; desconocido no
  sobreescribe) + completedAt real (nunca clobber; fallback server-ts,
  no finishDate que es due date). Commit 7e073704 (3 tests test-first).
  Mismo caveat de runner.
- L8 (T7 done, sprint completo): cap free-tier en tap y mid-run (mismo
  paywall que adds) + parciales al estado en fallo + RemindersClient
  inyectado (testeable sin EventKit). Commit 03dafe9c (3 tests
  test-first). Mismo caveat de runner.
