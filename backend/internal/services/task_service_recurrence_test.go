package services

import (
	"context"
	"errors"
	"testing"
	"time"

	"pepinillo/backend/internal/domain"
	"pepinillo/backend/internal/ports"
)

type fakeTaskRepository struct {
	items          []domain.Task
	lockAcquired   bool
	lockOwner      string
	releaseInvoked int
}

func (f *fakeTaskRepository) GetByID(_ context.Context, _ int) (*domain.Task, error) { return nil, nil }
func (f *fakeTaskRepository) ListByUser(_ context.Context, _ string) ([]domain.Task, error) {
	return f.items, nil
}
func (f *fakeTaskRepository) ListUsersWithRecurrenceTemplates(_ context.Context) ([]string, error) {
	seen := map[string]struct{}{}
	ids := make([]string, 0)
	for _, item := range f.items {
		if item.UserID == "" || item.IsDeleted || item.RecurrenceRule == nil || *item.RecurrenceRule == "" || item.RecurringTemplateID != nil {
			continue
		}
		if _, ok := seen[item.UserID]; ok {
			continue
		}
		seen[item.UserID] = struct{}{}
		ids = append(ids, item.UserID)
	}
	return ids, nil
}
func (f *fakeTaskRepository) TryAcquireRecurrenceLock(_ context.Context, _ string, ownerID string, _ time.Time) (bool, error) {
	if !f.lockAcquired {
		return false, nil
	}
	f.lockOwner = ownerID
	return true, nil
}
func (f *fakeTaskRepository) ReleaseRecurrenceLock(_ context.Context, _ string, ownerID string) error {
	if ownerID == f.lockOwner {
		f.releaseInvoked++
	}
	return nil
}
func (f *fakeTaskRepository) ListByFinishDate(_ context.Context, _ string, _ time.Time) ([]domain.Task, error) {
	return nil, nil
}
func (f *fakeTaskRepository) Upsert(_ context.Context, task *domain.Task) error {
	f.items = append(f.items, *task)
	return nil
}
func (f *fakeTaskRepository) Delete(_ context.Context, _ string, _ int) error { return nil }
func (f *fakeTaskRepository) Sync(_ context.Context, _ string, _ []domain.Task, _ []string, _ *time.Time) (*ports.TaskSyncResult, error) {
	return nil, nil
}
func (f *fakeTaskRepository) UpdateTrackingMode(_ context.Context, _ string, _ int, _ string) error {
	return nil
}
func (f *fakeTaskRepository) IncrementCompletionCount(_ context.Context, _ string, _ int, _ string) error {
	return nil
}
func (f *fakeTaskRepository) IncrementFocusTime(_ context.Context, _ string, _ int, _ string, _ int) error {
	return nil
}
func (f *fakeTaskRepository) SetActiveSession(_ context.Context, _ string, _ int, _ *string) error {
	return nil
}
func (f *fakeTaskRepository) ListByUserPaginated(_ context.Context, _ string, _ *ports.PaginationCursor, _ int) ([]domain.Task, error) {
	return nil, nil
}

func TestTaskServiceListRecurrences(t *testing.T) {
	now := time.Now().UTC()
	rule := "FREQ=WEEKLY;BYDAY=MO"
	emptyRule := ""
	from := now.Add(-24 * time.Hour)
	to := now.Add(24 * time.Hour)
	oldFinish := now.Add(-72 * time.Hour)
	futureCreated := now.Add(72 * time.Hour)

	repo := &fakeTaskRepository{
		lockAcquired: true,
		items: []domain.Task{
			{ID: 1, RecurrenceRule: &rule, IsDeleted: false},
			{ID: 2, RecurrenceRule: nil, IsDeleted: false},
			{ID: 3, RecurrenceRule: &emptyRule, IsDeleted: false},
			{ID: 4, RecurrenceRule: &rule, IsDeleted: true},
			{ID: 5, RecurrenceRule: &rule, IsDeleted: false, FinishDate: &oldFinish},
			{ID: 6, RecurrenceRule: &rule, IsDeleted: false, CreatedDate: &futureCreated},
		},
	}

	service := NewTaskService(repo, nil, nil)
	got, err := service.ListRecurrences(context.Background(), "user-id", &from, &to)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	if len(got) != 1 || got[0].ID != 1 {
		t.Fatalf("expected only task ID 1, got %+v", got)
	}
}

func TestTaskServiceGenerateRecurrences(t *testing.T) {
	anchor := time.Date(2026, 3, 1, 9, 0, 0, 0, time.UTC) // Sunday
	rule := "FREQ=WEEKLY;BYDAY=MO"
	title := "Template task"
	templateSyncID := "tpl-1"

	repo := &fakeTaskRepository{
		lockAcquired: true,
		items: []domain.Task{
			{
				ID:             10,
				SyncID:         templateSyncID,
				UserID:         "user-id",
				Title:          &title,
				RecurrenceRule: &rule,
				CreatedDate:    &anchor,
				UpdatedAt:      anchor,
			},
		},
	}

	service := NewTaskService(repo, nil, nil)
	from := time.Date(2026, 3, 2, 0, 0, 0, 0, time.UTC) // Monday
	to := time.Date(2026, 3, 9, 0, 0, 0, 0, time.UTC)   // next Monday

	created, err := service.GenerateRecurrences(context.Background(), "user-id", from, to)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if len(created) != 2 {
		t.Fatalf("expected 2 generated recurrences, got %d", len(created))
	}
	for _, item := range created {
		if item.RecurringTemplateID == nil || *item.RecurringTemplateID != templateSyncID {
			t.Fatalf("expected recurringTemplateId=%s, got %+v", templateSyncID, item.RecurringTemplateID)
		}
		if item.RecurrenceRule != nil {
			t.Fatalf("expected generated instance recurrenceRule=nil, got %+v", item.RecurrenceRule)
		}
	}

	createdAgain, err := service.GenerateRecurrences(context.Background(), "user-id", from, to)
	if err != nil {
		t.Fatalf("unexpected error in second run: %v", err)
	}
	if len(createdAgain) != 0 {
		t.Fatalf("expected no duplicates on second run, got %d", len(createdAgain))
	}
}

func TestTaskServiceGenerateRecurrencesWindowLockBlocked(t *testing.T) {
	anchor := time.Date(2026, 3, 1, 9, 0, 0, 0, time.UTC)
	rule := "FREQ=DAILY;INTERVAL=1"
	title := "Template task"

	repo := &fakeTaskRepository{
		lockAcquired: false,
		items: []domain.Task{
			{ID: 10, SyncID: "tpl-1", UserID: "user-id", Title: &title, RecurrenceRule: &rule, CreatedDate: &anchor, UpdatedAt: anchor},
		},
	}

	service := NewTaskService(repo, nil, nil)
	_, err := service.GenerateRecurrences(context.Background(), "user-id", anchor.AddDate(0, 0, 1), anchor.AddDate(0, 0, 1))
	if !errors.Is(err, ErrRecurrenceWindowInProgress) {
		t.Fatalf("expected ErrRecurrenceWindowInProgress, got %v", err)
	}
	if repo.releaseInvoked != 0 {
		t.Fatalf("expected no lock release invocation, got %d", repo.releaseInvoked)
	}
}

func TestTaskServiceGenerateRecurrencesForAllUsers(t *testing.T) {
	rule := "FREQ=DAILY;INTERVAL=1"
	anchor := time.Date(2026, 3, 1, 9, 0, 0, 0, time.UTC)
	title := "Daily template"

	repo := &fakeTaskRepository{
		lockAcquired: true,
		items: []domain.Task{
			{ID: 1, SyncID: "tpl-u1", UserID: "u1", RecurrenceRule: &rule, Title: &title, CreatedDate: &anchor, UpdatedAt: anchor},
			{ID: 2, SyncID: "tpl-u2", UserID: "u2", RecurrenceRule: &rule, Title: &title, CreatedDate: &anchor, UpdatedAt: anchor},
		},
	}
	service := NewTaskService(repo, nil, nil)

	users, created, err := service.GenerateRecurrencesForAllUsers(context.Background(), anchor.AddDate(0, 0, 1), anchor.AddDate(0, 0, 1))
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if users != 2 {
		t.Fatalf("expected users=2, got %d", users)
	}
	if created != 2 {
		t.Fatalf("expected created=2, got %d", created)
	}
}

// Issue #989 (S2/S8): backend-generated recurring instances must carry the
// canonical due date (mirroring the legacy template offset) and inherit the
// template's manual order, so the fields the contract now declares survive
// generation. Old clients keep reading the mirrored finishDate.
func TestBuildRecurringInstanceMirrorsDueDateAndOrder(t *testing.T) {
	created := time.Date(2026, 11, 1, 9, 0, 0, 0, time.UTC)
	finish := created.AddDate(0, 0, 1) // template offset: created → finish is +1 day
	template := domain.Task{
		SyncID:      "tpl-989",
		UserID:      "user-989",
		CreatedDate: &created,
		FinishDate:  &finish,
		SortOrder:   7,
	}
	day := time.Date(2026, 11, 20, 9, 0, 0, 0, time.UTC)
	now := time.Date(2026, 11, 19, 8, 0, 0, 0, time.UTC)

	instance := buildRecurringInstance(template, day, now)

	wantDue := day.Add(finish.Sub(created))
	if instance.DueDate == nil || !instance.DueDate.Equal(wantDue) {
		t.Fatalf("instance due date must mirror the template offset (%v), got %v", wantDue, instance.DueDate)
	}
	if instance.FinishDate == nil || !instance.FinishDate.Equal(wantDue) {
		t.Fatalf("legacy finish date must stay mirrored for old clients (%v), got %v", wantDue, instance.FinishDate)
	}
	if instance.SortOrder != template.SortOrder {
		t.Fatalf("instance must inherit template sort order %d, got %d", template.SortOrder, instance.SortOrder)
	}
	if instance.CompletedAt != nil || instance.ScheduledForToday {
		t.Fatalf("fresh instance must not be completed or pinned to today")
	}

	plain := buildRecurringInstance(domain.Task{SyncID: "tpl-989b", UserID: "user-989"}, day, now)
	if plain.DueDate != nil {
		t.Fatalf("template without dates must not produce a due date, got %v", plain.DueDate)
	}
	if plain.SortOrder != 0 {
		t.Fatalf("template without order must produce sort order 0, got %d", plain.SortOrder)
	}
}

// Issue #989 round 1: a template carrying ONLY the canonical dueDate (the
// PR-B shape) must still generate scheduled instances — the offset derives
// from dueDate when finishDate is absent.
func TestBuildRecurringInstanceOffsetsFromDueOnlyTemplate(t *testing.T) {
	created := time.Date(2026, 11, 1, 9, 0, 0, 0, time.UTC)
	due := created.AddDate(0, 0, 2)
	template := domain.Task{
		SyncID:      "tpl-989-due-only",
		UserID:      "user-989",
		CreatedDate: &created,
		DueDate:     &due,
	}
	day := time.Date(2026, 11, 20, 9, 0, 0, 0, time.UTC)

	instance := buildRecurringInstance(template, day, day.Add(-time.Hour))

	wantDue := day.Add(due.Sub(created))
	if instance.DueDate == nil || !instance.DueDate.Equal(wantDue) {
		t.Fatalf("due-only template must offset from dueDate (%v), got %v", wantDue, instance.DueDate)
	}
	if instance.FinishDate == nil || !instance.FinishDate.Equal(wantDue) {
		t.Fatalf("legacy mirror must carry the same day (%v), got %v", wantDue, instance.FinishDate)
	}
}
