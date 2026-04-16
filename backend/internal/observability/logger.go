// Package observability provides structured logging, metrics, and error
// tracking utilities. The logger is a thin wrapper around log/slog that
// emits JSON records to stdout. It is intentionally minimal — no new
// abstractions — so services can call slog.Info / slog.Warn / slog.Error
// directly against the package-level logger set via InitLogger.
package observability

import (
	"io"
	"log/slog"
	"os"
	"strings"
)

// LoggerConfig configures the JSON slog logger. Level accepts "debug",
// "info", "warn" or "error" (case-insensitive). Unknown values fall back
// to info so a misconfigured env var never silences the logs.
type LoggerConfig struct {
	Level       string
	Environment string
	Service     string
	// Writer is optional. When nil, os.Stdout is used. Tests inject a
	// bytes.Buffer here to capture output.
	Writer io.Writer
}

// InitLogger builds a JSON slog.Logger, installs it as the default, and
// returns it for callers that want an explicit reference. It must be
// called first in main() so every subsequent log line is structured.
func InitLogger(cfg LoggerConfig) *slog.Logger {
	writer := cfg.Writer
	if writer == nil {
		writer = os.Stdout
	}

	var handler slog.Handler = slog.NewJSONHandler(writer, &slog.HandlerOptions{
		Level: parseLevel(cfg.Level),
	})

	// Attach service + environment as base attributes so every record is
	// searchable in log aggregators without extra plumbing per call site.
	if cfg.Service != "" || cfg.Environment != "" {
		attrs := make([]slog.Attr, 0, 2)
		if cfg.Service != "" {
			attrs = append(attrs, slog.String("service", cfg.Service))
		}
		if cfg.Environment != "" {
			attrs = append(attrs, slog.String("env", cfg.Environment))
		}
		handler = handler.WithAttrs(attrs)
	}

	logger := slog.New(handler)
	slog.SetDefault(logger)
	return logger
}

// parseLevel converts a textual level to slog.Level. Invalid input maps
// to info rather than panicking — observability tooling should be lenient.
func parseLevel(raw string) slog.Level {
	switch strings.ToLower(strings.TrimSpace(raw)) {
	case "debug":
		return slog.LevelDebug
	case "warn", "warning":
		return slog.LevelWarn
	case "error":
		return slog.LevelError
	default:
		return slog.LevelInfo
	}
}
