# Clean-Context Review Bundle — Issue #989

> **Context Isolation Notice**: This packet is generated deterministically from git state.
> Do NOT read the implementer's conversation history. Evaluate strictly against the
> Issue acceptance criteria, Hierarchy of Truth (`AGENTS.md`), and `CHECKPOINTS.md`.

## Pinned Identity
- **Issue**: `#989`
- **Base SHA**: `a491ee331b2b14c24301cca95854ce545ef4a4bf`
- **Head SHA**: `7e2a7ed7be293933118d46bef49ec9eeac5e99b6`
- **Scope Digest (SHA-256)**: `77a98d55bd2e5e786166f5f70f14bd94be7aa49ec6fbbae13bd14559109a1ac2`
- **Changed Lines**: `497` (review budget: 400)
- **Blind Dual Review (`judgment-day`) Required**: `True`

## High-Risk Triggers
- `high-risk-keyword:backend/migrations/000020_task_sync_dates.down.sql`
- `high-risk-keyword:backend/migrations/000020_task_sync_dates.up.sql`
- `sensitive-surface:contracts/openapi.yaml`
- `size-exception:497 changed lines > 400`

## Acceptance Criteria (source: `task:odd/tasks/989-task-sync-contract.md`)
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

## Allowed Edit Surfaces
- `contracts/openapi.yaml`
- `backend/internal/domain/task.go`
- `backend/internal/domain/task_test.go`
- `backend/internal/services/task_service.go`
- `backend/internal/services/task_service_recurrence_test.go`
- `backend/internal/services/sync_service.go`
- `backend/internal/services/ai_service.go`
- `backend/internal/adapters/repositories/postgres/task_repository.go`
- `backend/internal/adapters/repositories/postgres/task_sync_dates_db_test.go`
- `backend/internal/adapters/repositories/postgres/internal_stats_repository.go`
- `_test.go`
- `backend/migrations/000020_task_sync_dates.up.sql`
- `.down.sql`
- `odd/tasks/989-task-sync-contract.md`

## Files Outside Allowed Edit Surfaces
- ⚠️ `backend/migrations/000020_task_sync_dates.down.sql`

## Observed Verification Evidence (V0/V1/V2)
```text
# Verification Evidence — issue #989 PR-A (feat/989-task-sync-contract)

Fecha: 2026-11-25 · Worktree: /Users/tiagofur/dev/pepinillo-wt-989 · Base: a491ee33 (origin/main)

## V2 — Contratos (C2)

1. `make contracts-lint` (tras editar contracts/openapi.yaml):
   → 90 problems (0 errors, 90 warnings) — warnings preexistentes de operation-description; 0 errores.
2. `make contracts-diff` (oasdiff contra origin/main):
   → "No breaking changes to report, but the specs are different." (aditivo)

## V1 — RED→GREEN (C3)

3. RED observado antes de implementar:
   `go test ./internal/domain/ ./internal/services/` (en backend/)
   → build failed: `template.SortOrder undefined`, `instance.CompletedAt undefined`,
   `instance.ScheduledForToday undefined`, `plain.DueDate undefined`,
   `NormalizeEnergyLevel` inexistente. Fallo determinista por la razón esperada
   (campos/helper aún no declarados).
4. GREEN tras implementar:
   `go build ./... && go test ./internal/domain/ ./internal/services/ ./internal/adapters/repositories/postgres/`
   → ok en los 3 paquetes.

## V2 — Suite y BD real (C3)

5. Suite completa backend: `go test ./...` → 14 paquetes ok, 0 FAIL.
6. `make test` (guardrails de factoría + suite backend) → OK.
7. Test de repositorio contra BD real (nuevo, guardado por env):
   - BD scratch `pepinillo_989_scratch`: migraciones 000001..000020 aplicadas
     en orden con psql (ON_ERROR_STOP=1) — todas OK; columnas due_date,
     completed_at, scheduled_for_today, sort_order y constraint
     chk_tasks_energy_level verificadas en information_schema/pg_constraint.
   - `TASK_TEST_DATABASE_URL=postgres://localhost/pepinillo_989_scratch?sslmode=disable go test -run TestTaskSyncPersistsAndNormalizesNewFields -v`
     → PASS (round-trip de dueDate/completedAt/scheduledForToday/sortOrder;
     energía Regular→admin, Light→shallow, urgent→shallow; ListByFinishDate
     encuentra fila canónica y fila legacy via COALESCE).
   - Sin env: `--- SKIP` (seguro para CI).
8. Ensayo del backfill (BD scratch #2, migraciones hasta 000019, filas sintéticas):
   - iOS terminada (finish lejano a updated_at): due_date := finish_date; completed_at NULL ✓
   - Android terminada (finish ≈ updated_at): completed_at := finish_date; due_date NULL ✓ (sin vencimiento inventado)
   - iOS no terminada con finish: due_date := finish_date ✓
   - Android no terminada (finish NULL): columnas NULL ✓
   - Energías legadas: low→admin, Hobby→shallow, Regular→admin ✓
   - `000020_task_sync_dates.down.sql`: deja 0 columnas nuevas (estado 000019) ✓
9. BDs scratch eliminadas tras la evidencia (dropdb pepinillo_989_scratch, pepinillo_989_backfill_scratch).

Risk: item 1 (migración con backfill sobre datos existentes) — mitigado con
ensayo up/down en BD scratch y down migration simétrica; item 3 (contrato que
otros consumen) — cambio estrictamente aditivo verificado con oasdiff.
```

## Changed Files
- `backend/internal/adapters/repositories/postgres/internal_stats_repository.go`
- `backend/internal/adapters/repositories/postgres/task_repository.go`
- `backend/internal/adapters/repositories/postgres/task_sync_dates_db_test.go`
- `backend/internal/domain/task.go`
- `backend/internal/domain/task_test.go`
- `backend/internal/services/ai_service.go`
- `backend/internal/services/task_service.go`
- `backend/internal/services/task_service_recurrence_test.go`
- `backend/migrations/000020_task_sync_dates.down.sql`
- `backend/migrations/000020_task_sync_dates.up.sql`
- `contracts/openapi.yaml`
- `odd/tasks/989-task-sync-contract.md`

## Diff Stat
```text
.../postgres/internal_stats_repository.go          |   2 +-
 .../repositories/postgres/task_repository.go       |  11 +-
 .../postgres/task_sync_dates_db_test.go            | 147 +++++++++++++++++++++
 backend/internal/domain/task.go                    |  46 ++++++-
 backend/internal/domain/task_test.go               |  47 +++++++
 backend/internal/services/ai_service.go            |   4 +-
 backend/internal/services/task_service.go          |  22 ++-
 .../services/task_service_recurrence_test.go       |  42 ++++++
 backend/migrations/000020_task_sync_dates.down.sql |  12 ++
 backend/migrations/000020_task_sync_dates.up.sql   |  53 ++++++++
 contracts/openapi.yaml                             |  24 ++++
 odd/tasks/989-task-sync-contract.md                |  87 ++++++++++++
 12 files changed, 487 insertions(+), 10 deletions(-)
```

## Full Diff
```diff
diff --git a/backend/internal/adapters/repositories/postgres/internal_stats_repository.go b/backend/internal/adapters/repositories/postgres/internal_stats_repository.go
index b413de3d..7c71154a 100644
--- a/backend/internal/adapters/repositories/postgres/internal_stats_repository.go
+++ b/backend/internal/adapters/repositories/postgres/internal_stats_repository.go
@@ -79,7 +79,7 @@ GROUP BY 1, 2`, d30).Scan(&rows).Error; err != nil {
 	var t struct{ Created30d, Completed30d int64 }
 	if err := db.Raw(`
 SELECT COUNT(*) FILTER (WHERE t.created_date >= ?) AS created30d,
-  COUNT(*) FILTER (WHERE t.is_finished AND NOT t.is_deleted AND t.finish_date >= ?) AS completed30d
+  COUNT(*) FILTER (WHERE t.is_finished AND NOT t.is_deleted AND COALESCE(t.completed_at, t.finish_date) >= ?) AS completed30d
 FROM tasks t JOIN users u ON u.id = t.user_id WHERE u.metrics_opt_in`, d30, d30).Scan(&t).Error; err != nil {
 		return nil, err
 	}
diff --git a/backend/internal/adapters/repositories/postgres/task_repository.go b/backend/internal/adapters/repositories/postgres/task_repository.go
index da8d2c62..f9766040 100644
--- a/backend/internal/adapters/repositories/postgres/task_repository.go
+++ b/backend/internal/adapters/repositories/postgres/task_repository.go
@@ -111,9 +111,11 @@ func (r *TaskRepository) ReleaseRecurrenceLock(ctx context.Context, lockKey, own
 
 func (r *TaskRepository) ListByFinishDate(ctx context.Context, userID string, date time.Time) ([]domain.Task, error) {
 	var tasks []domain.Task
+	// Issue #989: due_date is the canonical carrier; finish_date remains the
+	// legacy fallback for rows written before migration 000020 normalized it.
 	err := r.db.WithContext(ctx).
 		Preload("SubTasks").
-		Where("user_id = ? AND finish_date::date = ?", userID, date.Format("2006-01-02")).
+		Where("user_id = ? AND COALESCE(due_date, finish_date)::date = ?", userID, date.Format("2006-01-02")).
 		Order("updated_at DESC").
 		Find(&tasks).Error
 	if err != nil {
@@ -123,6 +125,9 @@ func (r *TaskRepository) ListByFinishDate(ctx context.Context, userID string, da
 }
 
 func (r *TaskRepository) Upsert(ctx context.Context, task *domain.Task) error {
+	// Issue #989: same energy normalization as the sync path so every write
+	// entry point produces canonical values.
+	task.EnergyLevel = domain.NormalizeEnergyLevel(task.EnergyLevel)
 	return r.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
 		// IDOR guard: when the client supplies an ID, verify the existing row
 		// belongs to the same user before allowing an UPDATE-by-PK via Save.
@@ -192,6 +197,10 @@ const taskSyncChunkSize = 200
 // transactions. incoming is passed by value: caller slices are never mutated.
 func (r *TaskRepository) upsertSyncItem(tx *gorm.DB, userID string, incoming domain.Task, now time.Time, applied, rejected *[]string) error {
 	incoming.UserID = userID
+	// Issue #989: clients shipped different energy vocabularies (Android
+	// Deep/Regular/Light, web legacy low/medium/high). Normalize on write so
+	// chk_tasks_energy_level only ever sees canonical values.
+	incoming.EnergyLevel = domain.NormalizeEnergyLevel(incoming.EnergyLevel)
 	// Sync clients may omit tracking_mode (e.g. the web mapper pre-W9): an
 	// invalid value would violate chk_tasks_tracking_mode on UPDATE (GORM
 	// writes the raw string on full-row Save — the column default only helps
diff --git a/backend/internal/adapters/repositories/postgres/task_sync_dates_db_test.go b/backend/internal/adapters/repositories/postgres/task_sync_dates_db_test.go
new file mode 100644
index 00000000..bfd23ad2
--- /dev/null
+++ b/backend/internal/adapters/repositories/postgres/task_sync_dates_db_test.go
@@ -0,0 +1,147 @@
+package postgres
+
+import (
+	"context"
+	"os"
+	"testing"
+	"time"
+
+	"gorm.io/driver/postgres"
+	"gorm.io/gorm"
+
+	"pepinillo/backend/internal/domain"
+)
+
+// Issue #989 (S2): the task sync upsert must persist the fields the contract
+// now declares (dueDate, completedAt, scheduledForToday, sortOrder) and
+// normalize legacy energy values on write. Runs only when
+// TASK_TEST_DATABASE_URL points at a database with all migrations applied
+// (use a scratch database; the test inserts and removes its own rows).
+func TestTaskSyncPersistsAndNormalizesNewFields(t *testing.T) {
+	dsn := os.Getenv("TASK_TEST_DATABASE_URL")
+	if dsn == "" {
+		t.Skip("TASK_TEST_DATABASE_URL not set")
+	}
+	db, err := gorm.Open(postgres.Open(dsn), &gorm.Config{})
+	if err != nil {
+		t.Fatal(err)
+	}
+
+	userID := "00000000-0000-0000-0000-0000000009e1"
+	t.Cleanup(func() { db.Exec("DELETE FROM users WHERE id = ?", userID) })
+	db.Exec("DELETE FROM users WHERE id = ?", userID)
+	if err := db.Exec(
+		`INSERT INTO users (id, email, name, created_at) VALUES (?, ?, ?, now())`,
+		userID, "task-989@x.test", "Task 989",
+	).Error; err != nil {
+		t.Fatal(err)
+	}
+
+	now := time.Now().UTC().Truncate(time.Second)
+	// Fixed calendar day so ListByFinishDate can target it below.
+	due := time.Date(2026, 11, 20, 9, 0, 0, 0, time.UTC)
+	completed := now.Add(-time.Hour)
+
+	tasks := []domain.Task{
+		{
+			SyncID:             "td989-due",
+			UserID:             userID,
+			Title:              ptrString989("Planned"),
+			EnergyLevel:        ptrString989("Regular"), // Android legacy → admin
+			DueDate:            &due,
+			CompletedAt:        &completed,
+			ScheduledForToday:  true,
+			SortOrder:          3,
+			TrackingMode:       "pomodoro",
+			UpdatedAt:          now,
+		},
+		{
+			SyncID:       "td989-light",
+			UserID:       userID,
+			Title:        ptrString989("Light legacy"),
+			EnergyLevel:  ptrString989("Light"), // Android legacy → shallow
+			TrackingMode: "pomodoro",
+			UpdatedAt:    now,
+		},
+		{
+			SyncID:       "td989-unknown",
+			UserID:       userID,
+			Title:        ptrString989("Unknown vocab"),
+			EnergyLevel:  ptrString989("urgent"), // unknown → shallow
+			TrackingMode: "pomodoro",
+			UpdatedAt:    now,
+		},
+	}
+
+	repo := NewTaskRepository(db)
+	if _, err := repo.Sync(context.Background(), userID, tasks, nil, nil); err != nil {
+		t.Fatal(err)
+	}
+	t.Cleanup(func() { db.Exec("DELETE FROM tasks WHERE sync_id LIKE 'td989-%'") })
+
+	got, err := repo.ListByUser(context.Background(), userID)
+	if err != nil {
+		t.Fatal(err)
+	}
+	bySync := map[string]domain.Task{}
+	for _, task := range got {
+		bySync[task.SyncID] = task
+	}
+
+	planned, ok := bySync["td989-due"]
+	if !ok {
+		t.Fatalf("synced task with new fields missing from ListByUser")
+	}
+	if planned.DueDate == nil || !planned.DueDate.Equal(due) {
+		t.Fatalf("dueDate round-trip failed: want %v, got %v", due, planned.DueDate)
+	}
+	if planned.CompletedAt == nil || !planned.CompletedAt.Equal(completed) {
+		t.Fatalf("completedAt round-trip failed: want %v, got %v", completed, planned.CompletedAt)
+	}
+	if !planned.ScheduledForToday {
+		t.Fatalf("scheduledForToday did not survive the sync round-trip")
+	}
+	if planned.SortOrder != 3 {
+		t.Fatalf("sortOrder did not survive the sync round-trip: want 3, got %d", planned.SortOrder)
+	}
+	if planned.EnergyLevel == nil || *planned.EnergyLevel != "admin" {
+		t.Fatalf("legacy energy %q must normalize to admin, got %v", "Regular", planned.EnergyLevel)
+	}
+
+	if light := bySync["td989-light"]; light.EnergyLevel == nil || *light.EnergyLevel != "shallow" {
+		t.Fatalf("legacy energy %q must normalize to shallow, got %v", "Light", light.EnergyLevel)
+	}
+	if unknown := bySync["td989-unknown"]; unknown.EnergyLevel == nil || *unknown.EnergyLevel != "shallow" {
+		t.Fatalf("unknown energy %q must normalize to shallow, got %v", "urgent", unknown.EnergyLevel)
+	}
+
+	// ListByFinishDate is the "tasks on this day" read: after #989 it must
+	// resolve through COALESCE(due_date, finish_date), so both a canonical
+	// row and a legacy row (pre-backfill shape: due NULL, finish set) match.
+	day := time.Date(2026, 11, 20, 0, 0, 0, 0, time.UTC)
+	legacy := time.Date(2026, 11, 20, 15, 0, 0, 0, time.UTC)
+	if err := db.Exec(
+		`INSERT INTO tasks (sync_id, user_id, title, finish_date, due_date, is_finished, tracking_mode, updated_at)
+		 VALUES ('td989-legacy', ?, 'Legacy row', ?, NULL, false, 'pomodoro', now())`,
+		userID, legacy,
+	).Error; err != nil {
+		t.Fatal(err)
+	}
+
+	found, err := repo.ListByFinishDate(context.Background(), userID, day)
+	if err != nil {
+		t.Fatal(err)
+	}
+	seen := map[string]bool{}
+	for _, task := range found {
+		seen[task.SyncID] = true
+	}
+	if !seen["td989-due"] {
+		t.Fatalf("canonical due_date row missing from ListByFinishDate(%v)", day)
+	}
+	if !seen["td989-legacy"] {
+		t.Fatalf("legacy finish_date row (due_date NULL) missing from ListByFinishDate(%v)", day)
+	}
+}
+
+func ptrString989(v string) *string { return &v }
diff --git a/backend/internal/domain/task.go b/backend/internal/domain/task.go
index 6724820a..3f6da49c 100644
--- a/backend/internal/domain/task.go
+++ b/backend/internal/domain/task.go
@@ -1,6 +1,9 @@
 package domain
 
-import "time"
+import (
+	"strings"
+	"time"
+)
 
 type Task struct {
 	ID                  int        `json:"id" gorm:"primaryKey;autoIncrement"`
@@ -12,10 +15,16 @@ type Task struct {
 	RecurrenceRule      *string    `json:"recurrenceRule"`
 	RecurringTemplateID *string    `json:"recurringTemplateId"`
 	CreatedDate         *time.Time `json:"createdDate"`
-	FinishDate          *time.Time `json:"finishDate"`
-	IsFinished          bool       `json:"isFinished" gorm:"default:false;not null"`
-	Priority            int        `json:"priority" gorm:"default:0;not null"`
-	Category            *string    `json:"category"`
+	FinishDate          *time.Time `json:"finishDate"` // Deprecated carrier (issue #989): Apple sent due dates here, Android completion instants. Superseded by DueDate/CompletedAt; still mirrored for old clients.
+	// Canonical task-model fields (issue #989). Clients kept these locally
+	// until the contract declared them; full-row LWW syncs persist them.
+	DueDate           *time.Time `json:"dueDate"`
+	CompletedAt       *time.Time `json:"completedAt"`
+	ScheduledForToday bool       `json:"scheduledForToday"`
+	SortOrder         int        `json:"sortOrder"`
+	IsFinished        bool       `json:"isFinished" gorm:"default:false;not null"`
+	Priority          int        `json:"priority" gorm:"default:0;not null"`
+	Category          *string    `json:"category"`
 
 	// Legacy Pomodoro fields (for backward compatibility)
 	EstimatedPomodoros int `json:"estimatedPomodoros" gorm:"default:0;not null"`
@@ -48,3 +57,30 @@ func ValidTrackingMode(mode string) bool {
 	}
 	return false
 }
+
+// NormalizeEnergyLevel maps the legacy client vocabularies onto the canonical
+// enum (deep | shallow | admin), mirroring the web mapper
+// (web/src/lib/data/sync/mappers.ts normalizeEnergy): Android shipped
+// Deep/Regular/Light and web legacy used low/medium/high. Canonical values
+// pass through; empty becomes unset; anything unknown fails safe to shallow
+// (never deep — an unrecognized value must not upgrade a task to Deep Work).
+// nil passes through so unset stays unset.
+func NormalizeEnergyLevel(raw *string) *string {
+	if raw == nil {
+		return nil
+	}
+	switch strings.ToLower(strings.TrimSpace(*raw)) {
+	case "deep", "high":
+		return ptrString("deep")
+	case "shallow", "light", "medium":
+		return ptrString("shallow")
+	case "admin", "regular", "low":
+		return ptrString("admin")
+	case "":
+		return nil
+	default:
+		return ptrString("shallow")
+	}
+}
+
+func ptrString(v string) *string { return &v }
diff --git a/backend/internal/domain/task_test.go b/backend/internal/domain/task_test.go
new file mode 100644
index 00000000..0dcd4ca2
--- /dev/null
+++ b/backend/internal/domain/task_test.go
@@ -0,0 +1,47 @@
+package domain
+
+import (
+	"testing"
+)
+
+// Issue #989 (S3): energy_level is free-form text on the wire because three
+// client platforms shipped different vocabularies (Apple: deep/shallow/admin,
+// Android: Deep/Regular/Light, web legacy: low/medium/high). The server must
+// normalize on write so every stored value is canonical.
+func TestNormalizeEnergyLevel(t *testing.T) {
+	s := func(v string) *string { return &v }
+
+	cases := []struct {
+		name string
+		in   *string
+		want *string
+	}{
+		{"nil passes through", nil, nil},
+		{"canonical deep", s("deep"), s("deep")},
+		{"canonical shallow", s("shallow"), s("shallow")},
+		{"canonical admin", s("admin"), s("admin")},
+		{"case and space normalized", s("  DEEP "), s("deep")},
+		{"android light", s("light"), s("shallow")},
+		{"android regular", s("regular"), s("admin")},
+		{"android deep stays", s("Deep"), s("deep")},
+		{"web legacy low", s("low"), s("admin")},
+		{"web legacy medium", s("medium"), s("shallow")},
+		{"web legacy high", s("high"), s("deep")},
+		{"empty becomes nil", s(""), nil},
+		{"unknown fails shallow", s("urgent"), s("shallow")},
+	}
+
+	for _, tc := range cases {
+		t.Run(tc.name, func(t *testing.T) {
+			got := NormalizeEnergyLevel(tc.in)
+			switch {
+			case tc.want == nil && got != nil:
+				t.Fatalf("want nil, got %q", *got)
+			case tc.want != nil && got == nil:
+				t.Fatalf("want %q, got nil", *tc.want)
+			case tc.want != nil && *got != *tc.want:
+				t.Fatalf("want %q, got %q", *tc.want, *got)
+			}
+		})
+	}
+}
diff --git a/backend/internal/services/ai_service.go b/backend/internal/services/ai_service.go
index 0cf20a38..07ea04f2 100644
--- a/backend/internal/services/ai_service.go
+++ b/backend/internal/services/ai_service.go
@@ -175,7 +175,9 @@ func (s *AIService) buildDataSummary(ctx context.Context, userID string, days in
 			summary.CompletedTasks++
 		} else {
 			summary.PendingTasks++
-			if t.FinishDate != nil && t.FinishDate.Before(now) {
+			// Issue #989: overdue resolves through the canonical due date
+			// with the legacy finishDate fallback.
+			if due := taskDueDate(t); due != nil && due.Before(now) {
 				summary.OverdueTasks++
 			}
 		}
diff --git a/backend/internal/services/task_service.go b/backend/internal/services/task_service.go
index a3adb9fd..06dbdf4a 100644
--- a/backend/internal/services/task_service.go
+++ b/backend/internal/services/task_service.go
@@ -62,8 +62,12 @@ func (s *TaskService) ListRecurrences(ctx context.Context, userID string, from,
 			continue
 		}
 
-		if from != nil && item.FinishDate != nil && item.FinishDate.Before(from.UTC()) {
-			continue
+		if from != nil {
+			// Issue #989: resolve the scheduled day through the canonical due
+			// date with the legacy finishDate fallback.
+			if due := taskDueDate(item); due != nil && due.Before(from.UTC()) {
+				continue
+			}
 		}
 		if to != nil && item.CreatedDate != nil && item.CreatedDate.After(to.UTC()) {
 			continue
@@ -456,6 +460,7 @@ func buildRecurringInstance(template domain.Task, day time.Time, now time.Time)
 		IsFinished:          false,
 		Priority:            template.Priority,
 		Category:            category,
+		SortOrder:           template.SortOrder,
 		EstimatedPomodoros:  template.EstimatedPomodoros,
 		CompletedPomodoros:  0,
 		FocusedSeconds:      0,
@@ -467,12 +472,25 @@ func buildRecurringInstance(template domain.Task, day time.Time, now time.Time)
 	if template.CreatedDate != nil && template.FinishDate != nil {
 		offset := template.FinishDate.Sub(*template.CreatedDate)
 		finish := day.Add(offset)
+		// Issue #989: mirror the canonical due date alongside the legacy
+		// finishDate carrier so old and new clients read the same day.
 		instance.FinishDate = &finish
+		instance.DueDate = &finish
 	}
 
 	return instance
 }
 
+// taskDueDate returns the canonical due date of a task, falling back to the
+// legacy finishDate carrier (issue #989 backfill makes them equal for old
+// rows, so this is only a bridge while clients migrate).
+func taskDueDate(t domain.Task) *time.Time {
+	if t.DueDate != nil {
+		return t.DueDate
+	}
+	return t.FinishDate
+}
+
 func ptrTimeTask(v time.Time) *time.Time {
 	return &v
 }
diff --git a/backend/internal/services/task_service_recurrence_test.go b/backend/internal/services/task_service_recurrence_test.go
index 81c3c503..3fe91b38 100644
--- a/backend/internal/services/task_service_recurrence_test.go
+++ b/backend/internal/services/task_service_recurrence_test.go
@@ -205,3 +205,45 @@ func TestTaskServiceGenerateRecurrencesForAllUsers(t *testing.T) {
 		t.Fatalf("expected created=2, got %d", created)
 	}
 }
+
+// Issue #989 (S2/S8): backend-generated recurring instances must carry the
+// canonical due date (mirroring the legacy template offset) and inherit the
+// template's manual order, so the fields the contract now declares survive
+// generation. Old clients keep reading the mirrored finishDate.
+func TestBuildRecurringInstanceMirrorsDueDateAndOrder(t *testing.T) {
+	created := time.Date(2026, 11, 1, 9, 0, 0, 0, time.UTC)
+	finish := created.AddDate(0, 0, 1) // template offset: created → finish is +1 day
+	template := domain.Task{
+		SyncID:      "tpl-989",
+		UserID:      "user-989",
+		CreatedDate: &created,
+		FinishDate:  &finish,
+		SortOrder:   7,
+	}
+	day := time.Date(2026, 11, 20, 9, 0, 0, 0, time.UTC)
+	now := time.Date(2026, 11, 19, 8, 0, 0, 0, time.UTC)
+
+	instance := buildRecurringInstance(template, day, now)
+
+	wantDue := day.Add(finish.Sub(created))
+	if instance.DueDate == nil || !instance.DueDate.Equal(wantDue) {
+		t.Fatalf("instance due date must mirror the template offset (%v), got %v", wantDue, instance.DueDate)
+	}
+	if instance.FinishDate == nil || !instance.FinishDate.Equal(wantDue) {
+		t.Fatalf("legacy finish date must stay mirrored for old clients (%v), got %v", wantDue, instance.FinishDate)
+	}
+	if instance.SortOrder != template.SortOrder {
+		t.Fatalf("instance must inherit template sort order %d, got %d", template.SortOrder, instance.SortOrder)
+	}
+	if instance.CompletedAt != nil || instance.ScheduledForToday {
+		t.Fatalf("fresh instance must not be completed or pinned to today")
+	}
+
+	plain := buildRecurringInstance(domain.Task{SyncID: "tpl-989b", UserID: "user-989"}, day, now)
+	if plain.DueDate != nil {
+		t.Fatalf("template without dates must not produce a due date, got %v", plain.DueDate)
+	}
+	if plain.SortOrder != 0 {
+		t.Fatalf("template without order must produce sort order 0, got %d", plain.SortOrder)
+	}
+}
diff --git a/backend/migrations/000020_task_sync_dates.down.sql b/backend/migrations/000020_task_sync_dates.down.sql
new file mode 100644
index 00000000..640f8f78
--- /dev/null
+++ b/backend/migrations/000020_task_sync_dates.down.sql
@@ -0,0 +1,12 @@
+-- 000020 down: drop the canonical task-model columns and the energy CHECK
+-- (issue #989). The backfilled values are not recoverable from finish_date
+-- alone after this point; the down migration exists for symmetric rollbacks,
+-- not for data preservation.
+
+ALTER TABLE tasks DROP CONSTRAINT IF EXISTS chk_tasks_energy_level;
+ALTER TABLE tasks DROP COLUMN IF EXISTS sort_order;
+ALTER TABLE tasks DROP COLUMN IF EXISTS scheduled_for_today;
+ALTER TABLE tasks DROP COLUMN IF EXISTS completed_at;
+ALTER TABLE tasks DROP COLUMN IF EXISTS due_date;
+
+COMMENT ON COLUMN tasks.energy_level IS 'Task energy classification (deep/shallow/admin/none)';
diff --git a/backend/migrations/000020_task_sync_dates.up.sql b/backend/migrations/000020_task_sync_dates.up.sql
new file mode 100644
index 00000000..c1eede56
--- /dev/null
+++ b/backend/migrations/000020_task_sync_dates.up.sql
@@ -0,0 +1,53 @@
+-- 000020: the Task contract never covered the client task model (issue #989).
+-- Clients kept dueDate, completedAt, scheduledForToday and sortOrder locally,
+-- and finishDate was overloaded: Apple clients sent the due date there while
+-- Android clients sent the completion instant. This migration adds the
+-- canonical columns, backfills them from finish_date with a heuristic, and
+-- normalizes the legacy energy vocabulary before adding a CHECK constraint.
+
+ALTER TABLE tasks ADD COLUMN IF NOT EXISTS due_date TIMESTAMPTZ;
+ALTER TABLE tasks ADD COLUMN IF NOT EXISTS completed_at TIMESTAMPTZ;
+ALTER TABLE tasks ADD COLUMN IF NOT EXISTS scheduled_for_today BOOLEAN NOT NULL DEFAULT FALSE;
+ALTER TABLE tasks ADD COLUMN IF NOT EXISTS sort_order INTEGER NOT NULL DEFAULT 0;
+
+-- Backfill due_date. For unfinished rows finish_date is always a due date
+-- (Android only stamps it when completing). For finished rows the value is
+-- ambiguous: Android-origin rows have finish_date ≈ updated_at (the
+-- completion instant is stamped right before upload); anything further away
+-- is an Apple-origin due date. The 1 hour window tolerates clock skew and
+-- slow uploads.
+UPDATE tasks SET due_date = finish_date
+WHERE finish_date IS NOT NULL
+  AND (NOT is_finished OR finish_date < updated_at - INTERVAL '1 hour');
+
+-- Recover Android-origin completion instants: finished rows whose
+-- finish_date sits within an hour of updated_at are completion stamps.
+UPDATE tasks SET completed_at = finish_date
+WHERE is_finished
+  AND finish_date IS NOT NULL
+  AND finish_date >= updated_at - INTERVAL '1 hour';
+
+-- Normalize the legacy energy vocabulary (Android: Deep/Regular/Light; web
+-- legacy: low/medium/high) onto the canonical enum before adding the CHECK.
+-- Canonical values are left untouched by the WHERE guard; NULL stays NULL;
+-- any other unexpected value fails safe to shallow.
+UPDATE tasks SET energy_level = CASE lower(btrim(energy_level))
+  WHEN 'deep' THEN 'deep'
+  WHEN 'high' THEN 'deep'
+  WHEN 'light' THEN 'shallow'
+  WHEN 'medium' THEN 'shallow'
+  WHEN 'regular' THEN 'admin'
+  WHEN 'low' THEN 'admin'
+  ELSE 'shallow'
+END
+WHERE energy_level IS NOT NULL
+  AND lower(btrim(energy_level)) NOT IN ('deep', 'shallow', 'admin');
+
+ALTER TABLE tasks ADD CONSTRAINT chk_tasks_energy_level
+  CHECK (energy_level IS NULL OR energy_level IN ('deep', 'shallow', 'admin'));
+
+COMMENT ON COLUMN tasks.due_date IS 'When the task is due (canonical). Supersedes the overloaded finish_date (issue #989).';
+COMMENT ON COLUMN tasks.completed_at IS 'When the task was completed; NULL while unfinished (issue #989).';
+COMMENT ON COLUMN tasks.scheduled_for_today IS 'User pinned the task to Today; legacy boolean pending planned_date (issue #989).';
+COMMENT ON COLUMN tasks.sort_order IS 'Manual plan order (drag order) (issue #989).';
+COMMENT ON COLUMN tasks.energy_level IS 'Canonical energy classification: deep | shallow | admin; legacy values normalized on write (issue #989).';
diff --git a/contracts/openapi.yaml b/contracts/openapi.yaml
index db694f24..34c05dcc 100644
--- a/contracts/openapi.yaml
+++ b/contracts/openapi.yaml
@@ -3113,6 +3113,10 @@ components:
           type: ["string", "null"]
         energyLevel:
           type: ["string", "null"]
+          description: >-
+            Canonical values: deep | shallow | admin. Legacy client values
+            (regular, light, low, medium, high) are normalized to the
+            canonical set on write; reads only return canonical values or null.
         recurrenceRule:
           type: ["string", "null"]
         recurringTemplateId:
@@ -3123,6 +3127,26 @@ components:
         finishDate:
           type: ["string", "null"]
           format: date-time
+          deprecated: true
+          description: >-
+            Legacy overloaded carrier: Apple clients historically sent the due
+            date here and Android clients the completion instant. New clients
+            must send dueDate and completedAt instead. The server keeps
+            mirroring writes into this column for old clients.
+        dueDate:
+          type: ["string", "null"]
+          format: date-time
+          description: When the task is due. Canonical replacement for the overloaded finishDate (issue #989).
+        completedAt:
+          type: ["string", "null"]
+          format: date-time
+          description: When the task was completed; null while unfinished (issue #989).
+        scheduledForToday:
+          type: boolean
+          description: User pinned the task to Today ("Añadir a Hoy"); expires client-side per platform rules (issue #989).
+        sortOrder:
+          type: integer
+          description: Manual plan order (drag order), stable per task (issue #989).
         isFinished:
           type: boolean
         priority:
diff --git a/odd/tasks/989-task-sync-contract.md b/odd/tasks/989-task-sync-contract.md
new file mode 100644
index 00000000..d5871ee2
--- /dev/null
+++ b/odd/tasks/989-task-sync-contract.md
@@ -0,0 +1,87 @@
+# odd/tasks/989-task-sync-contract.md
+
+Issue: https://github.com/tiagofur/pepinillo_nativo/issues/989
+Topología: **Delegated Direct** (multi-unidad: contrato, backend, migración).
+Único escritor: implementador de esta sesión.
+Base: `main` `a491ee33` · Rama: `feat/989-task-sync-contract` (worktree `pepinillo-wt-989`).
+
+## Specs (S1..Sn)
+
+Mapeados 1:1 de la issue. **Esta entrega cubre S1, S2 y S3** (PR-A de la
+cadena documentada en la issue). S4/S5 (iOS+Android), S6 (web) y S7 (fixture
+compartido) van en los PR-B y PR-C posteriores.
+
+- **S1 · Contrato (aditivo)**: schema `Task` de `contracts/openapi.yaml`
+  declara `dueDate`, `completedAt`, `scheduledForToday`, `sortOrder`;
+  `energyLevel` con valores canónicos documentados; `finishDate` marcado
+  `deprecated` con su semántica escrita. `make contracts-lint` OK y
+  `make contracts-diff` sin breaking.
+- **S2 · Backend persiste**: una tarea subida a `/api/v1/tasks/sync` o
+  `/sync/initial-upload` con `dueDate`, `completedAt`, `scheduledForToday`,
+  `sortOrder` y `energyLevel` vuelve con los mismos valores en
+  `/sync/full`. Test de repositorio contra base real (patrón guardado por
+  env de `internal_stats_repository_test.go`).
+- **S3 · Backend normaliza energía**: `energy_level` solo almacena
+  `deep|shallow|admin`; `regular`/`light`/`high`/`low`/`medium` se normalizan
+  al escribir (misma tabla que `normalizeEnergy` del web). La migración
+  normaliza el histórico y añade CHECK.
+
+## Allowed edit surfaces
+
+- `contracts/openapi.yaml`
+- `backend/internal/domain/task.go` + `backend/internal/domain/task_test.go` (nuevo)
+- `backend/internal/services/task_service.go` + `backend/internal/services/task_service_recurrence_test.go`
+- `backend/internal/services/sync_service.go`
+- `backend/internal/services/ai_service.go`
+- `backend/internal/adapters/repositories/postgres/task_repository.go` + `backend/internal/adapters/repositories/postgres/task_sync_dates_db_test.go` (nuevo)
+- `backend/internal/adapters/repositories/postgres/internal_stats_repository.go` (+ `_test.go`)
+- `backend/migrations/000020_task_sync_dates.up.sql` / `.down.sql` (nuevos)
+- `odd/tasks/989-task-sync-contract.md`
+
+## Tasks (T1..Tn)
+
+- **T1** (S1, inline): contract-first — schema `Task` + `make contracts-lint`
+  + `make contracts-diff`. Risk: item 3 (contrato que otros consumen; aditivo).
+  Result: OK (lint 0 errores; diff sin breaking) · Commit: `36f3e6f1`
+- **T2** (S2/S3, inline): migración `000020_task_sync_dates` (columnas nuevas
+  + backfill con heurística + normalización de energía + CHECK + comments).
+  Risk: item 1 (datos). Result: OK (aplica limpia 000001→000020 en BD scratch;
+  ensayo de backfill con las 4 formas históricas y `down` verificado)
+  · Commit: pendiente
+- **T3** (S3, inline): `domain.NormalizeEnergyLevel` + campos nuevos en
+  `domain.Task` + normalización en `upsertSyncItem` y `Upsert` + lecturas con
+  COALESCE (`ListByFinishDate`, overdue de IA, `completed30d`) + instancias
+  recurrentes espejan `dueDate`/`sortOrder`. RED→GREEN. Risk: item 3.
+  Result: OK (RED por símbolos ausentes; suite backend 14 paquetes ok)
+  · Commit: pendiente
+- **T4** (S2, inline): test de repositorio con BD real guardado por env
+  (`TASK_TEST_DATABASE_URL`), round-trip de los 5 campos + normalización +
+  `ListByFinishDate` con fila legacy. Result: OK (PASS contra BD scratch con
+  migraciones aplicadas; SKIP sin env, seguro para CI) · Commit: pendiente
+- **T5** (verificación V2): `make test`, `make contracts-lint`,
+  `make contracts-diff`; handoff + judgment-day dual (obligatorio: toca
+  `contracts/**` y migraciones) + PR. Result: en curso
+
+## Decisions Made Without Asking (triage de las decisiones abiertas de la issue)
+
+1. **Corte confirmado**: PR-A = contrato + backend + migración (esta entrega,
+   retrocompatible; Android ya envía los campos y empieza a persistir sin
+   cambios de cliente). PR-B = iOS + Android. PR-C = web + S7.
+2. **Backfill por heurística**: `due_date := finish_date` en filas no
+   terminadas, y en terminadas solo cuando `finish_date` NO está a menos de
+   1 hora de `updated_at` (Android sella `completedAt` justo antes de subir;
+   iOS conserva el vencimiento aunque esté cerca). `completed_at :=
+   finish_date` en terminadas con `finish_date` a menos de 1 hora de
+   `updated_at` (recupera el histórico de Android). Razonamiento en el PR.
+3. **`energyLevel` en el contrato**: descripción con valores canónicos y
+   nota de normalización; enum estricto se añade en PR-C cuando los tres
+   clientes normalicen (evita breaking en `contracts-diff`).
+4. **Limitación conocida y temporal**: hasta PR-B, iOS sigue sin enviar
+   `dueDate`/`completedAt`; si gana el LWW sobre una tarea, borra esas
+   columnas (fila completa). Hoy esas columnas ni existían: estrictamente
+   mejor, se cierra con PR-B encadenado.
+
+## Log
+
+- 2026-11-25: issue #989 triageada (status:new → in-progress). Artefacto
+  creado. PR-A iniciado en worktree.
```
