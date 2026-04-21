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

type PreferenceService struct {
	repo      ports.PreferenceRepository
	wsManager ports.WebSocketManager
}

func NewPreferenceService(repo ports.PreferenceRepository, wsManager ports.WebSocketManager) *PreferenceService {
	return &PreferenceService{repo: repo, wsManager: wsManager}
}

func (s *PreferenceService) GetPreferences(ctx context.Context, userID string) ([]domain.UserPreference, error) {
	return s.repo.GetByUser(ctx, userID)
}

func (s *PreferenceService) UpsertPreferences(ctx context.Context, userID, deviceID string, prefs []domain.UserPreference) ([]domain.UserPreference, error) {
	now := time.Now().UTC()
	for i := range prefs {
		if strings.TrimSpace(prefs[i].Key) == "" {
			return nil, ErrInvalidPreferenceKey
		}
		prefs[i].UserID = userID
		if prefs[i].UpdatedAt.IsZero() {
			prefs[i].UpdatedAt = now
		}
	}

	merged, err := s.repo.UpsertBatch(ctx, prefs)
	if err != nil {
		return nil, err
	}

	s.sendSettingsUpdatedNotification(userID, deviceID)
	return merged, nil
}

func (s *PreferenceService) sendSettingsUpdatedNotification(userID, excludeDeviceID string) {
	if s.wsManager == nil {
		return
	}

	message := map[string]any{
		"type": "settings_updated",
		"data": map[string]any{},
	}

	msgBytes, err := json.Marshal(message)
	if err != nil {
		fmt.Printf("failed to marshal websocket message: %v", err)
		return
	}

	_ = s.wsManager.SendToUserExcluding(userID, excludeDeviceID, msgBytes)
}
