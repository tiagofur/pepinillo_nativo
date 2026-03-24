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
	wsManager ports.WebSocketManager
}

func NewSyncService(focusRepo ports.FocusRepository, wsManager ports.WebSocketManager) *SyncService {
	return &SyncService{focusRepo: focusRepo, wsManager: wsManager}
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
