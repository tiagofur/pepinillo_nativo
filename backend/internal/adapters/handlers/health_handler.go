package handlers

import (
	"context"
	"fmt"
	"sync"
	"time"

	"github.com/gofiber/fiber/v2"

	"pepinillo/backend/internal/observability"
)

type healthResponse struct {
	Status    string `json:"status"`
	Service   string `json:"service"`
	Timestamp string `json:"timestamp"`
}

type DependencyChecks struct {
	Database func(context.Context) error
	Redis    func(context.Context) error
	MinIO    func(context.Context) error
	ML       func(context.Context) error
}

func DependencyChecksFrom(
	database func(context.Context) error,
	redis func(context.Context) error,
	minio func(context.Context) error,
	ml func(context.Context) error,
) DependencyChecks {
	return DependencyChecks{Database: database, Redis: redis, MinIO: minio, ML: ml}
}

type dependencyStatus struct {
	Status string `json:"status"`
	Error  string `json:"error,omitempty"`
}

type alertManagerAlert struct {
	Status       string            `json:"status"`
	Labels       map[string]string `json:"labels"`
	Annotations  map[string]string `json:"annotations"`
	StartsAt     string            `json:"startsAt"`
	GeneratorURL string            `json:"generatorURL"`
}

func mapToAlertManagerAlerts(alerts []observability.Alert, generatorURL string, now time.Time) []alertManagerAlert {
	out := make([]alertManagerAlert, 0, len(alerts))
	for _, a := range alerts {
		out = append(out, alertManagerAlert{
			Status: "firing",
			Labels: map[string]string{
				"alertname": a.Code,
				"severity":  a.Severity,
				"service":   "pepinillo-backend",
			},
			Annotations: map[string]string{
				"summary":   a.Message,
				"value":     fmt.Sprintf("%d", a.Value),
				"threshold": fmt.Sprintf("%d", a.Threshold),
			},
			StartsAt:     now.UTC().Format(time.RFC3339),
			GeneratorURL: generatorURL,
		})
	}
	return out
}

func RegisterHealthRoutes(router fiber.Router, checks DependencyChecks) {
	router.Get("/health", func(c *fiber.Ctx) error {
		return c.JSON(healthResponse{
			Status:    "ok",
			Service:   "pepinillo-backend",
			Timestamp: time.Now().UTC().Format(time.RFC3339),
		})
	})

	router.Get("/health/deps", func(c *fiber.Ctx) error {
		ctx, cancel := context.WithTimeout(c.Context(), 3*time.Second)
		defer cancel()

		statuses := map[string]dependencyStatus{
			"database": {Status: "unknown"},
			"redis":    {Status: "unknown"},
			"minio":    {Status: "unknown"},
			"ml":       {Status: "unknown"},
		}

		type checkItem struct {
			name string
			fn   func(context.Context) error
		}
		items := []checkItem{
			{name: "database", fn: checks.Database},
			{name: "redis", fn: checks.Redis},
			{name: "minio", fn: checks.MinIO},
			{name: "ml", fn: checks.ML},
		}

		var wg sync.WaitGroup
		var mu sync.Mutex
		overall := "ok"

		for _, item := range items {
			wg.Add(1)
			go func(it checkItem) {
				defer wg.Done()
				if it.fn == nil {
					mu.Lock()
					statuses[it.name] = dependencyStatus{Status: "disabled"}
					mu.Unlock()
					return
				}
				err := it.fn(ctx)
				mu.Lock()
				defer mu.Unlock()
				if err != nil {
					overall = "degraded"
					statuses[it.name] = dependencyStatus{Status: "error", Error: err.Error()}
					return
				}
				statuses[it.name] = dependencyStatus{Status: "ok"}
			}(item)
		}
		wg.Wait()

		return c.JSON(fiber.Map{
			"status":       overall,
			"service":      "pepinillo-backend",
			"timestamp":    time.Now().UTC().Format(time.RFC3339),
			"dependencies": statuses,
		})
	})

	router.Get("/health/metrics", func(c *fiber.Ctx) error {
		return c.JSON(fiber.Map{
			"status":    "ok",
			"service":   "pepinillo-backend",
			"timestamp": time.Now().UTC().Format(time.RFC3339),
			"metrics":   observability.Snapshot(),
		})
	})

	router.Get("/health/metrics/prometheus", func(c *fiber.Ctx) error {
		c.Set("Content-Type", "text/plain; version=0.0.4")
		return c.SendString(observability.PrometheusText())
	})

	router.Get("/health/alerts", func(c *fiber.Ctx) error {
		eval := observability.EvaluateManagedAlerts()
		status := "ok"
		if len(eval.Alerts) > 0 {
			status = "degraded"
		} else if len(eval.Suppressed) > 0 {
			status = "suppressed"
		}
		return c.JSON(fiber.Map{
			"status":     status,
			"service":    "pepinillo-backend",
			"timestamp":  time.Now().UTC().Format(time.RFC3339),
			"alerts":     eval.Alerts,
			"suppressed": eval.Suppressed,
			"remediation": fiber.Map{
				"muteActive":  eval.MuteActive,
				"cooldownSec": eval.CooldownSec,
				"evaluatedAt": eval.EvaluatedAt,
			},
		})
	})

	router.Get("/health/alerts/rules", func(c *fiber.Ctx) error {
		return c.JSON(fiber.Map{
			"status":    "ok",
			"service":   "pepinillo-backend",
			"timestamp": time.Now().UTC().Format(time.RFC3339),
			"rules":     observability.CurrentAlertRules(),
		})
	})

	router.Get("/health/alerts/alertmanager", func(c *fiber.Ctx) error {
		eval := observability.EvaluateManagedAlerts()
		payload := mapToAlertManagerAlerts(eval.Alerts, c.BaseURL()+"/api/v1/health/alerts", time.Now().UTC())
		return c.JSON(fiber.Map{
			"status":          "ok",
			"service":         "pepinillo-backend",
			"timestamp":       time.Now().UTC().Format(time.RFC3339),
			"alerts":          payload,
			"suppressedCount": len(eval.Suppressed),
		})
	})

	router.Get("/health/slo", func(c *fiber.Ctx) error {
		slo := observability.EvaluateSLO()
		status := "ok"
		for _, s := range slo {
			if s.Status == "degraded" {
				status = "degraded"
				break
			}
		}
		return c.JSON(fiber.Map{
			"status":    status,
			"service":   "pepinillo-backend",
			"timestamp": time.Now().UTC().Format(time.RFC3339),
			"slo":       slo,
		})
	})
}
