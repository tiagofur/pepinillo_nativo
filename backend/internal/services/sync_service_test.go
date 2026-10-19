package services

import (
	"context"
	"fmt"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"pepinillo/backend/internal/domain"
	"pepinillo/backend/internal/ports"
)

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

type fakeFocusRepository struct {
	sessions         []domain.FocusSession
	upsertBatchErr   error
	recomputeErr     error
	updatedSinceErr  error
	listAllErr       error
	paginatedErr     error
	recomputedDates  []time.Time
	upsertedSessions []domain.FocusSession
	// Stale-session reconciler (#550)
	closeStaleResult []domain.StaleSessionClosed
	closeStaleErr    error
	closeStaleTTLDur time.Duration
}

func (f *fakeFocusRepository) GetConfig(_ context.Context, _ string) (*domain.FocusConfig, error) {
	return nil, nil
}
func (f *fakeFocusRepository) UpsertConfig(_ context.Context, _ *domain.FocusConfig) error {
	return nil
}
func (f *fakeFocusRepository) UpsertStats(_ context.Context, _ *domain.FocusStats) error {
	return nil
}
func (f *fakeFocusRepository) ListStatsByRange(_ context.Context, _ string, _, _ time.Time) ([]domain.FocusStats, error) {
	return nil, nil
}
func (f *fakeFocusRepository) GetStatsByDate(_ context.Context, _ string, _ time.Time) (*domain.FocusStats, error) {
	return nil, nil
}
func (f *fakeFocusRepository) InsertSession(_ context.Context, _ *domain.FocusSession) error {
	return nil
}
func (f *fakeFocusRepository) UpdateSession(_ context.Context, _ *domain.FocusSession) error {
	return nil
}
func (f *fakeFocusRepository) CountSessionsByUser(_ context.Context, _ string) (int64, error) {
	return int64(len(f.sessions)), nil
}

func (f *fakeFocusRepository) ListAllSessions(_ context.Context, _ string) ([]domain.FocusSession, error) {
	if f.listAllErr != nil {
		return nil, f.listAllErr
	}
	return f.sessions, nil
}
func (f *fakeFocusRepository) ListSessionsByTask(_ context.Context, _ string, _ int) ([]domain.FocusSession, error) {
	return nil, nil
}
func (f *fakeFocusRepository) ListSessionsByRange(_ context.Context, _ string, _, _ time.Time) ([]domain.FocusSession, error) {
	return nil, nil
}
func (f *fakeFocusRepository) GetTaskStats(_ context.Context, _ string, _ int) (*domain.TaskFocusStats, error) {
	return nil, nil
}
func (f *fakeFocusRepository) ListSessionsByUserPaginated(_ context.Context, _ string, _ *ports.PaginationCursor, _ int) ([]domain.FocusSession, error) {
	if f.paginatedErr != nil {
		return nil, f.paginatedErr
	}
	return f.sessions, nil
}
func (f *fakeFocusRepository) UpsertSessionBatch(_ context.Context, sessions []domain.FocusSession) error {
	if f.upsertBatchErr != nil {
		return f.upsertBatchErr
	}
	f.upsertedSessions = append(f.upsertedSessions, sessions...)
	f.sessions = append(f.sessions, sessions...)
	return nil
}
func (f *fakeFocusRepository) ListSessionsUpdatedSince(_ context.Context, _ string, since time.Time) ([]domain.FocusSession, error) {
	if f.updatedSinceErr != nil {
		return nil, f.updatedSinceErr
	}
	var result []domain.FocusSession
	for _, s := range f.sessions {
		if !s.UpdatedAt.Before(since) {
			result = append(result, s)
		}
	}
	return result, nil
}
func (f *fakeFocusRepository) RecomputeStatsForDates(_ context.Context, _ string, dates []time.Time) error {
	if f.recomputeErr != nil {
		return f.recomputeErr
	}
	f.recomputedDates = append(f.recomputedDates, dates...)
	return nil
}
func (f *fakeFocusRepository) CloseStaleSessions(_ context.Context, ttl time.Duration) ([]domain.StaleSessionClosed, error) {
	f.closeStaleTTLDur = ttl
	if f.closeStaleErr != nil {
		return nil, f.closeStaleErr
	}
	return f.closeStaleResult, nil
}

// fakeSyncTaskRepository implements ports.TaskRepository for sync tests.
type fakeSyncTaskRepository struct {
	tasks        []domain.Task
	syncCalled   int
	syncErr      error
	listErr      error
	paginatedErr error
}

func (f *fakeSyncTaskRepository) GetByID(_ context.Context, _ int) (*domain.Task, error) {
	return nil, nil
}
func (f *fakeSyncTaskRepository) ListByUser(_ context.Context, _ string) ([]domain.Task, error) {
	if f.listErr != nil {
		return nil, f.listErr
	}
	return f.tasks, nil
}
func (f *fakeSyncTaskRepository) ListUsersWithRecurrenceTemplates(_ context.Context) ([]string, error) {
	return nil, nil
}
func (f *fakeSyncTaskRepository) TryAcquireRecurrenceLock(_ context.Context, _, _ string, _ time.Time) (bool, error) {
	return false, nil
}
func (f *fakeSyncTaskRepository) ReleaseRecurrenceLock(_ context.Context, _, _ string) error {
	return nil
}
func (f *fakeSyncTaskRepository) ListByFinishDate(_ context.Context, _ string, _ time.Time) ([]domain.Task, error) {
	return nil, nil
}
func (f *fakeSyncTaskRepository) Upsert(_ context.Context, task *domain.Task) error {
	f.tasks = append(f.tasks, *task)
	return nil
}
func (f *fakeSyncTaskRepository) Delete(_ context.Context, _ string, _ int) error { return nil }
func (f *fakeSyncTaskRepository) Sync(_ context.Context, _ string, tasks []domain.Task, _ []string, _ *time.Time) (*ports.TaskSyncResult, error) {
	f.syncCalled++
	if f.syncErr != nil {
		return nil, f.syncErr
	}
	// Simulate merge: return the input tasks as merged
	f.tasks = append(f.tasks, tasks...)
	applied := make([]string, 0, len(tasks))
	for _, t := range tasks {
		applied = append(applied, t.SyncID)
	}
	return &ports.TaskSyncResult{ServerTasks: f.tasks, AppliedSyncIDs: applied, SyncedAt: time.Now().UTC()}, nil
}
func (f *fakeSyncTaskRepository) UpdateTrackingMode(_ context.Context, _ string, _ int, _ string) error {
	return nil
}
func (f *fakeSyncTaskRepository) IncrementCompletionCount(_ context.Context, _ string, _ int, _ string) error {
	return nil
}
func (f *fakeSyncTaskRepository) IncrementFocusTime(_ context.Context, _ string, _ int, _ string, _ int) error {
	return nil
}
func (f *fakeSyncTaskRepository) SetActiveSession(_ context.Context, _ string, _ int, _ *string) error {
	return nil
}
func (f *fakeSyncTaskRepository) ListByUserPaginated(_ context.Context, _ string, _ *ports.PaginationCursor, limit int) ([]domain.Task, error) {
	if f.paginatedErr != nil {
		return nil, f.paginatedErr
	}
	if limit >= len(f.tasks) {
		return f.tasks, nil
	}
	return f.tasks[:limit], nil
}

type fakePreferenceRepository struct {
	prefs    []domain.UserPreference
	getErr   error
	batchErr error
}

func (f *fakePreferenceRepository) GetByUser(_ context.Context, _ string) ([]domain.UserPreference, error) {
	if f.getErr != nil {
		return nil, f.getErr
	}
	return f.prefs, nil
}
func (f *fakePreferenceRepository) UpsertBatch(_ context.Context, incoming []domain.UserPreference) ([]domain.UserPreference, error) {
	if f.batchErr != nil {
		return nil, f.batchErr
	}
	// Simulate LWW merge: for each incoming pref, keep the newer one
	existing := make(map[string]domain.UserPreference)
	for _, p := range f.prefs {
		existing[p.Key] = p
	}
	for _, p := range incoming {
		if cur, ok := existing[p.Key]; ok {
			if p.UpdatedAt.After(cur.UpdatedAt) {
				existing[p.Key] = p
			}
			// else keep existing (server wins)
		} else {
			existing[p.Key] = p
		}
	}
	result := make([]domain.UserPreference, 0, len(existing))
	for _, p := range existing {
		result = append(result, p)
	}
	f.prefs = result
	return result, nil
}

type fakeWSManager struct {
	sentMessages []fakeSentMessage
}

type fakeSentMessage struct {
	userID          string
	excludeDeviceID string
	message         []byte
}

func (f *fakeWSManager) HandleConnection(_ context.Context, _ string, _ interface{}) error {
	return nil
}
func (f *fakeWSManager) SendToUser(_ string, _ []byte) error         { return nil }
func (f *fakeWSManager) SendToAll(_ []byte) error                    { return nil }
func (f *fakeWSManager) BroadcastToUsers(_ []string, _ []byte) error { return nil }
func (f *fakeWSManager) DisconnectUser(_ string)                     {}
func (f *fakeWSManager) UserCount(_ string) int                      { return 0 }
func (f *fakeWSManager) SendToUserExcluding(userID, excludeDeviceID string, message []byte) error {
	f.sentMessages = append(f.sentMessages, fakeSentMessage{userID, excludeDeviceID, message})
	return nil
}

// ---------------------------------------------------------------------------
// SyncSessions tests
// ---------------------------------------------------------------------------

func TestSyncSessions_UpsertAndRecompute(t *testing.T) {
	now := time.Now().UTC()
	focusRepo := &fakeFocusRepository{}
	ws := &fakeWSManager{}
	svc := NewSyncService(focusRepo, &fakeSyncTaskRepository{}, &fakePreferenceRepository{}, ws)

	sessions := []domain.FocusSession{
		{ID: "s1", StartedAt: now, Mode: "focus", Phase: "work", DurationSeconds: 1500},
		{ID: "s2", StartedAt: now.Add(-24 * time.Hour), Mode: "focus", Phase: "work", DurationSeconds: 900},
	}

	resp, err := svc.SyncSessions(context.Background(), "user-1", "device-1", sessions, nil)
	require.NoError(t, err)
	require.NotNil(t, resp)

	// Sessions should have been upserted
	require.Len(t, focusRepo.upsertedSessions, 2)
	// Each session should be stamped with the user ID
	for _, s := range focusRepo.upsertedSessions {
		require.Equal(t, "user-1", s.UserID)
	}

	// Stats should be recomputed for 2 distinct dates
	require.Len(t, focusRepo.recomputedDates, 2)

	// No lastSyncAt → no sessions returned in response
	require.Nil(t, resp.Sessions)
}

func TestSyncSessions_ReturnsUpdatedSince(t *testing.T) {
	now := time.Now().UTC()
	lastSync := now.Add(-1 * time.Hour)
	focusRepo := &fakeFocusRepository{
		// Pre-existing session that was already on the server
		sessions: []domain.FocusSession{
			{ID: "existing", UserID: "user-1", StartedAt: now.Add(-2 * time.Hour), UpdatedAt: now.Add(-30 * time.Minute), Mode: "focus", Phase: "work"},
		},
	}
	ws := &fakeWSManager{}
	svc := NewSyncService(focusRepo, &fakeSyncTaskRepository{}, &fakePreferenceRepository{}, ws)

	incoming := []domain.FocusSession{
		{ID: "s1", StartedAt: now, Mode: "focus", Phase: "work", DurationSeconds: 1500},
	}

	resp, err := svc.SyncSessions(context.Background(), "user-1", "device-1", incoming, &lastSync)
	require.NoError(t, err)
	require.NotNil(t, resp)

	// Should return sessions updated since lastSyncAt (existing + newly upserted)
	require.NotEmpty(t, resp.Sessions)
}

func TestSyncSessions_EmptyInput(t *testing.T) {
	focusRepo := &fakeFocusRepository{}
	svc := NewSyncService(focusRepo, &fakeSyncTaskRepository{}, &fakePreferenceRepository{}, nil)

	resp, err := svc.SyncSessions(context.Background(), "user-1", "device-1", nil, nil)
	require.NoError(t, err)
	require.NotNil(t, resp)
	require.Nil(t, resp.Sessions)
	require.Len(t, focusRepo.upsertedSessions, 0)
}

func TestSyncSessions_WSNotification(t *testing.T) {
	now := time.Now().UTC()
	ws := &fakeWSManager{}
	svc := NewSyncService(&fakeFocusRepository{}, &fakeSyncTaskRepository{}, &fakePreferenceRepository{}, ws)

	sessions := []domain.FocusSession{
		{ID: "s1", StartedAt: now, Mode: "focus", Phase: "work", DurationSeconds: 1500},
	}

	_, err := svc.SyncSessions(context.Background(), "user-1", "device-1", sessions, nil)
	require.NoError(t, err)

	// WS notification should have been sent, excluding originating device
	require.Len(t, ws.sentMessages, 1)
	require.Equal(t, "user-1", ws.sentMessages[0].userID)
	require.Equal(t, "device-1", ws.sentMessages[0].excludeDeviceID)
}

func TestSyncSessions_NilWSManager(t *testing.T) {
	now := time.Now().UTC()
	svc := NewSyncService(&fakeFocusRepository{}, &fakeSyncTaskRepository{}, &fakePreferenceRepository{}, nil)

	sessions := []domain.FocusSession{
		{ID: "s1", StartedAt: now, Mode: "focus", Phase: "work", DurationSeconds: 1500},
	}

	// Should not panic even without WS manager
	resp, err := svc.SyncSessions(context.Background(), "user-1", "device-1", sessions, nil)
	require.NoError(t, err)
	require.NotNil(t, resp)
}

// ---------------------------------------------------------------------------
// InitialUpload tests
// ---------------------------------------------------------------------------

// ---------------------------------------------------------------------------
// HasServerData tests (merge-decision pre-check, GET /sync/has-data)
// ---------------------------------------------------------------------------

func TestHasServerData_EmptyAccount(t *testing.T) {
	svc := NewSyncService(&fakeFocusRepository{}, &fakeSyncTaskRepository{}, &fakePreferenceRepository{}, &fakeWSManager{})

	hasData, err := svc.HasServerData(context.Background(), "user-1")
	require.NoError(t, err)
	assert.False(t, hasData)
}

func TestHasServerData_TasksExist(t *testing.T) {
	title := "server task"
	taskRepo := &fakeSyncTaskRepository{
		tasks: []domain.Task{{SyncID: "t1", Title: &title}},
	}
	svc := NewSyncService(&fakeFocusRepository{}, taskRepo, &fakePreferenceRepository{}, &fakeWSManager{})

	hasData, err := svc.HasServerData(context.Background(), "user-1")
	require.NoError(t, err)
	assert.True(t, hasData)
}

func TestHasServerData_SessionsOnly(t *testing.T) {
	// Sessions in the fake are populated by UpsertSessionBatch; seed one
	// through the same path the real server writes.
	focusRepo := &fakeFocusRepository{}
	taskRepo := &fakeSyncTaskRepository{}
	svc := NewSyncService(focusRepo, taskRepo, &fakePreferenceRepository{}, &fakeWSManager{})

	_, err := svc.SyncSessions(context.Background(), "user-1", "device-1", []domain.FocusSession{
		{ID: "s1", StartedAt: time.Now().UTC(), Mode: "focus", Phase: "work", DurationSeconds: 1500},
	}, nil)
	require.NoError(t, err)

	hasData, err := svc.HasServerData(context.Background(), "user-1")
	require.NoError(t, err)
	assert.True(t, hasData)
}

func TestInitialUpload_NewUser(t *testing.T) {
	taskRepo := &fakeSyncTaskRepository{} // empty — no existing data
	focusRepo := &fakeFocusRepository{}
	prefRepo := &fakePreferenceRepository{}
	ws := &fakeWSManager{}
	svc := NewSyncService(focusRepo, taskRepo, prefRepo, ws)

	now := time.Now().UTC()
	title := "My task"
	req := &InitialUploadRequest{
		DeviceID: "device-1",
		Tasks: []domain.Task{
			{SyncID: "t1", Title: &title, UpdatedAt: now},
		},
		Sessions: []domain.FocusSession{
			{ID: "s1", StartedAt: now, Mode: "focus", Phase: "work", DurationSeconds: 1500},
		},
		Settings: []domain.UserPreference{
			{Key: "theme", Value: "dark", UpdatedAt: now},
		},
	}

	resp, err := svc.InitialUpload(context.Background(), "user-1", "device-1", req)
	require.NoError(t, err)
	require.NotNil(t, resp)
	require.False(t, resp.HasExistingData)
	require.NotEmpty(t, resp.Tasks)
	require.NotEmpty(t, resp.Sessions)
	require.NotEmpty(t, resp.Settings)

	// WS notification should have been sent
	require.Len(t, ws.sentMessages, 1)
}

func TestInitialUpload_ExistingUser(t *testing.T) {
	title := "Existing task"
	taskRepo := &fakeSyncTaskRepository{
		tasks: []domain.Task{
			{ID: 1, SyncID: "existing-1", UserID: "user-1", Title: &title, UpdatedAt: time.Now().UTC()},
		},
	}
	focusRepo := &fakeFocusRepository{}
	prefRepo := &fakePreferenceRepository{}
	svc := NewSyncService(focusRepo, taskRepo, prefRepo, nil)

	now := time.Now().UTC()
	newTitle := "New task"
	req := &InitialUploadRequest{
		DeviceID: "device-1",
		Tasks: []domain.Task{
			{SyncID: "t2", Title: &newTitle, UpdatedAt: now},
		},
	}

	resp, err := svc.InitialUpload(context.Background(), "user-1", "device-1", req)
	require.NoError(t, err)
	require.True(t, resp.HasExistingData)
}

func TestInitialUpload_Idempotent(t *testing.T) {
	taskRepo := &fakeSyncTaskRepository{}
	focusRepo := &fakeFocusRepository{}
	prefRepo := &fakePreferenceRepository{}
	svc := NewSyncService(focusRepo, taskRepo, prefRepo, nil)

	now := time.Now().UTC()
	title := "Task"
	req := &InitialUploadRequest{
		DeviceID: "device-1",
		Tasks:    []domain.Task{{SyncID: "t1", Title: &title, UpdatedAt: now}},
		Sessions: []domain.FocusSession{{ID: "s1", StartedAt: now, Mode: "focus", Phase: "work"}},
		Settings: []domain.UserPreference{{Key: "theme", Value: "dark", UpdatedAt: now}},
	}

	// First call
	resp1, err := svc.InitialUpload(context.Background(), "user-1", "device-1", req)
	require.NoError(t, err)

	// Second call with same data — should succeed (upsert, not insert)
	resp2, err := svc.InitialUpload(context.Background(), "user-1", "device-1", req)
	require.NoError(t, err)

	// Both should return data successfully
	require.NotNil(t, resp1)
	require.NotNil(t, resp2)
	// The Sync method was called twice
	require.Equal(t, 2, taskRepo.syncCalled)
}

func TestInitialUpload_EmptyUpload(t *testing.T) {
	taskRepo := &fakeSyncTaskRepository{}
	focusRepo := &fakeFocusRepository{}
	prefRepo := &fakePreferenceRepository{}
	svc := NewSyncService(focusRepo, taskRepo, prefRepo, nil)

	req := &InitialUploadRequest{DeviceID: "device-1"}

	resp, err := svc.InitialUpload(context.Background(), "user-1", "device-1", req)
	require.NoError(t, err)
	require.NotNil(t, resp)
	require.False(t, resp.HasExistingData)
}

func TestInitialUpload_RejectsEmptyPreferenceKey(t *testing.T) {
	taskRepo := &fakeSyncTaskRepository{}
	focusRepo := &fakeFocusRepository{}
	prefRepo := &fakePreferenceRepository{}
	svc := NewSyncService(focusRepo, taskRepo, prefRepo, nil)

	req := &InitialUploadRequest{
		DeviceID: "device-1",
		Settings: []domain.UserPreference{{Key: "", Value: "forest"}},
	}

	_, err := svc.InitialUpload(context.Background(), "user-1", "device-1", req)
	require.ErrorIs(t, err, ErrInvalidPreferenceKey)
}

// ---------------------------------------------------------------------------
// FullSync tests
// ---------------------------------------------------------------------------

func TestFullSync_DefaultLimit(t *testing.T) {
	taskRepo := &fakeSyncTaskRepository{}
	focusRepo := &fakeFocusRepository{}
	prefRepo := &fakePreferenceRepository{}
	svc := NewSyncService(focusRepo, taskRepo, prefRepo, nil)

	resp, err := svc.FullSync(context.Background(), "user-1", FullSyncRequest{Limit: 0})
	require.NoError(t, err)
	require.NotNil(t, resp)
	require.Empty(t, resp.Tasks.Items)
	require.False(t, resp.Tasks.HasMore)
}

func TestFullSync_LimitClamping(t *testing.T) {
	// Create enough tasks to test clamping
	tasks := make([]domain.Task, 10)
	for i := range tasks {
		tasks[i] = domain.Task{ID: i + 1, SyncID: fmt.Sprintf("t%d", i+1), UpdatedAt: time.Now().UTC()}
	}
	taskRepo := &fakeSyncTaskRepository{tasks: tasks}
	focusRepo := &fakeFocusRepository{}
	prefRepo := &fakePreferenceRepository{}
	svc := NewSyncService(focusRepo, taskRepo, prefRepo, nil)

	// Limit > 500 should clamp to 500
	resp, err := svc.FullSync(context.Background(), "user-1", FullSyncRequest{Limit: 999})
	require.NoError(t, err)
	require.NotNil(t, resp)
	// With only 10 tasks, all should be returned
	require.Len(t, resp.Tasks.Items, 10)
	require.False(t, resp.Tasks.HasMore)
}

func TestFullSync_HasMore(t *testing.T) {
	// Create limit+1 tasks so HasMore is true
	now := time.Now().UTC()
	tasks := make([]domain.Task, 4) // We'll request limit=3, repo returns up to limit items
	for i := range tasks {
		tasks[i] = domain.Task{ID: i + 1, SyncID: fmt.Sprintf("t%d", i+1), UpdatedAt: now.Add(time.Duration(i) * time.Second)}
	}
	taskRepo := &fakeSyncTaskRepository{tasks: tasks}
	focusRepo := &fakeFocusRepository{}
	prefRepo := &fakePreferenceRepository{}
	svc := NewSyncService(focusRepo, taskRepo, prefRepo, nil)

	// Request with limit=3; repo has 4 tasks, ListByUserPaginated is called with limit+1=4,
	// our fake returns min(4, len(tasks))=4 items, so HasMore should be true with 3 items returned
	resp, err := svc.FullSync(context.Background(), "user-1", FullSyncRequest{Limit: 3})
	require.NoError(t, err)
	require.Len(t, resp.Tasks.Items, 3)
	require.True(t, resp.Tasks.HasMore)
	require.NotEmpty(t, resp.Tasks.NextCursor)
}

func TestFullSync_CursorEncodeDecode(t *testing.T) {
	now := time.Date(2026, 3, 24, 12, 0, 0, 0, time.UTC)

	encoded := encodeCursor(now, "42")
	decoded, err := decodeCursor(encoded)
	require.NoError(t, err)
	require.Equal(t, now, decoded.UpdatedAt)
	require.Equal(t, "42", decoded.ID)
}

func TestFullSync_InvalidCursor(t *testing.T) {
	svc := NewSyncService(&fakeFocusRepository{}, &fakeSyncTaskRepository{}, &fakePreferenceRepository{}, nil)

	_, err := svc.FullSync(context.Background(), "user-1", FullSyncRequest{TaskCursor: "invalid"})
	require.Error(t, err)
	require.Contains(t, err.Error(), "invalid taskCursor")
}

func TestFullSync_EmptyCursorReturnsFirstPage(t *testing.T) {
	now := time.Now().UTC()
	tasks := []domain.Task{
		{ID: 1, SyncID: "t1", UpdatedAt: now},
	}
	taskRepo := &fakeSyncTaskRepository{tasks: tasks}
	focusRepo := &fakeFocusRepository{}
	prefRepo := &fakePreferenceRepository{
		prefs: []domain.UserPreference{{UserID: "user-1", Key: "theme", Value: "dark"}},
	}
	svc := NewSyncService(focusRepo, taskRepo, prefRepo, nil)

	resp, err := svc.FullSync(context.Background(), "user-1", FullSyncRequest{})
	require.NoError(t, err)
	require.Len(t, resp.Tasks.Items, 1)
	require.Len(t, resp.Settings, 1)
}

func TestFullSync_NilSettingsReturnsEmptySlice(t *testing.T) {
	svc := NewSyncService(&fakeFocusRepository{}, &fakeSyncTaskRepository{}, &fakePreferenceRepository{}, nil)

	resp, err := svc.FullSync(context.Background(), "user-1", FullSyncRequest{})
	require.NoError(t, err)
	require.NotNil(t, resp.Settings)
	require.Len(t, resp.Settings, 0)
}
