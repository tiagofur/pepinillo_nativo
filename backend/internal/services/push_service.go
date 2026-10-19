package services

import (
	"context"
	"errors"
	"fmt"
	"strings"
	"time"

	"pepinillo/backend/internal/domain"
	"pepinillo/backend/internal/ports"
)

var (
	ErrInvalidPushPlatform = errors.New("invalid push platform")
	ErrInvalidPushToken    = errors.New("invalid push token")
	ErrPushMessageEmpty    = errors.New("push message cannot be empty")
)

type PushService struct {
	repo           ports.DeviceTokenRepository
	provider       ports.PushProvider
	behaviorLogger ports.BehaviorLogger
}

type RecurrencePushWindow struct {
	From time.Time
	To   time.Time
}

func NewPushService(repo ports.DeviceTokenRepository, provider ports.PushProvider, behavior ...ports.BehaviorLogger) *PushService {
	var behaviorLogger ports.BehaviorLogger
	if len(behavior) > 0 {
		behaviorLogger = behavior[0]
	}

	return &PushService{
		repo:           repo,
		provider:       provider,
		behaviorLogger: behaviorLogger,
	}
}

func (s *PushService) RegisterDevice(ctx context.Context, userID, platform, token string, deviceID, appVersion *string) error {
	platform = strings.ToLower(strings.TrimSpace(platform))
	if platform != "ios" && platform != "android" {
		return ErrInvalidPushPlatform
	}

	token = strings.TrimSpace(token)
	if token == "" {
		return ErrInvalidPushToken
	}

	item := &domain.DeviceToken{
		UserID:     userID,
		Platform:   platform,
		Token:      token,
		DeviceID:   deviceID,
		AppVersion: appVersion,
		IsActive:   true,
	}
	return s.repo.Upsert(ctx, item)
}

func (s *PushService) ListDevices(ctx context.Context, userID string) ([]domain.DeviceToken, error) {
	return s.repo.ListByUser(ctx, userID)
}

func (s *PushService) UnregisterDevice(ctx context.Context, userID, token string) error {
	token = strings.TrimSpace(token)
	if token == "" {
		return ErrInvalidPushToken
	}
	return s.repo.DeleteByToken(ctx, userID, token)
}

func (s *PushService) SendTestPush(ctx context.Context, userID, title, body string) error {
	title = strings.TrimSpace(title)
	body = strings.TrimSpace(body)
	if title == "" || body == "" {
		return ErrPushMessageEmpty
	}

	return s.sendPushToUser(ctx, userID, title, body, map[string]string{"type": "test"})
}

func (s *PushService) SendRecurrenceGeneratedPush(ctx context.Context, userID string, created int, window RecurrencePushWindow) error {
	if created <= 0 {
		return nil
	}

	title := "Nuevas tareas recurrentes"
	body := fmt.Sprintf("Se generaron %d tareas para tu planificación.", created)
	return s.sendPushToUser(ctx, userID, title, body, map[string]string{
		"type":    "recurrence_generated",
		"created": fmt.Sprintf("%d", created),
		"from":    window.From.UTC().Format(time.RFC3339),
		"to":      window.To.UTC().Format(time.RFC3339),
	})
}

func (s *PushService) sendPushToUser(ctx context.Context, userID, title, body string, data map[string]string) error {
	items, err := s.repo.ListByUser(ctx, userID)
	if err != nil {
		return err
	}
	sent := 0
	var firstErr error
	pushType := data["type"]
	for _, d := range items {
		if err := s.provider.Send(ctx, d.Platform, d.Token, title, body, data); err != nil {
			s.logPushEvent(ctx, userID, "push_send_failed", map[string]any{
				"type":     pushType,
				"platform": d.Platform,
				"reason":   err.Error(),
			})
			// A3: a dead token must not suppress the user's other devices.
			// Deactivate it (soft: re-install revives via Upsert) and keep
			// going; report failure only if NOTHING was delivered.
			if errors.Is(err, ports.ErrPushTokenUnregistered) {
				if derr := s.repo.DeleteByToken(ctx, userID, d.Token); derr != nil {
					s.logPushEvent(ctx, userID, "push_token_prune_failed", map[string]any{
						"type":   pushType,
						"reason": derr.Error(),
					})
				}
			}
			if firstErr == nil {
				firstErr = fmt.Errorf("send push failed for token %s: %w", d.Token, err)
			}
			continue
		}
		sent++
	}
	s.logPushEvent(ctx, userID, "push_sent", map[string]any{
		"type":  pushType,
		"count": sent,
	})
	if sent == 0 && len(items) > 0 {
		return firstErr
	}
	return nil
}

func (s *PushService) logPushEvent(ctx context.Context, userID, eventType string, eventData map[string]any) {
	if s.behaviorLogger == nil {
		return
	}
	_ = s.behaviorLogger.LogEvent(ctx, userID, eventType, eventData)
}
