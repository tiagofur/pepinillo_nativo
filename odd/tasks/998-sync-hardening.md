# odd/tasks/998-sync-hardening.md

Issue: https://github.com/tiagofur/pepinillo_nativo/issues/998 (status:ready; follow-up de la dual de #989 PR-C)
Topología: Delegated Direct · Único escritor: implementador de esta sesión
Base: main 42877221 · 1 PR (backend + web; sin contratos HTTP, sin migraciones, sin ux)
Origen: ronda 1 del Juez B (P1) + ronda 2 (P2s) de la revisión de #989 PR-C.

## Specs (S1..Sn derivadas de la issue)

- **S1** `upsertSyncItem` (backend/internal/adapters/repositories/postgres/task_repository.go) deja de confiar en el Save-by-PK de asociaciones de GORM: la fila de tarea se guarda con `Omit(clause.Associations)` y las subtareas se reconcilian EXPLÍCITAMENTE cuando `incoming.SubTasks != nil` (nil = no provistas → intactas, regla vigente de `Upsert`):
  - fila entrante con PK ∈ subtasks de ESTA tarea → UPDATE title/isFinished;
  - fila entrante sin PK → match por contenido (task_id + título coalesced) → UPDATE si existe, INSERT si no (mata la duplicación de clientes que olvidan el id);
  - PK de OTRA tarea → jamás se toca (guard IDOR Save-by-PK) → tratada como sin-PK;
  - subtareas existentes NO matcheadas → DELETE (borrado de ausentes; mata la resurrección en el pull siguiente);
  - tras rechazo LWW no se toca nada (return previo).
- **S2** comentario falso corregido: sync_service.go:187 no dice que Sync «handles subtask replacement» (esa regla vive en repo.Upsert, no en la ruta sync).
- **S3** tests backend: test DB gated (`TASK_TEST_DATABASE_URL`, patrón task_sync_dates_db_test.go) cubriendo (a) cliente que envía ids → update in-place sin duplicar; (b) cliente que OLVIDA ids → match por contenido, cero duplicados; (c) subtarea ausente en el cliente → borrada; (d) SubTasks nil → intactas; (e) subtarea con PK ajena → no cruzada; (f) LWW reject → subtareas intactas.
- **S4** web: el push se difiere mientras haya un pull en vuelo (una única cola: el push pendiente se re-programa al terminar el pull; no hay push y pull simultáneos en el orquestador).
- **S5** web: al pushear tareas, los contadores `focusedSeconds*` se computan de las sesiones locales web (mismo patrón que los teléfonos) en vez de espejar el valor obsoleto del snapshot; el pull sigue siendo la verdad para contadores remotos.
- **S6** sin cambios de contrato (`contracts/openapi.yaml` intacto — payload igual), sin migraciones, gates/pagos intactos. `make test-backend` + `pnpm test` + `pnpm check` verdes.

## Corte

Un PR (size:m estimado ~300-400 líneas con tests). Si el diff supera ~400 líneas → judgment-day dual (toca sync = riesgo ítem 3/4 de CHECKPOINTS; con <400 → juez único).

## Allowed edit surfaces

- `backend/internal/adapters/repositories/postgres/task_repository.go` (upsertSyncItem + helper de reconciliación)
- `backend/internal/services/sync_service.go` (comentario)
- `backend/internal/adapters/repositories/postgres/task_sync_dates_db_test.go` · `backend/internal/adapters/repositories/postgres/task_sync_subtasks_db_test.go` (nuevo)
- `backend/internal/services/sync_service_test.go` (si existe, mocks de repo)
- `web/src/lib/data/sync/**` (mapper/merge de contadores) · `web/src/lib/stores/auth.svelte.ts` (orquestador push/pull — vive en stores, no en data/sync) · `web/tests/unit/sync-counters.test.ts` (nuevo)

## Tasks

- **T1**: fix backend S1 + comentario S2. RED→GREEN con test DB S3 (scratch local `pepinillo_998_scratch` migrado vía binario API). `go test ./...` verde.
- **T2**: web S4 (defer push durante pull) + S5 (focusedSeconds computados de sesiones al pushear). RED→GREEN vitest.
- **T3**: handoff + jueces (dual si >400 líneas) + PR + CI + merge + cierre issue.

## Gotchas aplicables

- GORM Save con asociaciones: update hijos por PK + RE-INSERTA hijos con PK=0 (verificado contra GORM v1.31 por el juez B de #989) — por eso Omit(clause.Associations).
- Title es *string: match por contenido compara coalesced.
- web i18n/spread no aplica aquí; los tests web de sync viven bajo web/tests/unit/.
- Worktree necesita android/local.properties SOLO para Android (no aplica); backend tests DB necesitan DSN con migraciones 000001..000021 aplicadas.

## Log

- 27-nov **Dual APPROVED ×2 (judgment-day, head 6940042)** — Juez A: mutación backend (row.ID=0 fuera) = PK conflict 23505 observado (guard IDOR load-bearing); mutación web (status invertido) = 3/4 tests caen. Juez B: mutación propia (DELETE de ausentes no-op) = gamma resucita + delta duplica (los 2 defectos de la issue); probe deshechable de títulos duplicados legítimos ×5 escenarios (converge al tamaño entrante sin duplicar); force-insert con PKs ajenas de OTRA tarea → 0 toques + 2 filas frescas locales; comentario S2 verificado frase a frase; id≡syncId verificado en ambos sentidos; sin path de colgado de flag. **Hallazgos adoptados (lote consolidado)**: extracción mecánica de reconcileSyncSubtasks → task_sync_reconcile.go (443+97, presupuesto OK); escrituras muertas (target.Title/IsFinished) fuera; escenario de slice vacío NO-nil en el test DB (borra todas — PASS); S4 refinado: pullAndApply con gate de entrada (rechaza doble resolveMerge), syncNow conduce runPull directo (sin save/restore innecesario), signOut limpia pullThrottle pendiente. **Follow-ups preexistentes → issue #1014** (sync_id '' único global + FOR UPDATE + paridad de redondeo). Gates tras el lote: go test ./... verde con DB, TestTaskSyncSubtasksReconcile PASS (7 escenarios), web 159/159 + check 0 err.
- 27-nov **T1 backend (S1-S3)**: upsertSyncItem guarda la fila con Omit(clause.Associations) y reconcilia subtareas EXPLÍCITAMENTE (reconcileSyncSubtasks): update por PK propia (skip si ya consumida), match por contenido (título coalesced) para filas sin PK, INSERT con PK=0 forzada (una PK foránea jamás se inserta ni se toca — IDOR), DELETE de las no matcheadas, nil = intactas, LWW reject = intactas. Comentario de sync_service corregido (S2). **RED→GREEN con DB real**: stash del fix → by-id push duplicó delta (4 filas vs 3, gamma sin borrar) → pop → PASS con los 6 escenarios (TestTaskSyncSubtasksReconcile). go test ./... COMPLETO verde con TASK_TEST_DATABASE_URL (scratch pepinillo_998_scratch migrado vía binario API con JWT_SECRET dummy; gotcha: el redirect de un comando inexistente traga el error — timeout existe en Darwin 27).
- 27-nov **T2 web (S4-S5)**: pullAndApply ahora sostiene el flag syncing con save/restore y extrae el cuerpo a runPull (hueco de solapamiento: resolveMerge('pull') llamaba sin flag); schedulePull re-arma en vez de descartar si está busy. S5: módulo nuevo data/sync/counters.ts (computeFocusCounters) + wiring en runInitialUpload — contadores derivados de sesiones completadas conocidas (task.id ≡ syncId hace el matcher directo), task sin sesiones conocidas conserva espejo (nunca baja contadores de teléfono no vistos), trackingMode = modo de la última completada. **RED determinista**: test escrito primero → import sin resolver (0 tests) → módulo restaurado → GREEN 4/4. Gotcha: git stash no guarda untracked — RED manual con mv + git checkout --. Gates: web 159/159 + check 0 err.
- 27-nov: labels status:new → status:ready (DoR: criterios concretos heredados de la dual de #989; exclusiones implícitas en la issue — no toca contratos ni migraciones). Worktree pepinillo-wt-998 / feat/998-sync-hardening creado. Artefacto creado. Explorador web en vuelo (orquestador push/pull + focusedSeconds).
