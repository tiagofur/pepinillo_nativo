package ports

import "context"

type BehaviorLogger interface {
	LogEvent(ctx context.Context, userID, eventType string, eventData map[string]any) error
}
