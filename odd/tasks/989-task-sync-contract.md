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
  `energyLevel` con valores canónicos documentados; `finishDate` marcado
  `deprecated` con su semántica escrita. `make contracts-lint` OK y
  `make contracts-diff` sin breaking.
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
- `backend/migrations/000020_task_sync_dates.up.sql` / `.down.sql` (nuevos)
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
2. **Backfill por heurística**: `due_date := finish_date` en filas no
   terminadas, y en terminadas solo cuando `finish_date` NO está a menos de
   1 hora de `updated_at` (Android sella `completedAt` justo antes de subir;
   iOS conserva el vencimiento aunque esté cerca). `completed_at :=
   finish_date` en terminadas con `finish_date` a menos de 1 hora de
   `updated_at` (recupera el histórico de Android). Razonamiento en el PR.
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
