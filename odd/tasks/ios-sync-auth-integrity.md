# Sprint 2 iOS — Sync/Auth integrity

Fix verified P1 defects where local data is merged, resurrected, lost or
never synced: login merge-flow uploads before the user chooses,
soft-deletes resurrect on store switch, legacy history invisible on the
backend branch, DailyStats wiped without rebuild, journals never synced,
deleted last subtask resurrected from server, widget writes race the app.
Authorized scope: "Sprint 2 (sync/auth: merge-flow, soft-deletes,
DailyStats, journal, subtask nil)" + legacy-import (P1, same area) +
widget commands (P1, same area).

## Specs

- S1: `authSucceeded` calls `initialUpload()` (uploads ALL local data)
  BEFORE showing Merge/Account-Only. "Use Account Only" is impossible:
  local data is already merged server-side (AuthFeature.swift:255-270 +
  SyncClient.swift:325). Fix: read-only server-emptiness probe
  (getFullSync) first; upload only after the user picks Merge; wipe +
  pull on Account-Only.
- S2: Store switch drops pending soft-deletes: `copyTasks` filters
  `!isLocallyDeleted` (LocalToCloudStoreMigrator.swift:64-66) and
  `markAllSyncableDataDirty` excludes them (SwiftDataPersistenceService
  .swift:812-826) → unpropagated local delete resurrects on first pull.
  Fix: migrate soft-deleted too (or emit deletes to backend after switch).
- S3: `importLegacyStoreIfNeeded` runs only in the Apple Cloud path
  (PersistenceStoreRouter.swift:184-190); the backend branch jumps to
  `switchToLocal(.backend)` → previous history "disappears". Fix: call it
  in the backend branch too (idempotent by flag).
- S4: `wipeAndSync` deletes DailyStats (`deleteAllStats`,
  SyncClient.swift:591-593) and phase 3 reinserts sessions via
  `upsertSessionFromServer`, which never calls
  `updateOrCreateDailyStats` → heatmap/streaks empty despite sessions.
  Fix: rebuild DailyStats from reinserted sessions.
- S5: Post-session journal/rating never syncs: `saveJournalEntry` sets no
  `isDirty` (SwiftDataPersistenceService.swift:300-311) and
  `FocusSessionSyncDTO` has no journal fields (APIDTOs.swift:205-240) →
  journals are local-only, lost on wipe/reinstall/device change. Fix:
  mark dirty + extend DTO/endpoint (client + backend if needed).
- S6: Deleting the last subtask resurrects from server:
  `subTasks: isEmpty ? nil : ...` (SyncClient.swift:118) and backend
  reads nil as "don't touch subtasks". Fix: explicit empty array +
  provided-flag (client + backend).
- S7: Widget extension writes the shared store with no coordination:
  `CompleteTaskFromWidgetIntent.perform()` saves from the widget process
  (WidgetIntents.swift:181-195) while the app writes via
  `BackgroundPersistenceActor` → lost updates. Fix: widget writes an App
  Group command consumed by the app (existing pause/resume pattern).
- S8: Test-first per rule: one RED test per rule through the public
  interface. iOS runner unavailable here (CLI tools only, no Xcode) —
  tests run in Xcode/CI before merge. Go backend tests run here when the
  toolchain is present.

## Tasks

- T1 (S1): Probe-then-upload login merge flow. Route: inline parent
  (AuthFeature + SyncClient paths). Commit: e15243d7 fix(ios):
  probe server data before uploading in login merge flow.
- T2 (S2): Migrate soft-deletes on store switch. Route: inline parent.
  Commit: 794f79d7 fix(ios): migrate soft-deleted tombstones across
  store switches.
- T3 (S3): Legacy import in backend branch. Route: inline parent.
  Commit: 5605ace2 fix(ios): import legacy store on backend branch too.
- T4 (S4): Rebuild DailyStats after wipeAndSync. Route: inline parent.
  Commit: a06e289f fix(ios): rebuild DailyStats after wipeAndSync
  applies server data.
- T5 (S5): Sync journal/rating (dirty + DTO/endpoint). Route: inline
  parent (backend already round-trips journal — no backend change).
  Commit: 4e26a3d3 fix(ios): sync session journal note and
  satisfaction rating.
- T6 (S6): Explicit empty subtasks (no flag/backend needed — verified).
  Route: inline parent. Commit: 0f0e9ae5 fix(ios): send explicit empty
  subtask list instead of nil.
- T7 (S7): Widget commands via App Group. Route: inline parent.
  Commit: 21af8273 fix(ios): route widget task completion through App
  Group commands.

## Log

- L0 (go-ahead sprint 2, verbatim): "vamos con el Sprint 2"
- L1 (alcance autorizado por parent, verbatim): "Sprint 2 (sync/auth:
  merge-flow, soft-deletes, DailyStats, journal, subtask nil)"
- L2 (T1 done): authSucceeded sondea serverHasData (getFullSync 1 pág.)
  antes de subir; diálogo sin upload previo; Merge sube, Account-Only
  borra y baja limpio. Commit e15243d7 (2 tests test-first). Mismo
  caveat de runner (sin Xcode).
- L3 (T2 done): copyTasks migra tombstones (identidad sync intacta,
  sin subtasks bajo padre borrado; sesiones linkeadas al tombstone) y
  markAllSyncableDataDirty los re-marca para re-push como deletes.
  Commit 794f79d7 (test reescrito + test nuevo test-first). Mismo
  caveat de runner.
- L4 (T3 done): rama backend intenta legacy import best-effort (flag
  idempotente; corrupt no bloquea activación) + hook observer DEBUG.
  Commit 5605ace2 (test behavioral-RED). Mismo caveat de runner.
- L5 (T4 done): fase 3 del wipe reconstruye DailyStats vía la misma ruta
  de agregación de los saves en vivo (por día/modo/counts/streak;
  modos desconocidos se saltan). Commit a06e289f (2 tests test-first).
  Mismo caveat de runner.
- L6 (T5 done): journal marca dirty; DTOs push/pull/initial-upload llevan
  los campos (default nil, backend compatible sin cambios); pull restaura
  en insert sin overwrite. Commit 4e26a3d3 (3 tests test-first).
  Mismo caveat de runner.
- L7 (T6 done): ambos builders mandan array siempre (nil distinguía mal);
  sin flag ni backend (Go sin omitempty + LWW verificados). Commit
  0f0e9ae5 (2 tests test-first). Mismo caveat de runner.
- L8 (T7 done, sprint completo): intent encola comando dedicado sin TTL
  (take atómico, sobrevive stale-discard); app aplica vía setTaskCompleted
  (guard/rollback); widget optimista; snapshot extendido. Commit 21af8273
  (2 tests test-first). Mismo caveat de runner.
