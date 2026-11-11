package handlers

import (
	"context"
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/gofiber/fiber/v2"

	"pepinillo/backend/internal/domain"
)

type stubStatsRepo struct{}

func (stubStatsRepo) Compute(context.Context, time.Time) (*domain.InternalStats, error) {
	return &domain.InternalStats{
		Users:        domain.InternalStatsUsers{Total: 3, New30d: 1, Active7d: 2, Active30d: 3},
		Sessions:     domain.InternalStatsByMode{Total30d: 5, ByMode30d: map[string]int64{"pomodoro": 5, "flowtime": 0, "timeblock": 0, "stopwatch": 0}},
		FocusMinutes: domain.InternalStatsByMode{Total30d: 120, ByMode30d: map[string]int64{"pomodoro": 120, "flowtime": 0, "timeblock": 0, "stopwatch": 0}},
		BreakMinutes: domain.InternalStatsBreak{Total30d: 20},
		Tasks:        domain.InternalStatsTasks{Created30d: 9, Completed30d: 4},
	}, nil
}

func TestInternalStatsEndpoint(t *testing.T) {
	app := fiber.New()
	RegisterInternalRoutes(app, NewInternalStatsHandler(stubStatsRepo{}), "tok")

	do := func(auth string) *http.Response {
		req := httptest.NewRequest(http.MethodGet, "/internal/stats", nil)
		if auth != "" {
			req.Header.Set("Authorization", auth)
		}
		resp, err := app.Test(req)
		if err != nil {
			t.Fatal(err)
		}
		return resp
	}

	if got := do("Bearer wrong").StatusCode; got != 401 {
		t.Fatalf("wrong token status = %d, want 401", got)
	}
	if got := do("").StatusCode; got != 401 {
		t.Fatalf("missing header status = %d, want 401", got)
	}
	resp := do("Bearer tok")
	if cc := resp.Header.Get("Cache-Control"); cc != "no-store" {
		t.Fatalf("Cache-Control = %q, want no-store", cc)
	}
	if resp.StatusCode != 200 {
		t.Fatalf("status = %d, want 200", resp.StatusCode)
	}
	raw, _ := io.ReadAll(resp.Body)
	var body map[string]map[string]any
	if err := json.Unmarshal(raw, &body); err != nil {
		t.Fatal(err)
	}
	for _, k := range []string{"users", "sessions", "focusMinutes", "breakMinutes", "tasks"} {
		if _, ok := body[k]; !ok {
			t.Fatalf("missing key %q in %s", k, raw)
		}
	}
	if len(body) != 5 {
		t.Fatalf("unexpected root keys in %s", raw)
	}
	if body["users"]["active7d"].(float64) != 2 || body["tasks"]["completed30d"].(float64) != 4 {
		t.Fatalf("unexpected values: %s", raw)
	}
	if _, ok := body["sessions"]["byMode30d"].(map[string]any)["stopwatch"]; !ok {
		t.Fatalf("byMode30d must list all four modes: %s", raw)
	}
}

func TestInternalStatsEndpoint_EmptyTokenFailsClosed(t *testing.T) {
	app := fiber.New()
	RegisterInternalRoutes(app, NewInternalStatsHandler(stubStatsRepo{}), "")
	req := httptest.NewRequest(http.MethodGet, "/internal/stats", nil)
	req.Header.Set("Authorization", "Bearer ")
	resp, err := app.Test(req)
	if err != nil || resp.StatusCode != 401 {
		t.Fatalf("status=%v err=%v, want 401", resp, err)
	}
}
