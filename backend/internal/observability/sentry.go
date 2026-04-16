package observability

import (
	"log/slog"
	"time"

	"github.com/getsentry/sentry-go"
)

// SentryConfig toggles Sentry initialization. An empty DSN disables
// Sentry entirely — safe default for local development.
type SentryConfig struct {
	DSN                string
	Environment        string
	Release            string
	SampleRate         float64 // 0..1, applied to errors (default 1.0)
	TracesSampleRate   float64 // 0..1, applied to traces (default 0.1)
	AttachStacktrace   bool
}

// InitSentry initializes the Sentry SDK if DSN is set. It returns true
// when Sentry is active, false when skipped. Errors initializing Sentry
// are logged but never fatal — the server must still boot without
// observability in degraded environments.
func InitSentry(cfg SentryConfig) bool {
	if cfg.DSN == "" {
		slog.Info("sentry disabled (SENTRY_DSN is empty)")
		return false
	}

	sampleRate := cfg.SampleRate
	if sampleRate <= 0 {
		sampleRate = 1.0
	}
	tracesSampleRate := cfg.TracesSampleRate
	if tracesSampleRate < 0 {
		tracesSampleRate = 0
	}

	err := sentry.Init(sentry.ClientOptions{
		Dsn:              cfg.DSN,
		Environment:      cfg.Environment,
		Release:          cfg.Release,
		SampleRate:       sampleRate,
		TracesSampleRate: tracesSampleRate,
		AttachStacktrace: cfg.AttachStacktrace,
	})
	if err != nil {
		slog.Error("sentry init failed", "error", err)
		return false
	}

	slog.Info("sentry enabled",
		"env", cfg.Environment,
		"sampleRate", sampleRate,
		"tracesSampleRate", tracesSampleRate,
	)
	return true
}

// FlushSentry flushes buffered events. Call via defer in main() so events
// captured right before shutdown still reach Sentry.
func FlushSentry(timeout time.Duration) {
	sentry.Flush(timeout)
}

// CaptureError reports an error to Sentry with optional structured tags.
// It is a no-op when Sentry is not initialized. Callers should still log
// the error locally — Sentry is a supplement, not a replacement.
func CaptureError(err error, tags map[string]string) {
	if err == nil {
		return
	}
	hub := sentry.CurrentHub()
	if hub == nil || hub.Client() == nil {
		return
	}
	hub.WithScope(func(scope *sentry.Scope) {
		for k, v := range tags {
			scope.SetTag(k, v)
		}
		hub.CaptureException(err)
	})
}
