package observability

import (
	"bytes"
	"errors"
	"testing"
	"time"
)

func TestInitSentrySkipsWhenDSNEmpty(t *testing.T) {
	// Ensure logger is initialized so InitSentry's slog call does not panic.
	InitLogger(LoggerConfig{Writer: &bytes.Buffer{}})

	defer func() {
		if r := recover(); r != nil {
			t.Fatalf("InitSentry panicked on empty DSN: %v", r)
		}
	}()

	enabled := InitSentry(SentryConfig{DSN: ""})
	if enabled {
		t.Fatalf("expected InitSentry to return false when DSN is empty, got true")
	}

	// CaptureError must be a no-op when Sentry is disabled.
	CaptureError(errors.New("dummy"), map[string]string{"stage": "test"})
	CaptureError(nil, nil)

	// FlushSentry should also be safe to call.
	FlushSentry(100 * time.Millisecond)
}

func TestInitSentryRejectsInvalidDSN(t *testing.T) {
	InitLogger(LoggerConfig{Writer: &bytes.Buffer{}})

	defer func() {
		if r := recover(); r != nil {
			t.Fatalf("InitSentry panicked on invalid DSN: %v", r)
		}
	}()

	// An obviously invalid DSN should make Init fail, and we should observe
	// false — but never panic.
	enabled := InitSentry(SentryConfig{DSN: "not-a-dsn"})
	if enabled {
		t.Fatalf("expected InitSentry to return false for invalid DSN")
	}
}
