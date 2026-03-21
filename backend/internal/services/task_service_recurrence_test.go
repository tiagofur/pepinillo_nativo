package services

import (
	"context"
	"errors"
	"testing"
	"time"

	"pepinillo/backend/internal/domain"
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
func (f *fakeTaskRepository) Sync(_ context.Context, _ string, _ []domain.Task, _ []string, _ *time.Time) ([]domain.Task, []string, time.Time, error) {
	return nil, nil, time.Time{}, nil
}
func (f *fakeTaskRepository) UpdateTrackingMode(_ context.Context, _ int, _ string) error {
	return nil
}
func (f *fakeTaskRepository) IncrementCompletionCount(_ context.Context, _ int, _ string) error {
	return nil
}
func (f *fakeTaskRepository) IncrementFocusTime(_ context.Context, _ int, _ string, _ int) error {
	return nil
}
func (f *fakeTaskRepository) SetActiveSession(_ context.Context, _ int, _ *string) error {
	return nil
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
