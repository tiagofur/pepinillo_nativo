package integration

import (
	"context"
	"sync"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"pepinillo/backend/internal/adapters/behavior"
	"pepinillo/backend/internal/domain"
	"pepinillo/backend/internal/services"
)

type integrationDeviceTokenRepo struct {
	mu    sync.Mutex
	items map[string][]domain.DeviceToken
}

func (r *integrationDeviceTokenRepo) Upsert(_ context.Context, token *domain.DeviceToken) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	r.items[token.UserID] = append(r.items[token.UserID], *token)
	return nil
}
func (r *integrationDeviceTokenRepo) ListByUser(_ context.Context, userID string) ([]domain.DeviceToken, error) {
	r.mu.Lock()
	defer r.mu.Unlock()
	return append([]domain.DeviceToken(nil), r.items[userID]...), nil
}
func (r *integrationDeviceTokenRepo) DeleteByToken(_ context.Context, userID, token string) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	src := r.items[userID]
	dst := make([]domain.DeviceToken, 0, len(src))
	for _, it := range src {
		if it.Token != token {
			dst = append(dst, it)
		}
	}
	r.items[userID] = dst
	return nil
}

type integrationPushProvider struct {
	mu   sync.Mutex
	sent int
}

func (p *integrationPushProvider) Send(_ context.Context, _, _, _, _ string, _ map[string]string) error {
	p.mu.Lock()
	defer p.mu.Unlock()
	p.sent++
	return nil
}

type lwwIntegrationTaskRepo struct {
	mu    sync.Mutex
	items map[string]domain.Task
}

func newLWWIntegrationTaskRepo() *lwwIntegrationTaskRepo {
	return &lwwIntegrationTaskRepo{items: map[string]domain.Task{}}
}

func (r *lwwIntegrationTaskRepo) GetByID(_ context.Context, _ int) (*domain.Task, error) {
	return nil, nil
}
func (r *lwwIntegrationTaskRepo) ListUsersWithRecurrenceTemplates(_ context.Context) ([]string, error) {
	return nil, nil
}
func (r *lwwIntegrationTaskRepo) TryAcquireRecurrenceLock(_ context.Context, _, _ string, _ time.Time) (bool, error) {
	return true, nil
}
func (r *lwwIntegrationTaskRepo) ReleaseRecurrenceLock(_ context.Context, _, _ string) error {
	return nil
}
func (r *lwwIntegrationTaskRepo) ListByFinishDate(_ context.Context, _ string, _ time.Time) ([]domain.Task, error) {
	return nil, nil
}
func (r *lwwIntegrationTaskRepo) Upsert(_ context.Context, task *domain.Task) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	r.items[task.SyncID] = *task
	return nil
}
func (r *lwwIntegrationTaskRepo) Delete(_ context.Context, _ string, _ int) error { return nil }
func (r *lwwIntegrationTaskRepo) ListByUser(_ context.Context, _ string) ([]domain.Task, error) {
	r.mu.Lock()
	defer r.mu.Unlock()
	out := make([]domain.Task, 0, len(r.items))
	for _, item := range r.items {
		out = append(out, item)
	}
	return out, nil
}
func (r *lwwIntegrationTaskRepo) Sync(_ context.Context, userID string, tasks []domain.Task, _ []string, _ *time.Time) ([]domain.Task, []string, time.Time, error) {
	r.mu.Lock()
	defer r.mu.Unlock()
	now := time.Now().UTC()
	for _, incoming := range tasks {
		existing, ok := r.items[incoming.SyncID]
		if ok && existing.UpdatedAt.After(incoming.UpdatedAt) {
			continue
		}
		incoming.UserID = userID
		r.items[incoming.SyncID] = incoming
	}
	out := make([]domain.Task, 0, len(r.items))
	for _, item := range r.items {
		out = append(out, item)
	}
	return out, nil, now, nil
}
func (r *lwwIntegrationTaskRepo) UpdateTrackingMode(_ context.Context, _ int, _ string) error {
	return nil
}
func (r *lwwIntegrationTaskRepo) IncrementCompletionCount(_ context.Context, _ int, _ string) error {
	return nil
}
func (r *lwwIntegrationTaskRepo) IncrementFocusTime(_ context.Context, _ int, _ string, _ int) error {
	return nil
}
func (r *lwwIntegrationTaskRepo) SetActiveSession(_ context.Context, _ int, _ *string) error {
	return nil
}

type recurrenceIntegrationTaskRepo struct {
	items []domain.Task
}

func (r *recurrenceIntegrationTaskRepo) GetByID(_ context.Context, _ int) (*domain.Task, error) {
	return nil, nil
}
func (r *recurrenceIntegrationTaskRepo) ListByUser(_ context.Context, userID string) ([]domain.Task, error) {
	out := make([]domain.Task, 0)
	for _, item := range r.items {
		if item.UserID == userID {
			out = append(out, item)
		}
	}
	return out, nil
}
func (r *recurrenceIntegrationTaskRepo) ListUsersWithRecurrenceTemplates(_ context.Context) ([]string, error) {
	seen := map[string]struct{}{}
	out := make([]string, 0)
	for _, item := range r.items {
		if item.RecurrenceRule == nil || *item.RecurrenceRule == "" || item.RecurringTemplateID != nil {
			continue
		}
		if _, ok := seen[item.UserID]; ok {
			continue
		}
		seen[item.UserID] = struct{}{}
		out = append(out, item.UserID)
	}
	return out, nil
}
func (r *recurrenceIntegrationTaskRepo) TryAcquireRecurrenceLock(_ context.Context, _, _ string, _ time.Time) (bool, error) {
	return true, nil
}
func (r *recurrenceIntegrationTaskRepo) ReleaseRecurrenceLock(_ context.Context, _, _ string) error {
	return nil
}
func (r *recurrenceIntegrationTaskRepo) ListByFinishDate(_ context.Context, _ string, _ time.Time) ([]domain.Task, error) {
	return nil, nil
}
func (r *recurrenceIntegrationTaskRepo) Upsert(_ context.Context, task *domain.Task) error {
	r.items = append(r.items, *task)
	return nil
}
func (r *recurrenceIntegrationTaskRepo) Delete(_ context.Context, _ string, _ int) error { return nil }
func (r *recurrenceIntegrationTaskRepo) Sync(_ context.Context, _ string, _ []domain.Task, _ []string, _ *time.Time) ([]domain.Task, []string, time.Time, error) {
	return nil, nil, time.Now().UTC(), nil
}
func (r *recurrenceIntegrationTaskRepo) UpdateTrackingMode(_ context.Context, _ int, _ string) error {
	return nil
}
func (r *recurrenceIntegrationTaskRepo) IncrementCompletionCount(_ context.Context, _ int, _ string) error {
	return nil
}
func (r *recurrenceIntegrationTaskRepo) IncrementFocusTime(_ context.Context, _ int, _ string, _ int) error {
	return nil
}
func (r *recurrenceIntegrationTaskRepo) SetActiveSession(_ context.Context, _ int, _ *string) error {
	return nil
}

func TestCritical_TaskSyncLWW_Integration(t *testing.T) {
	if testing.Short() {
		t.Skip("skipping integration test")
	}
	repo := newLWWIntegrationTaskRepo()
	svc := services.NewTaskService(repo, behavior.NewNoopLogger(), nil)
	ctx := context.Background()

	newTitle := "new"
	oldTitle := "old"
	now := time.Now().UTC()

	_, _, _, err := svc.Sync(ctx, "u1", []domain.Task{
		{SyncID: "sync-1", Title: &newTitle, UpdatedAt: now},
	}, nil, nil)
	require.NoError(t, err)

	_, _, _, err = svc.Sync(ctx, "u1", []domain.Task{
		{SyncID: "sync-1", Title: &oldTitle, UpdatedAt: now.Add(-time.Hour)},
	}, nil, nil)
	require.NoError(t, err)

	items, err := repo.ListByUser(ctx, "u1")
	require.NoError(t, err)
	require.Len(t, items, 1)
	require.NotNil(t, items[0].Title)
	assert.Equal(t, "new", *items[0].Title)
}

func TestCritical_RecurrenceBusinessPush_Integration(t *testing.T) {
	if testing.Short() {
		t.Skip("skipping integration test")
	}

	rule := "FREQ=DAILY;INTERVAL=1"
	anchor := time.Date(2026, 3, 1, 9, 0, 0, 0, time.UTC)
	title := "Template"
	taskRepo := &recurrenceIntegrationTaskRepo{
		items: []domain.Task{
			{SyncID: "tpl-u1", UserID: "u1", RecurrenceRule: &rule, Title: &title, CreatedDate: &anchor, UpdatedAt: anchor},
			{SyncID: "tpl-u2", UserID: "u2", RecurrenceRule: &rule, Title: &title, CreatedDate: &anchor, UpdatedAt: anchor},
		},
	}
	taskSvc := services.NewTaskService(taskRepo, behavior.NewNoopLogger(), nil)

	deviceRepo := &integrationDeviceTokenRepo{items: map[string][]domain.DeviceToken{
		"u1": {{UserID: "u1", Platform: "ios", Token: "tok-1"}},
		"u2": {{UserID: "u2", Platform: "android", Token: "tok-2"}},
	}}
	pushProvider := &integrationPushProvider{}
	pushSvc := services.NewPushService(deviceRepo, pushProvider, behavior.NewNoopLogger())

	from := anchor.AddDate(0, 0, 1)
	to := anchor.AddDate(0, 0, 1)
	_, _, summary, err := taskSvc.GenerateRecurrencesForAllUsersWithSummary(context.Background(), from, to)
	require.NoError(t, err)
	require.Len(t, summary, 2)

	for _, row := range summary {
		err := pushSvc.SendRecurrenceGeneratedPush(context.Background(), row.UserID, row.Created, services.RecurrencePushWindow{From: from, To: to})
		require.NoError(t, err)
	}

	assert.Equal(t, 2, pushProvider.sent)
}
