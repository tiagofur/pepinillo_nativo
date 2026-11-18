# 900 — Siri task lifecycle: complete, query, open (TaskEntity)
Objective: Second Siri phase after #899 — operate the task lifecycle by voice: complete a task, ask for today's tasks, and open a task in the app, reusing the existing `TaskEntity`/`TaskEntityQuery` seam and the `pepinillo://task/<id>` deep-link pipeline that already exists on iOS and Mac.
Branch: `feat/siri-task-lifecycle-900` (worktree, off main `a528bab1`) | Delivery: `complete` | Test runners: `xcodebuild test -scheme "Pepinillo Dev"`, `xcodebuild build -scheme "PepinilloMac Dev"` (stable Xcode 27.2)

## Specs

- **S1**: `CompleteTaskIntent` with `@Parameter task: TaskEntity`; persists `isCompleted` + `completedAt` via `makeIntentsModelContainer()` and returns a confirmation dialog EN/ES/PT.
- **S2**: `GetTodayTasksIntent` returning `ReturnsValue<[TaskEntity]>` + `ProvidesDialog` with a spoken summary (respecting `scheduledForToday` and active tasks).
- **S3**: `OpenTaskIntent` opens the app and navigates to the task (reusing the existing `pepinillo://task/<id>` deep link; no new navigation surface).
- **S4**: App Shortcuts with EN/ES/PT phrases for the new intents + `AppShortcuts.xcstrings` updated.
- **S5**: Evaluate conformance with the applicable `.task` schemas of the current SDK; document in the PR which schema cases exist and which are adopted.
- **S6**: Both schemes (`Pepinillo Dev` + `PepinilloMac Dev`) compile clean + unit tests for the logic + "Cómo probar" section in the PR with manual Siri QA on Mac and iPhone.

## UX Brief

Not required by the issue (no `ux:shape` label). Voice-first surface: dialogs follow the established #899 tone (short, emoji-tailed confirmations), parameter summaries follow the existing localized keys pattern in `Localizable.xcstrings`.

### Assumptions

- A1: "Today" = `scheduledForToday == true` (the in-app Today flag), excluding completed, tombstoned (`isLocallyDeleted`) and recurring-template tasks. `dueDate`-based inclusion is NOT added (S2 wording names `scheduledForToday` explicitly).
- A2: Completing is NOT free-tier gated — the #216 cap only guards creation, not completion.
- A3: AppShortcut slots (Tiago decision, 2026-11-18): demote `ResumeFocusIntent` and `GetCurrentSessionIntent` AppShortcut entries (intent structs remain usable from the Shortcuts app); `CompleteTaskIntent` and `GetTodayTasksIntent` get phrases; `OpenTaskIntent` ships WITHOUT an AppShortcut entry (dynamic entity phrases are clunky; it stays reachable from Shortcuts/Spotlight). This keeps the provider at the Apple 10-shortcut limit.
- A4: Deep link: `openAppWhenRun = true` + open `pepinillo://task/<uuid>` via `UIApplication.open` (iOS) / `NSWorkspace.open` (macOS). Both platforms already route `pepinillo://task/` to task detail (AppFeature `.appURLReceived` → `pendingDeepLinkTaskID`; `PepinilloMacApp.swift:343`).
- A5: Tombstone debt tagged to #900 during #899 triage: `TaskEntityQuery.fetchActiveTasks` gains `!isLocallyDeleted` (a planned scope expansion over the issue's surfaces — `StartFocusIntent.swift` outside the `PepinilloShortcuts` block; justified as the debt was explicitly recorded against #900).

## Allowed edit surfaces

- `ios/PepinilloIntents/CompleteTaskIntent.swift` (new)
- `ios/PepinilloIntents/GetTodayTasksIntent.swift` (new)
- `ios/PepinilloIntents/OpenTaskIntent.swift` (new)
- `ios/PepinilloIntents/TaskIntentService.swift` (new — shared pure query seam for the three intents + `TaskEntityQuery` delegation)
- `ios/PepinilloIntents/StartFocusIntent.swift` (the `PepinilloShortcuts` block + `TaskEntityQuery` tombstone delegation per A5)
- `ios/PepinilloIntents/AppShortcuts.xcstrings`
- `ios/Shared/Resources/Localizable.xcstrings` (dialog + parameter-summary keys EN/ES/PT)
- `ios/Tests/SiriIntentsTests/**`
- `odd/tasks/900-siri-task-lifecycle.md`

## Tasks

- [x] **T1** (`S1`, risk: `V1`): `CompleteTaskIntent` + `TaskCompletionService` (mark completed, tombstone/not-found/already-done cases) — RED tests first.
- [x] **T2** (`S2`, risk: `V1`): `GetTodayTasksIntent` + today summary builder — RED tests first.
- [x] **T3** (`S3`, risk: `V1`): `OpenTaskIntent` + deep-link URL builder — RED test first.
- [x] **T4** (`S4`, risk: `V0`): shortcut slots swap (A3) + `AppShortcuts.xcstrings` phrase keys + dialog/summary keys EN/ES/PT.
- [x] **T5** (`S5`, risk: `V0`): document SDK 27.2 schema audit in the PR (no `.task` schema cases exist — grep of `AppIntents` swiftinterface).
- [x] **T6** (`S6`, risk: `V1`): both schemes build + focused suite green + "Cómo probar".

## Log

- **L1 (2026-11-18)**: Triage session — issue started after the Apple-queue sweep (#631/#629/#692/#746/#767/#795/#796 verified done and closed; #915 merged). Slot decision A3 confirmed by Tiago.
- **L2 (2026-11-18)**: SDK audit for S5: `AppIntents.framework` swiftinterface (iPhoneOS27.2.sdk) contains no `.task` assistant-schema cases (only `performBackgroundTask`/`LongRunningTaskOptions`); consistent with the `.task.createTask` finding recorded during #899. All three intents are plain `AppIntent`s.
- **L3 (2026-11-18)**: RED tests written for T1–T3 against the new service seam (compile-gated RED, same batch as the implementation per the #848/#899 house pattern). Localizable.xcstrings was already carrying a "Complete Task" key (Mac context menu, `extractionState` manual) — kept that entry as the AppShortcut shortTitle and did not duplicate it.
- **L4 (2026-11-18)**: Catalog edits: AppShortcuts.xcstrings via order-preserving JSON round-trip (byte-identical dump verified before mutation — compact `": "` separators); Localizable.xcstrings via raw-text insertion at its `": "`/" : " Xcode format (full-file re-dump diverges, so text surgery only). `parameterSummary` omitted on the parameterless GetTodayTasksIntent, matching StopFocusIntent/CheckStatsIntent.
- **L5 (2026-11-18)**: Verification — `xcodebuild test -scheme "Pepinillo Dev"` (iPhone 18 Pro, stable 27.2): 43/43 test cases passed across CompleteTaskIntentTests / GetTodayTasksIntentTests / OpenTaskIntentTests / CreateTaskIntentTests / SiriIntentsTests (11 new, rest regression). Note: the simulator runs an ES locale — summary assertions resolve through the catalog rather than hard-coded EN sentences. `xcodebuild build -scheme "PepinilloMac Dev"` succeeded under DEVELOPER_DIR=Xcode-beta.app (27.3 SDK, pre-existing Dev-scheme requirement from the touch-on-Mac/Live-Activities work); under stable 27.2 the Dev scheme fails in PepinilloLiveActivity with ActivityKit unavailability — pre-existing, unrelated to this change. Budget: ~250 Swift logic lines + ~360 catalog rows; kept as one PR because S1–S4 are one voice-lifecycle deliverable (same call as #899's 378-line PR).
- **L6 (2026-11-18)**: Judgment-day round 1 (dual blind judges over the frozen packet): both judges confirmed one severe finding — F1, `markCompleted` did not stamp `isDirty = true`, so a Siri completion of a previously-synced task was never selected by `fetchDirtyTasks` and never uploaded (every in-app mutation path stamps it). Fixed in one work unit (stamp + `markCompletedStampsDirty` test); focused suites re-run green 12/12. Evidence corrections applied to this log (11 new tests, `shortcutsCount` is `>= 2`). Recorded as info without fix (single-judge or suggestion severity): Siri completion writes the store directly and does not ride the widget external-command pipeline (foregrounded app refreshes on next tasks reload — suspect for a follow-up), NSSiriUsageDescription predates the new voice operations, parameter summaries fall back to EN literals (pre-existing pattern), fetch errors conflate with notFound, perform()-level tests deferred (same P3 ledger item as #899).
