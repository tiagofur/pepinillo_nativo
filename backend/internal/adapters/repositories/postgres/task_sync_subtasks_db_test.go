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

// Issue #998 (S1/S3): the sync upsert must reconcile subtasks explicitly —
// update by server id, content-match rows from clients that forget the id
// (no duplicates), delete the rows missing from the incoming list (no
// resurrection), never touch another task's PK (IDOR guard) and leave the
// list untouched when the client omits it or loses the LWW race. Runs only
// when TASK_TEST_DATABASE_URL points at a database with all migrations
// applied (scratch database; the test cleans its own rows).
func TestTaskSyncSubtasksReconcile(t *testing.T) {
	dsn := os.Getenv("TASK_TEST_DATABASE_URL")
	if dsn == "" {
		t.Skip("TASK_TEST_DATABASE_URL not set")
	}
	db, err := gorm.Open(postgres.Open(dsn), &gorm.Config{})
	if err != nil {
		t.Fatal(err)
	}
	ctx := context.Background()
	repo := NewTaskRepository(db)

	userID := "00000000-0000-0000-0000-0000000009e2"
	otherUserID := "00000000-0000-0000-0000-0000000009e3"
	t.Cleanup(func() {
		db.Exec("DELETE FROM users WHERE id IN (?, ?)", userID, otherUserID)
	})
	db.Exec("DELETE FROM users WHERE id IN (?, ?)", userID, otherUserID)
	for id, email := range map[string]string{
		userID:      "task-998@x.test",
		otherUserID: "task-998-other@x.test",
	} {
		if err := db.Exec(
			`INSERT INTO users (id, email, name, created_at) VALUES (?, ?, ?, now())`,
			id, email, "Task 998",
		).Error; err != nil {
			t.Fatal(err)
		}
	}

	now := time.Now().UTC().Truncate(time.Second)
	newTask := func(syncID string) domain.Task {
		return domain.Task{
			SyncID:       syncID,
			UserID:       userID,
			Title:        ptrString989("Sync 998"),
			TrackingMode: "pomodoro",
			UpdatedAt:    now,
		}
	}
	sub := func(title string, finished bool) domain.SubTask {
		return domain.SubTask{Title: ptrString989(title), IsFinished: finished}
	}
	countSubtasks := func(taskID int) int {
		var n int64
		db.Model(&domain.SubTask{}).Where("task_id = ?", taskID).Count(&n)
		return int(n)
	}

	// ── Seed the base task with three subtasks via the sync path itself ──
	seed := newTask("ts998-base")
	seed.SubTasks = []domain.SubTask{sub("alpha", false), sub("beta", false), sub("gamma", false)}
	if _, err := repo.Sync(ctx, userID, []domain.Task{seed}, nil, nil); err != nil {
		t.Fatalf("seed sync: %v", err)
	}
	var seeded domain.Task
	if err := db.Where("user_id = ? AND sync_id = ?", userID, "ts998-base").First(&seeded).Error; err != nil {
		t.Fatal(err)
	}
	if got := countSubtasks(seeded.ID); got != 3 {
		t.Fatalf("seed: want 3 subtasks, got %d", got)
	}
	var alpha, beta domain.SubTask
	var rows []domain.SubTask
	db.Where("task_id = ?", seeded.ID).Order("id").Find(&rows)
	alpha, beta = rows[0], rows[1]

	// ── (a) client sends server ids: in-place update, missing row deleted ──
	push := newTask("ts998-base")
	push.ID = seeded.ID
	push.UpdatedAt = now.Add(time.Minute) // newer → LWW applies
	push.SubTasks = []domain.SubTask{
		{ID: alpha.ID, Title: ptrString989("alpha v2"), IsFinished: false},
		{ID: beta.ID, Title: ptrString989("beta"), IsFinished: true},
		sub("delta", false), // brand new (no id, no content match)
	}
	if _, err := repo.Sync(ctx, userID, []domain.Task{push}, nil, nil); err != nil {
		t.Fatalf("push by id: %v", err)
	}
	rows = nil
	db.Where("task_id = ?", seeded.ID).Order("id").Find(&rows)
	if len(rows) != 3 {
		t.Fatalf("by-id push: want 3 subtasks (gamma deleted), got %d", len(rows))
	}
	if *rows[0].Title != "alpha v2" || rows[0].ID != alpha.ID {
		t.Fatalf("by-id push: alpha row not updated in place: %+v", rows[0])
	}
	if !rows[1].IsFinished {
		t.Fatalf("by-id push: beta not finished: %+v", rows[1])
	}
	if *rows[2].Title != "delta" {
		t.Fatalf("by-id push: delta missing: %+v", rows[2])
	}

	// ── (b) client forgets the ids: content match, zero duplicates ──
	push = newTask("ts998-base")
	push.ID = seeded.ID
	push.UpdatedAt = now.Add(2 * time.Minute)
	push.SubTasks = []domain.SubTask{
		sub("alpha v2", true),
		sub("beta", false),
		sub("delta", true),
	}
	if _, err := repo.Sync(ctx, userID, []domain.Task{push}, nil, nil); err != nil {
		t.Fatalf("push content: %v", err)
	}
	rows = nil
	db.Where("task_id = ?", seeded.ID).Order("id").Find(&rows)
	if len(rows) != 3 {
		t.Fatalf("content push: duplicates! want 3 subtasks, got %d", len(rows))
	}
	if rows[0].ID != alpha.ID || !rows[0].IsFinished {
		t.Fatalf("content push: alpha row not content-matched in place: %+v", rows[0])
	}

	// ── (c) LWW reject: an older push must not touch subtasks ──
	push = newTask("ts998-base")
	push.ID = seeded.ID
	push.UpdatedAt = now // older than the stored stamp → rejected
	push.SubTasks = []domain.SubTask{sub("wipe", false)}
	if res, err := repo.Sync(ctx, userID, []domain.Task{push}, nil, nil); err != nil {
		t.Fatalf("push lww: %v", err)
	} else if len(res.RejectedSyncIDs) != 1 {
		t.Fatalf("push lww: want 1 rejected, got %v", res.RejectedSyncIDs)
	}
	if got := countSubtasks(seeded.ID); got != 3 {
		t.Fatalf("lww reject: subtasks touched! want 3, got %d", got)
	}

	// ── (d) SubTasks omitted (nil): untouched ──
	push = newTask("ts998-base")
	push.ID = seeded.ID
	push.UpdatedAt = now.Add(3 * time.Minute)
	push.SubTasks = nil
	if _, err := repo.Sync(ctx, userID, []domain.Task{push}, nil, nil); err != nil {
		t.Fatalf("push nil: %v", err)
	}
	if got := countSubtasks(seeded.ID); got != 3 {
		t.Fatalf("nil subtasks: list changed! want 3, got %d", got)
	}

	// ── (e) foreign PK: another user's subtask id must never be touched ──
	other := newTask("ts998-other")
	other.UserID = otherUserID
	other.SubTasks = []domain.SubTask{sub("other-alpha", false)}
	if _, err := repo.Sync(ctx, otherUserID, []domain.Task{other}, nil, nil); err != nil {
		t.Fatalf("seed other: %v", err)
	}
	var otherRow domain.Task
	db.Where("user_id = ? AND sync_id = ?", otherUserID, "ts998-other").First(&otherRow)
	var otherSub domain.SubTask
	db.Where("task_id = ?", otherRow.ID).First(&otherSub)

	push = newTask("ts998-base")
	push.ID = seeded.ID
	push.UpdatedAt = now.Add(4 * time.Minute)
	// The (broken) client claims the FOREIGN subtask id with a new title.
	push.SubTasks = []domain.SubTask{sub("hijack", false)}
	push.SubTasks[0].ID = otherSub.ID
	if _, err := repo.Sync(ctx, userID, []domain.Task{push}, nil, nil); err != nil {
		t.Fatalf("push foreign: %v", err)
	}
	var untouched domain.SubTask
	if err := db.Where("id = ?", otherSub.ID).First(&untouched).Error; err != nil {
		t.Fatalf("foreign subtask vanished: %v", err)
	}
	if untouched.TaskID != otherRow.ID || *untouched.Title != "other-alpha" {
		t.Fatalf("foreign subtask was modified: %+v", untouched)
	}
	// And it lands inside THIS task as a fresh row (content found nothing).
	if got := countSubtasks(seeded.ID); got != 1 {
		t.Fatalf("foreign-pk push: want 1 row in task, got %d", got)
	}
}
