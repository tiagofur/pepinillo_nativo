package behavior

import "context"

type NoopLogger struct{}

func NewNoopLogger() *NoopLogger {
	return &NoopLogger{}
}

func (l *NoopLogger) LogEvent(_ context.Context, _ string, _ string, _ map[string]any) error {
	return nil
}
