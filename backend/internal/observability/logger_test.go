package observability

import (
	"bytes"
	"encoding/json"
	"log/slog"
	"strings"
	"testing"
)

func TestInitLoggerEmitsJSONWithExpectedFields(t *testing.T) {
	var buf bytes.Buffer
	logger := InitLogger(LoggerConfig{
		Level:       "debug",
		Environment: "test",
		Service:     "pepinillo-backend",
		Writer:      &buf,
	})

	logger.Info("hello world", "user_id", "abc-123", "count", 42)

	line := strings.TrimSpace(buf.String())
	if line == "" {
		t.Fatalf("expected log output, got empty string")
	}

	var record map[string]any
	if err := json.Unmarshal([]byte(line), &record); err != nil {
		t.Fatalf("expected valid JSON, got error %v; line=%s", err, line)
	}

	checks := map[string]string{
		"msg":     "hello world",
		"level":   "INFO",
		"service": "pepinillo-backend",
		"env":     "test",
		"user_id": "abc-123",
	}
	for key, expected := range checks {
		if got, ok := record[key].(string); !ok || got != expected {
			t.Errorf("field %q: expected %q, got %v", key, expected, record[key])
		}
	}

	if got, ok := record["count"].(float64); !ok || got != 42 {
		t.Errorf("field count: expected 42, got %v", record["count"])
	}
	if _, ok := record["time"]; !ok {
		t.Errorf("expected time field in JSON record")
	}
}

func TestInitLoggerRespectsLevel(t *testing.T) {
	var buf bytes.Buffer
	logger := InitLogger(LoggerConfig{
		Level:  "warn",
		Writer: &buf,
	})

	logger.Info("should be filtered")
	logger.Warn("should appear")

	out := buf.String()
	if strings.Contains(out, "should be filtered") {
		t.Errorf("info-level line leaked through warn filter: %s", out)
	}
	if !strings.Contains(out, "should appear") {
		t.Errorf("warn-level line missing from output: %s", out)
	}
}

func TestParseLevelFallsBackToInfo(t *testing.T) {
	cases := map[string]slog.Level{
		"":          slog.LevelInfo,
		"info":      slog.LevelInfo,
		"DEBUG":     slog.LevelDebug,
		"Warn":      slog.LevelWarn,
		"warning":   slog.LevelWarn,
		"error":     slog.LevelError,
		"nonsense":  slog.LevelInfo,
	}
	for input, want := range cases {
		if got := parseLevel(input); got != want {
			t.Errorf("parseLevel(%q) = %v, want %v", input, got, want)
		}
	}
}
