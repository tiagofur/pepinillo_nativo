package services

import (
	"context"
	"encoding/json"
	"fmt"
	"time"

	"pepinillo/backend/internal/domain"
	"pepinillo/backend/internal/ports"
)

type FocusService struct {
	repo           ports.FocusRepository
	behaviorLogger ports.BehaviorLogger
	wsManager      ports.WebSocketManager
}

func NewFocusService(repo ports.FocusRepository, behaviorLogger ports.BehaviorLogger, wsManager ports.WebSocketManager) *FocusService {
	return &FocusService{repo: repo, behaviorLogger: behaviorLogger, wsManager: wsManager}
}

func (s *FocusService) GetConfig(ctx context.Context, userID string) (*domain.FocusConfig, error) {
	return s.repo.GetConfig(ctx, userID)
}

func (s *FocusService) UpsertConfig(ctx context.Context, cfg *domain.FocusConfig) error {
	if err := s.repo.UpsertConfig(ctx, cfg); err != nil {
		return err
	}
	_ = s.behaviorLogger.LogEvent(ctx, cfg.UserID, "focus_config_updated", map[string]any{})

	s.sendFocusConfigNotification(cfg.UserID, cfg)
	return nil
}

func (s *FocusService) UpsertStats(ctx context.Context, stats *domain.FocusStats) error {
	if err := s.repo.UpsertStats(ctx, stats); err != nil {
		return err
	}
	_ = s.behaviorLogger.LogEvent(ctx, stats.UserID, "focus_stats_upserted", map[string]any{"date": stats.Date.Format("2006-01-02")})
	return nil
}

func (s *FocusService) ListStatsByRange(ctx context.Context, userID string, from, to time.Time) ([]domain.FocusStats, error) {
	return s.repo.ListStatsByRange(ctx, userID, from, to)
}

func (s *FocusService) InsertSession(ctx context.Context, session *domain.FocusSession) error {
	if err := s.repo.InsertSession(ctx, session); err != nil {
		return err
	}
	_ = s.behaviorLogger.LogEvent(ctx, session.UserID, "focus_session_inserted", map[string]any{"sessionId": session.ID, "mode": session.Mode, "phase": session.Phase})

	s.sendFocusSessionNotification(session.UserID, session, "focus_session_created")
	return nil
}

func (s *FocusService) ListSessionsByTask(ctx context.Context, userID string, taskID int) ([]domain.FocusSession, error) {
	return s.repo.ListSessionsByTask(ctx, userID, taskID)
}

func (s *FocusService) ListSessionsByRange(ctx context.Context, userID string, from, to time.Time) ([]domain.FocusSession, error) {
	return s.repo.ListSessionsByRange(ctx, userID, from, to)
}

func (s *FocusService) UpdateSession(ctx context.Context, session *domain.FocusSession) error {
	if err := s.repo.UpdateSession(ctx, session); err != nil {
		return err
	}
	_ = s.behaviorLogger.LogEvent(ctx, session.UserID, "focus_session_updated", map[string]any{"sessionId": session.ID})

	s.sendFocusSessionNotification(session.UserID, session, "focus_session_updated")
	return nil
}

func (s *FocusService) ListAllSessions(ctx context.Context, userID string) ([]domain.FocusSession, error) {
	return s.repo.ListAllSessions(ctx, userID)
}

func (s *FocusService) GetStatsByDate(ctx context.Context, userID string, date time.Time) (*domain.FocusStats, error) {
	return s.repo.GetStatsByDate(ctx, userID, date)
}

func (s *FocusService) GetTaskStats(ctx context.Context, userID string, taskID int) (*domain.TaskFocusStats, error) {
	return s.repo.GetTaskStats(ctx, userID, taskID)
}

func (s *FocusService) sendFocusConfigNotification(userID string, cfg *domain.FocusConfig) {
	if s.wsManager == nil {
		return
	}

	message := map[string]any{
		"type": "focus_config_updated",
		"data": cfg,
	}

	msgBytes, err := json.Marshal(message)
	if err != nil {
		fmt.Printf("failed to marshal websocket message: %v", err)
		return
	}

	_ = s.wsManager.SendToUser(userID, msgBytes)
}

func (s *FocusService) sendFocusSessionNotification(userID string, session *domain.FocusSession, messageType string) {
	if s.wsManager == nil {
		return
	}

	message := map[string]any{
		"type": messageType,
		"data": session,
	}

	msgBytes, err := json.Marshal(message)
	if err != nil {
		fmt.Printf("failed to marshal websocket message: %v", err)
		return
	}

	_ = s.wsManager.SendToUser(userID, msgBytes)
}
