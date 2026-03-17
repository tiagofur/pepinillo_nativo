package services

import (
	"context"
	"encoding/json"
	"fmt"
	"time"

	"pepinillo/backend/internal/domain"
	"pepinillo/backend/internal/ports"
)

type PomodoroService struct {
	repo          ports.PomodoroRepository
	behaviorLogger ports.BehaviorLogger
	wsManager     ports.WebSocketManager
}

func NewPomodoroService(repo ports.PomodoroRepository, behaviorLogger ports.BehaviorLogger, wsManager ports.WebSocketManager) *PomodoroService {
	return &PomodoroService{repo: repo, behaviorLogger: behaviorLogger, wsManager: wsManager}
}

func (s *PomodoroService) GetConfig(ctx context.Context, userID string) (*domain.PomodoroConfig, error) {
	return s.repo.GetConfig(ctx, userID)
}

func (s *PomodoroService) UpsertConfig(ctx context.Context, cfg *domain.PomodoroConfig) error {
	if err := s.repo.UpsertConfig(ctx, cfg); err != nil {
		return err
	}
	_ = s.behaviorLogger.LogEvent(ctx, cfg.UserID, "pomodoro_config_updated", map[string]any{})

	s.sendPomodoroConfigNotification(cfg.UserID, cfg)

	return nil
}

func (s *PomodoroService) UpsertStats(ctx context.Context, stats *domain.PomodoroStats) error {
	if err := s.repo.UpsertStats(ctx, stats); err != nil {
		return err
	}
	_ = s.behaviorLogger.LogEvent(ctx, stats.UserID, "pomodoro_stats_upserted", map[string]any{"date": stats.Date.Format("2006-01-02"), "pomodoros": stats.Pomodoros})
	return nil
}

func (s *PomodoroService) ListStatsByRange(ctx context.Context, userID string, from, to time.Time) ([]domain.PomodoroStats, error) {
	return s.repo.ListStatsByRange(ctx, userID, from, to)
}

func (s *PomodoroService) InsertSession(ctx context.Context, session *domain.PomodoroSession) error {
	if err := s.repo.InsertSession(ctx, session); err != nil {
		return err
	}
	_ = s.behaviorLogger.LogEvent(ctx, session.UserID, "pomodoro_session_inserted", map[string]any{"sessionId": session.ID, "taskId": session.TaskID, "phase": session.Phase})

	s.sendPomodoroSessionNotification(session.UserID, session, "pomodoro_session_created")

	return nil
}

func (s *PomodoroService) ListSessionsByTask(ctx context.Context, userID string, taskID int) ([]domain.PomodoroSession, error) {
	return s.repo.ListSessionsByTask(ctx, userID, taskID)
}

func (s *PomodoroService) ListSessionsByRange(ctx context.Context, userID string, from, to time.Time) ([]domain.PomodoroSession, error) {
	return s.repo.ListSessionsByRange(ctx, userID, from, to)
}

func (s *PomodoroService) UpdateSession(ctx context.Context, session *domain.PomodoroSession) error {
	if err := s.repo.UpdateSession(ctx, session); err != nil {
		return err
	}
	_ = s.behaviorLogger.LogEvent(ctx, session.UserID, "pomodoro_session_updated", map[string]any{"sessionId": session.ID})

	s.sendPomodoroSessionNotification(session.UserID, session, "pomodoro_session_updated")

	return nil
}

func (s *PomodoroService) ListAllSessions(ctx context.Context, userID string) ([]domain.PomodoroSession, error) {
	return s.repo.ListAllSessions(ctx, userID)
}

func (s *PomodoroService) GetStatsByDate(ctx context.Context, userID string, date time.Time) (*domain.PomodoroStats, error) {
	return s.repo.GetStatsByDate(ctx, userID, date)
}

func (s *PomodoroService) GetTaskStats(ctx context.Context, userID string, taskID int) (*domain.TaskPomodoroStats, error) {
	return s.repo.GetTaskStats(ctx, userID, taskID)
}

func (s *PomodoroService) sendPomodoroConfigNotification(userID string, cfg *domain.PomodoroConfig) {
	if s.wsManager == nil {
		return
	}

	message := map[string]any{
		"type": "pomodoro_config_updated",
		"data": cfg,
	}

	msgBytes, err := json.Marshal(message)
	if err != nil {
		fmt.Printf("failed to marshal websocket message: %v", err)
		return
	}

	_ = s.wsManager.SendToUser(userID, msgBytes)
}

func (s *PomodoroService) sendPomodoroSessionNotification(userID string, session *domain.PomodoroSession, messageType string) {
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

