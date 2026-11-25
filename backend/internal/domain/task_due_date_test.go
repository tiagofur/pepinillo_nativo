package domain

import (
	"testing"
	"time"
)

// Issue #989: TaskDueDate is the canonical due-date resolver with the legacy
// finishDate fallback — every server-side read path (recurrence listing, AI
// overdue, statistics) must go through it so pre-backfill and post-PR-B rows
// behave identically.
func TestTaskDueDate(t *testing.T) {
	due := time.Date(2026, 11, 20, 9, 0, 0, 0, time.UTC)
	legacy := time.Date(2026, 11, 10, 9, 0, 0, 0, time.UTC)

	cases := []struct {
		name string
		task Task
		want *time.Time
	}{
		{"both nil", Task{}, nil},
		{"canonical wins", Task{DueDate: &due, FinishDate: &legacy}, &due},
		{"legacy fallback", Task{FinishDate: &legacy}, &legacy},
		{"canonical only", Task{DueDate: &due}, &due},
	}

	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			got := TaskDueDate(tc.task)
			switch {
			case tc.want == nil && got != nil:
				t.Fatalf("want nil, got %v", got)
			case tc.want != nil && got == nil:
				t.Fatalf("want %v, got nil", *tc.want)
			case tc.want != nil && !got.Equal(*tc.want):
				t.Fatalf("want %v, got %v", *tc.want, *got)
			}
		})
	}
}
