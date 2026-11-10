# Android + Wear Super Review

Full read-only audit of the Android phone app and Wear OS app, matching the
iOS/Apple Watch audit standard (65 findings, P0/P1/P2), followed by fixes for
data-integrity and functional bugs plus welcome UI/UX improvements.

## Specs

- S1: "hicimos un review COMPLETO de la app iOS y el Apple Watch, ahora tenemos que hacer el SUPER review completo en Android y Wear, para tener la certeza que todo esta perfecto."
- S2: "en Android asi como dejamos en iOS, mejoras de UI/UX tambien son bienvenidas"

## Tasks

| ID | Spec | Task | Route | Commit |
| ---- | ---- | ---- | ---- | ------ |
| T1 | S1 | Create feature doc + Engram mirror + todo projection | inline | — |
| T2 | S1 | Parallel read-only audits: Focus/timer+services, persistence+sync, auth+billing, tasks+domain, widgets+platform, Wear+integration, UI/UX | 7x gentle-ai-explore | — |
| T3 | S1 | Run Android + Wear test suites and assemble both APKs | inline | — |
| T4 | S1 | Synthesize findings report (P0/P1/P2 with file:line evidence) | inline | — |
| T5 | S1 | Fix A-series P1s (sync/data integrity) + supporting backend | inline/worker | — |
| T6 | S1 | Fix B-series P1s (auth/billing) | inline/worker | — |
| T7 | S1 | Fix C-series P1s (tasks/domain/stats) | inline/worker | — |
| T8 | S1 | Fix D-series P1s (widgets/service) | inline/worker | — |
| T9 | S1 | Fix E-series P1s (Wear) | inline/worker | — |
| T10 | S2 | UI/UX + localization bundle (F-series) | inline/worker | — |
| T11 | S1,S2 | Final report + PR handoff | inline | — |

## Log

- L1: "hicimos un review COMPLETO de la app iOS y el Apple Watch, ahora tenemos que hacer el SUPER review completo en Android y Wear, para tener la certeza que todo esta perfecto.en Android asi como dejamos en iOS, mejoras de UI/UX tambien son bienvenidas"
- L2: Baseline: repo at 89711b31 on fix/ios-build-warnings (iOS work, unmerged). Android audit runs read-only against current tree; fixes will branch from main. iOS audit standard: obs-9e7b9b6fa951b52a (65 findings, P0/P1/P2 with file:line evidence).
- L3: Fix waves: backend 1935743d (has-data + acks + DoUpdates) + manifest 79ec5c6f + wear queries 5d064eb6 done by parent inline. Workers W2 (B1-B4, 89 tests green in scratch), W3b (C1/C3/C4 + P2s, 91 tests green pre-contract), W5 (E1-E5, 112 wear tests green), W6 (F1/F3-partial + polish, 69 tests green; F4 + dashboard-root deferred to parent inline), W4 (D1-D2 + P2s, 40 tests green; WidgetRefreshWorker surface approved) finished. W3a failed 2x on subagent infra → parent implemented inline (SyncEngineTest 37 + DailyStatsRecomputeTest 9 green, schema v14). Slice note: 1417 lines in 4 commits; remaining merges land as one commit per branch (W5, W4, W2, W3b, W6) + inline F4 remainder, then full suite + report.
- L4: All 5 worker branches merged (W5 ac370989, W4 f98bf883, W2 3bfe9023, W3b 72b5d1be, W6 4b94ae19; strings.xml append-append conflicts resolved keeping both key sets). Contract-crossing tests green on merged tree. Inline remainder committed: pluralized counts (tasks/ai-credits/sync-ago/durations) in 3 locales, localized formatMinutes x3, review-sheet mode names, dashboard error+retry via hasHistory (+2 tests). Full suite + APKs running as job-3.
- L5: CLOSED. Full suite: app 636 + wear 112 tests, 0 failures; both APKs assemble. 6 worktrees removed, scratch cleaned. Native assess: unassessable (untracked helper files), no reviewDue → writer self-verification stands (focused + full suites green, contract tests green, spot-checked diffs). Deferred (documented, not fixed): sync settings push redesign (server full-row Save can clobber — self-heals via max-merge), client stats-push vs server recompute duplication, guest-purchase server verification retry, upgrade/proration handling, iOS merge-ordering twin (backend contract ready; iOS client still uploads first).

## Findings — synthesis (7 audits, 0 P0 / 21 P1 / ~40 P2 / ~6 P3)

Spot-checked and confirmed: A1, B1, C1, E1 (read in source by parent).

### P1 — sync/data integrity (A)
- A1 `replaceSyncSnapshot` wipes daily_stats with no recompute: free-tier users get permanently empty streaks/history after wipeAndSync; entitled users lose tasksCompleted/longestSessionMinutes (server DTO lacks them). PepinilloDatabase.kt:75-95, SyncEngine.kt:594,790-792.
- A2 Pull-merge "nil = no-touch" resurrects cleared dueDate/recurrenceRule across devices. SyncEngine.kt:468-480.
- A3 LWW compares device clock vs server clock; rejected pushes still marked synced (silent edit loss). SyncEngine.kt:419-436, backend task_repository.go:259-261.

### P1 — auth/billing (B)
- B1 Merge-before-choice: initialUpload runs before MergeConflict dialog → "Use Account Only" impossible (Android twin of iOS bug); error path skips dialog and pushes dirty rows anyway. SessionManager.kt:182-196,233-236.
- B2 Merge dialog dead-end from EmailVerificationScreen routes. AuthViewModel.kt:276-282, MainActivity routes.
- B3 AuthStorageUnavailableException = Hilt DI crash loop (no production catch). AuthStore.kt:55-76,107.
- B4 Failed receipt verification syncs stale profile → downgrades just-purchased entitlement. PaywallViewModel.kt:173-176, SubscriptionManager.kt:278-296.

### P1 — tasks/domain/stats (C)
- C1 Mixed due-date encodings (UTC-midnight picker vs local-midnight quick-add; UTC vs local reads; raw millis SQL bounds) → tasks vanish from Upcoming, inconsistent badges. TaskDetailScreen.kt:1033, TasksViewModel.kt:244-252,124, TaskItem.kt:447,456, TaskDao.kt:106.
- C2 Recurring completions never counted in daily tasksCompleted (advanceRecurringTask keeps isCompleted=false; count query misses it). TaskRepository.kt:267-289, TaskDao.kt:103.
- C3 Focus score denominator = days-with-stats-row not calendar days → rest days free points. DashboardViewModel.kt:295-302.
- C4 Soundscape fade race: unguarded mediaPlayer.setVolume → IllegalStateException. SoundscapeManager.kt:210-221.

### P1 — widgets/service (D)
- D1 Stop-from-notification races service teardown → zombie Running widget + stale linked-task. FocusTimerService.kt:270-291.
- D2 Unguarded startForegroundService in Application.onCreate under WorkManager respawn → ForegroundServiceStartNotAllowedException crash loop. PepinilloApplication.kt:44,81-86.

### P1 — Wear (E)
- E1 Queue coalescing path mismatch (/cmd/timer_pause vs /cmd/timer/pause) → offline dedup dead. WearPendingCommandQueue.kt:26-31 (confirmed).
- E2 No command ack/reconciliation → phantom watch session ticking with no phone session. WearMessageSender.kt:56-70, WearViewModel.kt:85-107.
- E3 WaitingForNext tears down WearFocusService (notification gone, receivers unregistered). WearSyncListenerService.kt:186-190 vs WearFocusService.kt:193-196.
- E4 Speech recognizer launch without resolve/catch → ActivityNotFoundException crash. TimerScreen.kt:682-690.

### P1 — UI/UX + localization (F)
- F1 Focus timer a11y: no liveRegion, double announcement, 1Hz vs 4Hz mismatch. FocusScreen.kt:336-341.
- F2 Pomodoro stepper +/- without contentDescription. TaskDetailScreen.kt:734,744.
- F3 Raw enum names shown to users (priority/energy/recurrence/modes/tier) in es/pt markets.
- F4 Plurals missing: "1 days", "1 sessions today", es "1 activas". strings.xml:487,471,497.

### Notable P2s (fix quick wins, defer the rest)
Focus engine (solid overall): pause-metrics leak across phases FocusEngine.kt:499; interruptionCount never incremented; skipped breaks persisted wasCompleted=true FocusEngine.kt:452-458; count-up notification frozen FocusTimerService.kt:386; widget startService vs startForegroundService FocusTimerWidget.kt:602-607; silent free-tier fallback; duplicate-persist window on phase transition.
Sync P2s: session push livelock under skew SyncEngine.kt:601-609; stats push clobbers server recompute SyncEngine.kt:752; DataStore+Room non-atomic UserPreferencesRepository.kt:255-264; subtask+parent two transactions TaskRepository.kt:250-282; timezone day keys; sortOrder-0 treated absent SyncEngine.kt:474.
Domain P2s: report SimpleDateFormat local-time-labeled-Z ReportDataBuilder.kt:29; peak-hour no midnight wrap; month recurrence overflow RecurrenceCalculator.kt:27; calendar month bound inclusive; weekday headers break for Monday-first CalendarScreen.kt:69-75; midnight attribution start_time vs created_at; quick-add limit race; no title/notes limits.
Widgets P2s: FocusTimerWidget never refreshes while idle; TasksWidget ≤15min stale; SelectModeAction bypasses gating FocusTimerWidget.kt:567-594; dead Start/PauseResume actions with startService; onEnabled mode wipe; double haptic FeedbackManager.kt:143,61; ManufacturerUtils needs <queries>.
Wear P2s: no CAPABILITY_CHANGED phone-side; ambient 10Hz ticks TimerScreen.kt:75-88; stale notification body; task row not TalkBack-accessible TasksScreen.kt:170-180; 40dp touch targets; StatsScreen sync status free-tier missing; DiagnosticsScreen unreachable.
UI/UX P2s: brandGreen() hardcoded TaskItem.kt:476-481; FilterPill shape TasksScreen.kt:558; hero timer font inline FocusScreen.kt:378-383; contrast risks PriorityColors; dashboard error→empty-state lie DashboardStats.kt:96-113; detail sheet imePadding TaskDetailScreen.kt:151-157; paywall subtitle row + legal targets; 12h clock forced; chart strings hardcoded; ModeChip/calendar semantics.

### Verified-correct highlights
Focus engine elapsed accounting (monotonic anchors, pause freeze, atomic per-phase persistence, process-death recovery, external-start no-op guards, doze FGS, DST); Room migration chain 1→13 no destructive fallback; sync idempotency (UUID PK + ON CONFLICT); EncryptedSharedPreferences tokens; sign-out teardown order; streak service DST-safe; toggleCompletionAtomic; Glance single-process; wear delegated session model + bounded offline queue; design system (shape/motion tokens, reduce-motion, skeletons, predictive back, dynamic color).
