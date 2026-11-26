package postgres

import (
	"context"
	"os"
	"testing"
	"time"

	"gorm.io/driver/postgres"
	"gorm.io/gorm"

	"pepinillo/backend/internal/domain"
)

// Issue #989 (S2): the task sync upsert must persist the fields the contract
// now declares (dueDate, completedAt, scheduledForToday, sortOrder) and
// normalize legacy energy values on write. Runs only when
// TASK_TEST_DATABASE_URL points at a database with all migrations applied
// (use a scratch database; the test inserts and removes its own rows).
func TestTaskSyncPersistsAndNormalizesNewFields(t *testing.T) {
	dsn := os.Getenv("TASK_TEST_DATABASE_URL")
	if dsn == "" {
		t.Skip("TASK_TEST_DATABASE_URL not set")
	}
	db, err := gorm.Open(postgres.Open(dsn), &gorm.Config{})
	if err != nil {
		t.Fatal(err)
	}

	userID := "00000000-0000-0000-0000-0000000009e1"
	t.Cleanup(func() { db.Exec("DELETE FROM users WHERE id = ?", userID) })
	db.Exec("DELETE FROM users WHERE id = ?", userID)
	if err := db.Exec(
		`INSERT INTO users (id, email, name, created_at) VALUES (?, ?, ?, now())`,
		userID, "task-989@x.test", "Task 989",
	).Error; err != nil {
		t.Fatal(err)
	}

	now := time.Now().UTC().Truncate(time.Second)
	// Fixed calendar day so ListByFinishDate can target it below.
	due := time.Date(2026, 11, 20, 9, 0, 0, 0, time.UTC)
	completed := now.Add(-time.Hour)

	tasks := []domain.Task{
		{
			SyncID:             "td989-due",
			UserID:             userID,
			Title:              ptrString989("Planned"),
			EnergyLevel:        ptrString989("Regular"), // Android legacy → admin
			DueDate:            &due,
			CompletedAt:        &completed,
			ScheduledForToday:  true,
			SortOrder:          3,
			TrackingMode:       "pomodoro",
			UpdatedAt:          now,
		},
		{
			SyncID:       "td989-light",
			UserID:       userID,
			Title:        ptrString989("Light legacy"),
			EnergyLevel:  ptrString989("Light"), // Android legacy → shallow
			TrackingMode: "pomodoro",
			UpdatedAt:    now,
		},
		{
			SyncID:       "td989-unknown",
			UserID:       userID,
			Title:        ptrString989("Unknown vocab"),
			EnergyLevel:  ptrString989("urgent"), // unknown → shallow
			TrackingMode: "pomodoro",
			UpdatedAt:    now,
		},
	}

	repo := NewTaskRepository(db)
	if _, err := repo.Sync(context.Background(), userID, tasks, nil, nil); err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { db.Exec("DELETE FROM tasks WHERE sync_id LIKE 'td989-%'") })

	got, err := repo.ListByUser(context.Background(), userID)
	if err != nil {
		t.Fatal(err)
	}
	bySync := map[string]domain.Task{}
	for _, task := range got {
		bySync[task.SyncID] = task
	}

	planned, ok := bySync["td989-due"]
	if !ok {
		t.Fatalf("synced task with new fields missing from ListByUser")
	}
	if planned.DueDate == nil || !planned.DueDate.Equal(due) {
		t.Fatalf("dueDate round-trip failed: want %v, got %v", due, planned.DueDate)
	}
	if planned.CompletedAt == nil || !planned.CompletedAt.Equal(completed) {
		t.Fatalf("completedAt round-trip failed: want %v, got %v", completed, planned.CompletedAt)
	}
	if !planned.ScheduledForToday {
		t.Fatalf("scheduledForToday did not survive the sync round-trip")
	}
	if planned.SortOrder != 3 {
		t.Fatalf("sortOrder did not survive the sync round-trip: want 3, got %d", planned.SortOrder)
	}
	if planned.EnergyLevel == nil || *planned.EnergyLevel != "admin" {
		t.Fatalf("legacy energy %q must normalize to admin, got %v", "Regular", planned.EnergyLevel)
	}

	if light := bySync["td989-light"]; light.EnergyLevel == nil || *light.EnergyLevel != "shallow" {
		t.Fatalf("legacy energy %q must normalize to shallow, got %v", "Light", light.EnergyLevel)
	}
	if unknown := bySync["td989-unknown"]; unknown.EnergyLevel == nil || *unknown.EnergyLevel != "shallow" {
		t.Fatalf("unknown energy %q must normalize to shallow, got %v", "urgent", unknown.EnergyLevel)
	}

	// ListByFinishDate is the "tasks on this day" read: after #989 it must
	// resolve through COALESCE(due_date, finish_date), so both a canonical
	// row and a legacy row (pre-backfill shape: due NULL, finish set) match.
	day := time.Date(2026, 11, 20, 0, 0, 0, 0, time.UTC)
	legacy := time.Date(2026, 11, 20, 15, 0, 0, 0, time.UTC)
	if err := db.Exec(
		`INSERT INTO tasks (sync_id, user_id, title, finish_date, due_date, is_finished, tracking_mode, updated_at)
		 VALUES ('td989-legacy', ?, 'Legacy row', ?, NULL, false, 'pomodoro', now())`,
		userID, legacy,
	).Error; err != nil {
		t.Fatal(err)
	}

	found, err := repo.ListByFinishDate(context.Background(), userID, day)
	if err != nil {
		t.Fatal(err)
	}
	seen := map[string]bool{}
	for _, task := range found {
		seen[task.SyncID] = true
	}
	if !seen["td989-due"] {
		t.Fatalf("canonical due_date row missing from ListByFinishDate(%v)", day)
	}
	if !seen["td989-legacy"] {
		t.Fatalf("legacy finish_date row (due_date NULL) missing from ListByFinishDate(%v)", day)
	}

	// Issue #989 PR-B round 1 (P1): sync payloads must emit the resolved due
	// date for the backfill residual cohort (due NULL, finish set — Apple
	// tasks completed within the migration window), or canonical-only clients
	// (which no longer read finishDate) wipe it on pull and lose it forever
	// on the next push.
	all, err := repo.ListByUser(context.Background(), userID)
	if err != nil {
		t.Fatal(err)
	}
	for _, task := range all {
		if task.SyncID == "td989-legacy" && task.DueDate == nil {
			t.Fatalf("sync payload must resolve dueDate through the legacy finish fallback for backfill-residual rows")
		}
	}

	// Issue #989 PR-C round 1 (judge B P1): subtasks pushed WITH server ids
	// must UPDATE in place — GORM's association save re-inserts zero-PK
	// children, so repeated pushes of id-less payloads duplicate the list and
	// the duplicates propagate to every client on pull. Clients now send the
	// ids they pulled; this pins the server side of that contract.
	var dueRow domain.Task
	for _, task := range all {
		if task.SyncID == "td989-due" {
			dueRow = task
		}
	}
	if dueRow.ID == 0 {
		t.Fatalf("td989-due missing for the subtask id guard")
	}
	if err := db.Exec(
		`INSERT INTO subtasks (id, task_id, title, is_finished) VALUES (9001, ?, 'kept', false)`,
		dueRow.ID,
	).Error; err != nil {
		t.Fatal(err)
	}
	subTitle := "kept"
	pushWithKnownSubtask := func() {
		payload := dueRow
		payload.SubTasks = []domain.SubTask{{ID: 9001, TaskID: dueRow.ID, Title: &subTitle, IsFinished: false}}
		if _, err := repo.Sync(context.Background(), userID, []domain.Task{payload}, nil, nil); err != nil {
			t.Fatal(err)
		}
	}
	pushWithKnownSubtask()
	pushWithKnownSubtask()
	var subCount int64
	if err := db.Model(&domain.SubTask{}).Where("task_id = ?", dueRow.ID).Count(&subCount).Error; err != nil {
		t.Fatal(err)
	}
	if subCount != 1 {
		t.Fatalf("repeated pushes of a known-id subtask must not duplicate: count = %d, want 1", subCount)
	}

	// Issue #989 round 1 (P1): completed30d resolves through
	// COALESCE(completed_at, finish_date), so both a new-shape completion
	// (Android origin: completed_at set, finish stale) and a legacy-shape
	// completion (completed_at NULL, finish recent) count within the window.
	ctx := context.Background()
	if err := db.Exec(`UPDATE users SET metrics_opt_in = true WHERE id = ?`, userID).Error; err != nil {
		t.Fatal(err)
	}
	statsRepo := NewInternalStatsRepository(db)
	before, err := statsRepo.Compute(ctx, now)
	if err != nil {
		t.Fatal(err)
	}
	if err := db.Exec(
		`INSERT INTO tasks (sync_id, user_id, title, finish_date, completed_at, is_finished, tracking_mode, updated_at)
		 VALUES
		 ('td989-done-new',    ?, 'New-shape done', now() - interval '40 days', ?, true, 'pomodoro', ?),
		 ('td989-done-legacy', ?, 'Legacy done',    ?,                        NULL,              true, 'pomodoro', now())`,
		userID, now.Add(-time.Hour), now, userID, now.Add(-2*time.Hour),
	).Error; err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { db.Exec("DELETE FROM tasks WHERE sync_id LIKE 'td989-done-%'") })

	after, err := statsRepo.Compute(ctx, now)
	if err != nil {
		t.Fatal(err)
	}
	delta := after.Tasks.Completed30d - before.Tasks.Completed30d
	if delta != 2 {
		t.Fatalf("completed30d must count both completion shapes via COALESCE: delta = %d, want 2", delta)
	}
}

func ptrString989(v string) *string { return &v }
