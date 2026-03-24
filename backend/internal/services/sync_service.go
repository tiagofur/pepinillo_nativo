package services

import (
	"context"
	"encoding/json"
	"fmt"
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

type SessionSyncRequest struct {
	Sessions   []domain.FocusSession `json:"sessions"`
	LastSyncAt *time.Time            `json:"lastSyncAt"`
}

type SessionSyncResponse struct {
	Sessions        []domain.FocusSession `json:"sessions"`
	ServerTimestamp time.Time             `json:"serverTimestamp"`
}

func (s *SyncService) SyncSessions(ctx context.Context, userID string, sessions []domain.FocusSession, lastSyncAt *time.Time) (*SessionSyncResponse, error) {
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

	// 4. Broadcast WS notification to other devices
	s.sendSyncNotification(userID, len(sessions))

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
	DeviceID string                   `json:"deviceId"`
	Tasks    []domain.Task            `json:"tasks"`
	Sessions []domain.FocusSession    `json:"sessions"`
	Settings []domain.UserPreference  `json:"settings"`
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

// InitialUpload atomically upserts all client data (tasks, sessions, settings)
// and returns the full merged server state. This is idempotent — sending the
// same request twice produces the same result (upsert, not insert).
func (s *SyncService) InitialUpload(ctx context.Context, userID string, req *InitialUploadRequest) (*InitialUploadResponse, error) {
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
	mergedTasks, _, _, err := s.taskRepo.Sync(ctx, userID, req.Tasks, nil, nil)
	if err != nil {
		return nil, fmt.Errorf("upsert tasks: %w", err)
	}

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

	// 7. Broadcast WS notification
	s.sendInitialUploadNotification(userID)

	return &InitialUploadResponse{
		Tasks:           mergedTasks,
		Sessions:        mergedSessions,
		Settings:        mergedSettings,
		ServerTimestamp: now,
		HasExistingData: hasExistingData,
	}, nil
}

func (s *SyncService) sendInitialUploadNotification(userID string) {
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

	_ = s.wsManager.SendToUser(userID, msgBytes)
}

func (s *SyncService) sendSyncNotification(userID string, sessionCount int) {
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

	_ = s.wsManager.SendToUser(userID, msgBytes)
}
