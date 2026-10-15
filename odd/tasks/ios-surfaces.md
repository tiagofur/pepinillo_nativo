# Sprint 4 iOS — Surfaces (Spotlight, widgets, Focus Filter, watch, connectivity)

Fix remaining verified audit defects on system surfaces: PII lingering in
Spotlight after logout, ignored widget configuration, Focus Filter
re-firing on deactivation, wrong period text in insights, dropped
subscription changes during reconcile, stale watch complications, and
stale watch commands executing late. Authorized scope: "Sprint 4
(surfaces: spotlight deindex, widget params, focus filter, insights
text, reconcile rerun, watch pause/budget, watch command TTL)".
Deferred: NWPathMonitor fan-out, Siri/widget streak parity,
preferredMode precedence, sendTasks duplication, updateConfig anchor,
Live Activity end content, mode-breakdown filter, WeeklyReportService
truncation, V4→V5 unique advisory, sortOrder ties, calendar races,
AI cache key — plus all feature suggestions, which need product
decisions first (resume-after-kill, achievements, AI transparency,
monthly pace, energy suggestion wiring, ADHDBreakView wiring,
interactive complications, Smart relevance, standalone watch).

## Specs

- S1: Spotlight index never cleared on logout/account-delete
  (`deleteAll` zero callers; SpotlightClient.swift:52-54) → deleted
  tasks stay searchable system-wide with visible titles (PII). Fix: call
  `deleteAll` in sign-out cleanup (at least with wipeLocalUserData).
- S2: Widget config parameters silently ignored (`showStreak`,
  `showModeBreakdown` declared in ConfigureFocusWidgetIntent, never read;
  FocusWidgetProvider.swift:253-261). Fix: propagate to entry + filter in
  Small/Medium/Large views.
- S3: FocusFilterIntent re-fires auto-start on DEACTIVATION
  (FocusFilterIntent.swift:49-58 queues external start unconditionally;
  system invokes perform on enable AND disable). Fix: persist prior state
  in App Group, revert when already applied (WWDC22 pattern). Residual:
  exact deactivation behavior needs on-device confirmation.
- S4: Insights "weekly" hardcoded text on 30D/Year periods
  ("You focused on N out of 7 days", InsightsService.swift:107, fed with
  periodSessions by AnalyticsFeature.swift:372). Fix: pass the period or
  scope those insights to week.
- S5: Coalesced `reconcile` drops new capabilities (second call awaits
  in-flight and returns without re-running;
  PersistenceStoreRouter.swift:73-78) → subscription change during a
  reconcile is lost until the next event. Fix: re-run with latest
  capabilities (pending-slot loop).
- S6: Watch complication ignores pause + burns refresh budget (1s
  timeline entries + 1-min provider refresh while Text(timerInterval:)
  self-ticks; FocusComplications.swift:60-96,180,287;
  FocusWidgetProvider.swift:27-31). Fix: single entry with anchors +
  `.after(end)` policy; freeze on pause (iOS widget already does).
- S7: Watch→iPhone commands without TTL execute stale (WatchConnectivity
  delivery on next launch, no timestamp check;
  WatchConnectivityClient.swift:490-498). Fix: timestamp + TTL validation
  before executing watch commands.
- S8: Test-first per rule: one RED test per rule through the public
  interface. iOS runner unavailable here (CLI tools only, no Xcode) —
  tests run in Xcode/CI before merge.

## Tasks

- T1 (S1): Spotlight deindex on logout. Route: inline parent.
  Commit: e3e0917f fix(ios): deindex Spotlight on account deletion wipe.
- T2 (S2): Wire widget config params. Route: inline parent. Commit:
  b0150b85 fix(ios): honor widget Show Streak and Mode Breakdown toggles.
- T3 (S3): FocusFilter deactivation guard. Route: inline parent.
  Commit: 27ad19db fix(ios): toggle Focus Filter state so disable never
  auto-starts.
- T4 (S4): Period-aware insights text. Route: inline parent. Commit:
  04be47cf fix(ios): use selected period length in streak insight text.
- T5 (S5): Reconcile rerun on new capabilities. Route: inline parent.
  Commit: 00421b9a fix(ios): rerun reconcile with latest capabilities
  on overlap.
- T6 (S6): Watch/iOS widget pause + budget. Route: inline parent.
  Commit: e3eac877 fix(ios): freeze widgets on pause and stop burning
  reload budget.
- T7 (S7): TTL on watch commands. Route: inline parent. Commit:
  0a2eedf4 fix(ios): drop stale queued watch commands past TTL.

## Log

- L0 (go-ahead sprint 4, verbatim): "Sprint 4"
- L1 (alcance autorizado por parent, verbatim): "Sprint 4 (surfaces:
  spotlight deindex, widget params, focus filter, insights text,
  reconcile rerun, watch pause/budget, watch command TTL)"
- L2 (T1 done): deleteAll en rama wipe del cleanup (sign-out simple
  conserva índice válido). Commit e3e0917f (test test-first). Mismo
  caveat de runner (sin Xcode).
- L3 (T2 done): flags en entry (defaults = intent) + propagación en ambos
  builders + 3 gates en vistas. Sin test automatizado viable (tipos de la
  extensión invisibles a targets de tests): verificación estructural +
  smoke manual de configuración. Commit b0150b85.
- L4 (T3 done): toggle con restore de modo previo (sin start en disable);
  inits explícitos para tests. Residual: orden exacto de desactivación
  requiere confirmación en dispositivo. Commit 27ad19db (2 tests
  test-first). Mismo caveat de runner.
- L5 (T4 done): periodDays con default 7 (callers intactos) + dashboard
  pasa su período; key de localización intacta. Commit 04be47cf (test
  test-first). Mismo caveat de runner.
- L6 (T5 done): pending-slot + loop (single-flight intacto, sin locks por
  @MainActor) + hook de suspensión; la revisión capturó una declaración
  faltante pre-commit. Commit 00421b9a (test determinista con gate).
  Mismo caveat de runner.
- L7 (T6 done): isPaused phone→watch→entry; freeze en 3 faces; single
  entry + .after(end), idle 15min (iOS y watch). Provider/vistas por
  diff review (Context no construible en tests). Commit e3eac877 (test
  test-first). Mismo caveat + verificación en dispositivo.
- L8 (T7 done, sprint completo): sello sentAt en encode + drop >5min en
  userInfo (missing = deliver, back-compat); sendMessage intacto.
  Commit 0a2eedf4 (test test-first). Mismo caveat de runner.
