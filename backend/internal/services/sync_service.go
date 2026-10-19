package services

import (
	"context"
	"encoding/json"
	"fmt"
	"strings"
	"time"

	"pepinillo/backend/internal/domain"
	"pepinillo/backend/internal/ports"
)

type SyncService struct {
	focusRepo ports.FocusRepository
	taskRepo  ports.TaskRepository
	prefRepo  ports.PreferenceRepository
	wsManager ports.WebSocketManager
}

func NewSyncService(
	focusRepo ports.FocusRepository,
	taskRepo ports.TaskRepository,
	prefRepo ports.PreferenceRepository,
	wsManager ports.WebSocketManager,
) *SyncService {
	return &SyncService{
		focusRepo: focusRepo,
		taskRepo:  taskRepo,
		prefRepo:  prefRepo,
		wsManager: wsManager,
	}
}

// FullSyncRequest holds query parameters for paginated full sync.
type FullSyncRequest struct {
	TaskCursor    string `query:"taskCursor"`
	SessionCursor string `query:"sessionCursor"`
	Limit         int    `query:"limit"`
}

// PaginatedPage represents a single page of cursor-paginated results.
type PaginatedPage[T any] struct {
	Items      []T    `json:"items"`
	NextCursor string `json:"nextCursor,omitempty"`
	HasMore    bool   `json:"hasMore"`
}

// FullSyncResponse is the response for GET /sync/full.
type FullSyncResponse struct {
	Tasks           PaginatedPage[domain.Task]         `json:"tasks"`
	Sessions        PaginatedPage[domain.FocusSession] `json:"sessions"`
	Settings        []domain.UserPreference            `json:"settings"`
	ServerTimestamp time.Time                          `json:"serverTimestamp"`
}

type SessionSyncRequest struct {
	Sessions   []domain.FocusSession `json:"sessions"`
	LastSyncAt *time.Time            `json:"lastSyncAt"`
}

type SessionSyncResponse struct {
	Sessions        []domain.FocusSession `json:"sessions"`
	ServerTimestamp time.Time             `json:"serverTimestamp"`
}

func (s *SyncService) SyncSessions(ctx context.Context, userID, deviceID string, sessions []domain.FocusSession, lastSyncAt *time.Time) (*SessionSyncResponse, error) {
	now := time.Now().UTC()

	// Stamp all incoming sessions with the user ID and current time
	for i := range sessions {
		sessions[i].UserID = userID
		sessions[i].UpdatedAt = now
	}

	// 1. Upsert incoming sessions (INSERT ON CONFLICT DO UPDATE)
	if err := s.focusRepo.UpsertSessionBatch(ctx, sessions); err != nil {
		return nil, fmt.Errorf("upsert session batch: %w", err)
	}

	// 2. Collect affected dates for stats recomputation
	affectedDates := collectAffectedDates(sessions)
	if err := s.focusRepo.RecomputeStatsForDates(ctx, userID, affectedDates); err != nil {
		return nil, fmt.Errorf("recompute stats: %w", err)
	}

	// 3. Find sessions updated since lastSyncAt to return to client
	var updatedSessions []domain.FocusSession
	if lastSyncAt != nil {
		var err error
		updatedSessions, err = s.focusRepo.ListSessionsUpdatedSince(ctx, userID, *lastSyncAt)
		if err != nil {
			return nil, fmt.Errorf("list updated sessions: %w", err)
		}
	}

	// 4. Broadcast WS notification to other devices (exclude originating device)
	s.sendSyncNotification(userID, deviceID, len(sessions))

	return &SessionSyncResponse{
		Sessions:        updatedSessions,
		ServerTimestamp: now,
	}, nil
}

func collectAffectedDates(sessions []domain.FocusSession) []time.Time {
	seen := make(map[string]time.Time)
	for _, s := range sessions {
		dateKey := s.StartedAt.Format("2006-01-02")
		if _, ok := seen[dateKey]; !ok {
			seen[dateKey] = time.Date(s.StartedAt.Year(), s.StartedAt.Month(), s.StartedAt.Day(), 0, 0, 0, 0, time.UTC)
		}
	}
	dates := make([]time.Time, 0, len(seen))
	for _, d := range seen {
		dates = append(dates, d)
	}
	return dates
}

// InitialUploadRequest represents the full state from a client performing
// an anonymous-to-registered account migration (or first device sync).
type InitialUploadRequest struct {
	DeviceID string                  `json:"deviceId"`
	Tasks    []domain.Task           `json:"tasks"`
	Sessions []domain.FocusSession   `json:"sessions"`
	Settings []domain.UserPreference `json:"settings"`
}

// InitialUploadResponse returns the merged server state after an initial upload.
// HasExistingData tells the client whether the server already had data for this user
// so the Android client can show the "merge vs account-only" dialog.
type InitialUploadResponse struct {
	Tasks           []domain.Task           `json:"tasks"`
	Sessions        []domain.FocusSession   `json:"sessions"`
	Settings        []domain.UserPreference `json:"settings"`
	ServerTimestamp time.Time               `json:"serverTimestamp"`
	HasExistingData bool                    `json:"hasExistingData"`
}

// HasServerData reports whether the account already holds any tasks or focus
// sessions, WITHOUT uploading or mutating anything. Clients call this before
// the merge dialog so the user's "merge vs account-only" choice is real:
// until now the client uploaded local data first and only then asked, which
// made "Use Account Only" unable to recover the discarded local data.
func (s *SyncService) HasServerData(ctx context.Context, userID string) (bool, error) {
	existingTasks, err := s.taskRepo.ListByUser(ctx, userID)
	if err != nil {
		return false, fmt.Errorf("check existing tasks: %w", err)
	}
	if len(existingTasks) > 0 {
		return true, nil
	}
	sessionCount, err := s.focusRepo.CountSessionsByUser(ctx, userID)
	if err != nil {
		return false, fmt.Errorf("check existing sessions: %w", err)
	}
	return sessionCount > 0, nil
}

// InitialUpload atomically upserts all client data (tasks, sessions, settings)
// and returns the full merged server state. This is idempotent — sending the
// same request twice produces the same result (upsert, not insert).
func (s *SyncService) InitialUpload(ctx context.Context, userID, deviceID string, req *InitialUploadRequest) (*InitialUploadResponse, error) {
	now := time.Now().UTC()

	// 1. Check if user already has data on the server
	existingTasks, err := s.taskRepo.ListByUser(ctx, userID)
	if err != nil {
		return nil, fmt.Errorf("check existing data: %w", err)
	}
	hasExistingData := len(existingTasks) > 0

	// 2. Upsert tasks via the existing Sync method (handles SyncID-based conflict detection,
	// subtask replacement, and returns the merged state inside a transaction).
	for i := range req.Tasks {
		req.Tasks[i].UserID = userID
		if req.Tasks[i].UpdatedAt.IsZero() {
			req.Tasks[i].UpdatedAt = now
		}
	}
	mergedResult, err := s.taskRepo.Sync(ctx, userID, req.Tasks, nil, nil)
	if err != nil {
		return nil, fmt.Errorf("upsert tasks: %w", err)
	}
	mergedTasks := mergedResult.ServerTasks

	// 3. Upsert sessions
	for i := range req.Sessions {
		req.Sessions[i].UserID = userID
		req.Sessions[i].UpdatedAt = now
	}
	if err := s.focusRepo.UpsertSessionBatch(ctx, req.Sessions); err != nil {
		return nil, fmt.Errorf("upsert sessions: %w", err)
	}

	// 4. Recompute stats for all affected dates from sessions
	affectedDates := collectAffectedDates(req.Sessions)
	if err := s.focusRepo.RecomputeStatsForDates(ctx, userID, affectedDates); err != nil {
		return nil, fmt.Errorf("recompute stats: %w", err)
	}

	// 5. Upsert settings
	for i := range req.Settings {
		if strings.TrimSpace(req.Settings[i].Key) == "" {
			return nil, ErrInvalidPreferenceKey
		}
		req.Settings[i].UserID = userID
		if req.Settings[i].UpdatedAt.IsZero() {
			req.Settings[i].UpdatedAt = now
		}
	}
	mergedSettings, err := s.prefRepo.UpsertBatch(ctx, req.Settings)
	if err != nil {
		return nil, fmt.Errorf("upsert settings: %w", err)
	}

	// 6. Fetch all sessions for the user (merged state)
	mergedSessions, err := s.focusRepo.ListAllSessions(ctx, userID)
	if err != nil {
		return nil, fmt.Errorf("fetch sessions: %w", err)
	}

	// 7. Broadcast WS notification (exclude originating device)
	s.sendInitialUploadNotification(userID, deviceID)

	return &InitialUploadResponse{
		Tasks:           mergedTasks,
		Sessions:        mergedSessions,
		Settings:        mergedSettings,
		ServerTimestamp: now,
		HasExistingData: hasExistingData,
	}, nil
}

func (s *SyncService) sendInitialUploadNotification(userID, excludeDeviceID string) {
	if s.wsManager == nil {
		return
	}

	message := map[string]any{
		"type": "initial_upload_completed",
		"data": map[string]any{},
	}

	msgBytes, err := json.Marshal(message)
	if err != nil {
		fmt.Printf("failed to marshal websocket message: %v", err)
		return
	}

	_ = s.wsManager.SendToUserExcluding(userID, excludeDeviceID, msgBytes)
}

// FullSync returns paginated tasks, sessions, and all settings for a user.
func (s *SyncService) FullSync(ctx context.Context, userID string, req FullSyncRequest) (*FullSyncResponse, error) {
	// Clamp limit
	limit := req.Limit
	if limit <= 0 {
		limit = 100
	}
	if limit > 500 {
		limit = 500
	}

	// --- Tasks ---
	var taskCursor *ports.PaginationCursor
	if req.TaskCursor != "" {
		c, err := decodeCursor(req.TaskCursor)
		if err != nil {
			return nil, fmt.Errorf("invalid taskCursor: %w", err)
		}
		taskCursor = c
	}

	tasks, err := s.taskRepo.ListByUserPaginated(ctx, userID, taskCursor, limit+1)
	if err != nil {
		return nil, fmt.Errorf("list tasks: %w", err)
	}

	taskPage := buildPage(tasks, limit, func(t domain.Task) string {
		return encodeCursor(t.UpdatedAt, fmt.Sprintf("%d", t.ID))
	})

	// --- Sessions ---
	var sessionCursor *ports.PaginationCursor
	if req.SessionCursor != "" {
		c, err := decodeCursor(req.SessionCursor)
		if err != nil {
			return nil, fmt.Errorf("invalid sessionCursor: %w", err)
		}
		sessionCursor = c
	}

	sessions, err := s.focusRepo.ListSessionsByUserPaginated(ctx, userID, sessionCursor, limit+1)
	if err != nil {
		return nil, fmt.Errorf("list sessions: %w", err)
	}

	sessionPage := buildPage(sessions, limit, func(s domain.FocusSession) string {
		return encodeCursor(s.UpdatedAt, s.ID)
	})

	// --- Settings ---
	settings, err := s.prefRepo.GetByUser(ctx, userID)
	if err != nil {
		return nil, fmt.Errorf("list settings: %w", err)
	}
	if settings == nil {
		settings = []domain.UserPreference{}
	}

	return &FullSyncResponse{
		Tasks:           taskPage,
		Sessions:        sessionPage,
		Settings:        settings,
		ServerTimestamp: time.Now().UTC(),
	}, nil
}

// encodeCursor encodes an updated_at timestamp and ID into a cursor string.
func encodeCursor(updatedAt time.Time, id string) string {
	return updatedAt.UTC().Format(time.RFC3339Nano) + "|" + id
}

// decodeCursor decodes a cursor string into a PaginationCursor.
func decodeCursor(cursor string) (*ports.PaginationCursor, error) {
	parts := strings.SplitN(cursor, "|", 2)
	if len(parts) != 2 {
		return nil, fmt.Errorf("cursor must be in format 'updatedAt|id'")
	}

	t, err := time.Parse(time.RFC3339Nano, parts[0])
	if err != nil {
		return nil, fmt.Errorf("invalid cursor timestamp: %w", err)
	}

	return &ports.PaginationCursor{
		UpdatedAt: t,
		ID:        parts[1],
	}, nil
}

// buildPage constructs a PaginatedPage from items fetched with limit+1 strategy.
func buildPage[T any](items []T, limit int, cursorFn func(T) string) PaginatedPage[T] {
	hasMore := len(items) > limit
	if hasMore {
		items = items[:limit]
	}

	var nextCursor string
	if hasMore && len(items) > 0 {
		nextCursor = cursorFn(items[len(items)-1])
	}

	return PaginatedPage[T]{
		Items:      items,
		NextCursor: nextCursor,
		HasMore:    hasMore,
	}
}

func (s *SyncService) sendSyncNotification(userID, excludeDeviceID string, sessionCount int) {
	if s.wsManager == nil {
		return
	}

	message := map[string]any{
		"type": "sessions_synced",
		"data": map[string]any{
			"sessionCount": sessionCount,
		},
	}

	msgBytes, err := json.Marshal(message)
	if err != nil {
		fmt.Printf("failed to marshal websocket message: %v", err)
		return
	}

	_ = s.wsManager.SendToUserExcluding(userID, excludeDeviceID, msgBytes)
}
