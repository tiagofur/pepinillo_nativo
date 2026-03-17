package behavior

import (
	"context"
	"encoding/json"
	"time"

	"gorm.io/gorm"

	"pepinillo/backend/internal/domain"
)

type PostgresLogger struct {
	db *gorm.DB
}

func NewPostgresLogger(db *gorm.DB) *PostgresLogger {
	return &PostgresLogger{db: db}
}

func (l *PostgresLogger) LogEvent(ctx context.Context, userID, eventType string, eventData map[string]any) error {
	payload, _ := json.Marshal(eventData)
	entry := &domain.UserBehaviorLog{
		UserID:    userID,
		EventType: eventType,
		EventData: string(payload),
		Timestamp: time.Now().UTC(),
	}
	return l.db.WithContext(ctx).Create(entry).Error
}
