package services

import (
	"testing"
	"time"

	"pepinillo/backend/internal/domain"
)

// Issue #989 review round 1 (P1): the overdue read path switched to the
// canonical due date with the legacy finishDate fallback. These cases pin
// the behavior without a database: an unfinished task with a past due date
// (Apple-origin, any carrier) is overdue; a future due date is not; a
// finished Android-origin row never counts as overdue; deleted rows vanish.
func TestCountTaskStates(t *testing.T) {
	now := time.Date(2026, 11, 25, 12, 0, 0, 0, time.UTC)
	yesterday := now.Add(-24 * time.Hour)
	tomorrow := now.Add(24 * time.Hour)
	weekAgo := now.Add(-7 * 24 * time.Hour)

	ptrStr := func(v string) *string { return &v }

	tasks := []domain.Task{
		// Unfinished, past due on the canonical carrier → overdue.
		{SyncID: "a", DueDate: &yesterday},
		// Unfinished, past due only on the legacy carrier (pre-backfill row) → overdue.
		{SyncID: "b", FinishDate: &yesterday},
		// Unfinished, due tomorrow (completed-early shape) → pending, not overdue.
		{SyncID: "c", DueDate: &tomorrow},
		// Android-origin finished row (completion instant as legacy finish) → completed, never overdue.
		{SyncID: "d", IsFinished: true, FinishDate: &weekAgo, CompletedAt: &weekAgo},
		// Unfinished without any date → pending.
		{SyncID: "e"},
		// Deleted rows are invisible.
		{SyncID: "f", IsDeleted: true, DueDate: &yesterday},
		// Category bookkeeping rides along.
		{SyncID: "g", Category: ptrStr("trabajo")},
	}

	categories := map[string]int{}
	total, completed, pending, overdue := countTaskStates(tasks, now, categories)

	if total != 6 {
		t.Fatalf("total = %d, want 6 (deleted excluded)", total)
	}
	if completed != 1 {
		t.Fatalf("completed = %d, want 1", completed)
	}
	if pending != 5 {
		t.Fatalf("pending = %d, want 5", pending)
	}
	if overdue != 2 {
		t.Fatalf("overdue = %d, want 2 (one per carrier)", overdue)
	}
	if categories["trabajo"] != 1 || categories["sin categoría"] != 5 {
		t.Fatalf("categories = %v, want trabajo:1 + sin categoría:5", categories)
	}
}
