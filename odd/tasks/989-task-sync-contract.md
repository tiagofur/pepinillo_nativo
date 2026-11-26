# odd/tasks/989-task-sync-contract.md

Issue: https://github.com/tiagofur/pepinillo_nativo/issues/989
Topología: **Delegated Direct** (multi-unidad: contrato, backend, migración).
Único escritor: implementador de esta sesión.
Base: `main` `a491ee33` · Rama: `feat/989-task-sync-contract` (worktree `pepinillo-wt-989`).

## Specs (S1..Sn)

Mapeados 1:1 de la issue. **Esta entrega cubre S1, S2 y S3** (PR-A de la
cadena documentada en la issue). S4/S5 (iOS+Android), S6 (web) y S7 (fixture
compartido) van en los PR-B y PR-C posteriores.

- **S1 · Contrato (aditivo)**: schema `Task` de `contracts/openapi.yaml`
  declara `dueDate`, `completedAt`, `scheduledForToday`, `sortOrder`;
  `finishDate` marcado `deprecated` con su semántica escrita.
  **Slice de esta entrega (triage):** el criterio original pide
  `energyLevel` como enum cerrado; aquí se documentan los valores canónicos
  con nota de normalización y el enum estricto entra en PR-C, cuando los
  tres clientes normalicen (un enum hoy rompería los payloads vivos de
  Android). `make contracts-lint` OK y `make contracts-diff` sin breaking.
- **S2 · Backend persiste**: una tarea subida a `/api/v1/tasks/sync` o
  `/sync/initial-upload` con `dueDate`, `completedAt`, `scheduledForToday`,
  `sortOrder` y `energyLevel` vuelve con los mismos valores en
  `/sync/full`. Test de repositorio contra base real (patrón guardado por
  env de `internal_stats_repository_test.go`).
- **S3 · Backend normaliza energía**: `energy_level` solo almacena
  `deep|shallow|admin`; `regular`/`light`/`high`/`low`/`medium` se normalizan
  al escribir (misma tabla que `normalizeEnergy` del web). La migración
  normaliza el histórico y añade CHECK.

## Allowed edit surfaces

- `contracts/openapi.yaml`
- `backend/internal/domain/task.go` + `backend/internal/domain/task_test.go` (nuevo)
- `backend/internal/services/task_service.go` + `backend/internal/services/task_service_recurrence_test.go`
- `backend/internal/services/sync_service.go`
- `backend/internal/services/ai_service.go`
- `backend/internal/adapters/repositories/postgres/task_repository.go` + `backend/internal/adapters/repositories/postgres/task_sync_dates_db_test.go` (nuevo)
- `backend/internal/adapters/repositories/postgres/internal_stats_repository.go` (+ `_test.go`)
- `backend/migrations/000020_task_sync_dates.up.sql` (nuevo)
- `backend/migrations/000020_task_sync_dates.down.sql` (nuevo)
- `backend/internal/services/task_recurrence.go` (nuevo — extracción mecánica, ronda 1)
- `backend/internal/services/task_summary.go` (nuevo — costura pura de conteo, ronda 1)
- `backend/internal/services/task_summary_test.go` (nuevo)
- `backend/internal/domain/task_due_date_test.go` (nuevo)
- `odd/tasks/989-task-sync-contract.md`

## Tasks (T1..Tn)

- **T1** (S1, inline): contract-first — schema `Task` + `make contracts-lint`
  + `make contracts-diff`. Risk: item 3 (contrato que otros consumen; aditivo).
  Result: OK (lint 0 errores; diff sin breaking) · Commit: `36f3e6f1`
- **T2** (S2/S3, inline): migración `000020_task_sync_dates` (columnas nuevas
  + backfill con heurística + normalización de energía + CHECK + comments).
  Risk: item 1 (datos). Result: OK (aplica limpia 000001→000020 en BD scratch;
  ensayo de backfill con las 4 formas históricas y `down` verificado)
  · Commit: pendiente
- **T3** (S3, inline): `domain.NormalizeEnergyLevel` + campos nuevos en
  `domain.Task` + normalización en `upsertSyncItem` y `Upsert` + lecturas con
  COALESCE (`ListByFinishDate`, overdue de IA, `completed30d`) + instancias
  recurrentes espejan `dueDate`/`sortOrder`. RED→GREEN. Risk: item 3.
  Result: OK (RED por símbolos ausentes; suite backend 14 paquetes ok)
  · Commit: pendiente
- **T4** (S2, inline): test de repositorio con BD real guardado por env
  (`TASK_TEST_DATABASE_URL`), round-trip de los 5 campos + normalización +
  `ListByFinishDate` con fila legacy. Result: OK (PASS contra BD scratch con
  migraciones aplicadas; SKIP sin env, seguro para CI) · Commit: pendiente
- **T5** (verificación V2): `make test`, `make contracts-lint`,
  `make contracts-diff`; handoff + judgment-day dual (obligatorio: toca
  `contracts/**` y migraciones) + PR. Result: en curso

## Decisions Made Without Asking (triage de las decisiones abiertas de la issue)

1. **Corte confirmado**: PR-A = contrato + backend + migración (esta entrega,
   retrocompatible; Android ya envía los campos y empieza a persistir sin
   cambios de cliente). PR-B = iOS + Android. PR-C = web + S7.
2. **Backfill por heurística (ventana simétrica, corregida en ronda 1)**:
   `due_date := finish_date` en filas no terminadas; en terminadas, solo
   cuando `finish_date` cae FUERA de una ventana de ±1 hora alrededor de
   `updated_at` (ambos lados acotados: iOS completada antes del vencimiento
   tiene `finish_date` futuro y conserva su `due_date`).
   `completed_at := finish_date` en terminadas con `finish_date` dentro de
   la ventana (recupera el histórico de Android). Residual documentado en
   la migración: Android terminada y editada >1 h después recibe un
   vencimiento fantasma — inofensivo (todas las lecturas COALESCEan) y
   auto-reparable con el primer push de PR-B.
3. **`energyLevel` en el contrato**: descripción con valores canónicos y
   nota de normalización; enum estricto se añade en PR-C cuando los tres
   clientes normalicen (evita breaking en `contracts-diff`).
4. **Limitación conocida y temporal**: hasta PR-B, iOS sigue sin enviar
   `dueDate`/`completedAt`; si gana el LWW sobre una tarea, borra esas
   columnas (fila completa). Hoy esas columnas ni existían: estrictamente
   mejor, se cierra con PR-B encadenado.

## Log

- 2026-11-25: issue #989 triageada (status:new → in-progress). Artefacto
  creado. PR-A iniciado en worktree.
- 2026-11-25 (ronda 1 judgment-day): Juez A CHANGES_REQUESTED — P0: la
  ventana de backfill de `completed_at` no acotaba el lado futuro (iOS
  completada antes del vencimiento recibía `completed_at` inventado y
  perdía `due_date`); P1: faltaban tests de regresión de las lecturas
  convertidas (completed30d, overdue). Juez B APPROVED con los mismos
  hallazgos como P2 (misma ventana, presupuesto de líneas, S1 del
  artefacto). Lote único de fixes: ventana simétrica con residual
  documentado (vencimiento fantasma Android editada >1 h), costura pura
  `countTaskStates` testeable, `domain.TaskDueDate` exportada, energía
  vacía → shallow (alineada con web y migración), offset due-aware en
  instancias, `pickTaskDay` vía `TaskDueDate`, wording del contrato,
  extracción mecánica verbatim a `task_recurrence.go` (task_service
  549→361), S1 del artefacto marca el slice del enum, superficies con
  rutas completas. Re-ensayo de backfill con las 5 formas (incl. la del
  P0): PASS. Deuda señalada (no bloqueante): `ai_service.go` (743 líneas)
  sobre presupuesto — seguimiento #995.
- 2026-11-25 (ronda 2 judgment-day): Juez A CHANGES_REQUESTED — P1: el
  assert de `completed30d` no discriminaba (la fila new-shape con
  `finish_date` a -5d seguía contando tras un revert del COALESCE);
  Juez B CHANGES_REQUESTED — P0 de proceso: tres archivos de trabajo
  (handoff, pr-body, verification) quedaron commiteados en la raíz por un
  `git add -A`, fuera de superficie. Ambos con remedio mecánico
  prescrito. Aplicados SIN reclamar tercera ronda (C4.3: bucle automático
  gastado): `git rm` de los tres (copias en /tmp/pep989/ y worktree sin
  trackear), fila del test a `finish_date = -40d` (discriminación
  verificada mecánicamente en scratch: COALESCE cuenta 1, bare 0),
  residual de frontera ±1 h anotado en la migración, cuerpo del PR
  refrescado, deuda ai_service → #995. Estado: **needs-human** — la
  re-revisión final acotada requiere autorización del leader.

## PR-B (T6..T8) — feat/989-clients-canonical-fields, base main 3f33b39d

Allowed edit surfaces adicionales:
- `android/app/src/main/java/dev/creapolis/pepinillo/core/network/ApiModels.kt`
- `android/app/src/main/java/dev/creapolis/pepinillo/data/sync/SyncEngine.kt`
- `android/app/src/main/java/dev/creapolis/pepinillo/data/sync/InitialSyncManager.kt`
- `android/app/src/test/java/dev/creapolis/pepinillo/data/sync/TaskCanonicalFieldsSyncTest.kt` (nuevo)
- `android/local.properties` (sin trackear, copia del SDK)
- `ios/Domain/Models/APIDTOs.swift`
- `ios/Domain/Clients/SyncClient.swift`
- `ios/Shared/Persistence/SwiftDataPersistenceService.swift`
- `ios/Tests/IntegrationTests/PersistenceServiceTests.swift`
- `.github/workflows/android-test.yml` (una línea: test nuevo al subset CI)

- **T6** (S5): Android canónico. Result: OK (RED por campo ausente; 3 tests
  nuevos + paquetes sync/repository en verde, 17 clases re-ejecutadas)
  · Commit: `524ea8f8`
- **T7** (S4): iOS canónico. Result: OK (RED por init sin campos; 21/21
  PersistenceServiceTests + SyncClientTests verde) · Commit: `a0fae892`
- **T8** (verificación V1/V2 + handoff + judgment-day): ronda 1 dual —
  Juez A CHANGES_REQUESTED (2 P1: payload de sync sin fallback de due para
  el cohort residual del backfill; InitialSyncManager sin tests — que
  además destapó que el restore descartaba due/hoy/orden) · Juez B APPROVED.
  Fixes: `applyDueDateFallback` en los 4 sitios de lectura + aserción en el
  test BD real (RED en scratch) · restore de InitialSyncManager mapea los
  campos + test de restore con decoy (no-tautología demostrada por stash).
  Re-revisión acotada (ronda 2): APPROVED dual · Commits: `4b01be09`, `34abd1c7`

## PR-C (T9..T11) — feat/989-web-canonical-fixture, base main 5689b203

Allowed edit surfaces adicionales:
- `web/src/lib/data/remote/types.ts`
- `web/src/lib/data/sync/mappers.ts`
- `web/src/lib/domain/entities/types.ts`
- `web/tests/unit/sync-mappers.test.ts` / `sync-merge.test.ts` / `task-fixture.test.ts` (nuevo)
- `contracts/fixtures/task-canonical-989.json` (nuevo)
- `backend/internal/domain/task_fixture_test.go` (nuevo)
- `android/app/src/test/java/dev/creapolis/pepinillo/data/sync/TaskCanonicalFixtureTest.kt` (nuevo)
- `ios/Tests/IntegrationTests/PersistenceServiceTests.swift`
- `contracts/openapi.yaml` (descripción energyLevel)

- **T9** (S6): web canónico. Result: OK (RED 3 tests; 143/143 suite web;
  check 0 errores; build OK) · Commit: `fac5bd05`
- **T10** (S7): fixture compartido + tests backend/Android/iOS/web.
  Result: OK (go + gradle + xcodebuild 22/22 + vitest) · Commit: `6a46732e`
- **T11** (S1 slice de enum): oasdiff marca request-enum breaking (clientes
  sin actualizar) → decisión documentada en el contrato: enum diferido
  detrás de contract-break o split request/response. Result: OK (lint 0
  errores, diff sin breaking) · Commit: `cf0a0493`

## PR-C judgment-day (ronda 1 + ronda 2)

- **Ronda 1**: Juez A APPROVED (P2: asimetría de borrado de última
  subtarea desde web + tests TZ-frágiles; P3: comentario ±12h + guard
  muerto) · Juez B CHANGES_REQUESTED — **P1 real**: subtareas sin ids por
  el único push path de web (`/sync/initial-upload` → `upsertSyncItem`) →
  el association save de GORM re-inserta hijos de PK-cero → duplicados
  propagados a todos los clientes (verificó source de GORM v1.31;
  pre-existente vía iOS, rutinario para web).
- **Lote único de fixes**: `9e11299b` (mapper manda `srv-<id>` como id;
  RED por stash: `[undefined, undefined]` vs `[7, 8]`; merge-tie vía
  mapper real; aserciones TZ-stables; comentario ±12h honesto) +
  `9e77b877` (guardia BD: pushes repetidos de una subtarea con id
  conocido no duplican; guard muerto fuera).
- **Ronda 2 (scoped)**: **APPROVED dual, 0 P0/P1** — ambos jueces
  re-ejecutaron gates (web 143, backend ok, contracts limpios).
  Deudas documentadas → issue follow-up (hardening `upsertSyncItem`,
  ventana LWW de contadores web, `focusedSeconds` no se acumula en web).
