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
