package handlers

import (
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/gofiber/fiber/v2"
)

func TestHealthMetricsRoutes(t *testing.T) {
	app := fiber.New()
	RegisterHealthRoutes(app, DependencyChecks{})

	reqJSON := httptest.NewRequest(http.MethodGet, "/health/metrics", nil)
	respJSON, err := app.Test(reqJSON)
	if err != nil {
		t.Fatalf("metrics json request failed: %v", err)
	}
	if respJSON.StatusCode != fiber.StatusOK {
		t.Fatalf("expected 200 for /health/metrics, got %d", respJSON.StatusCode)
	}

	reqProm := httptest.NewRequest(http.MethodGet, "/health/metrics/prometheus", nil)
	respProm, err := app.Test(reqProm)
	if err != nil {
		t.Fatalf("metrics prometheus request failed: %v", err)
	}
	if respProm.StatusCode != fiber.StatusOK {
		t.Fatalf("expected 200 for /health/metrics/prometheus, got %d", respProm.StatusCode)
	}

	reqAlerts := httptest.NewRequest(http.MethodGet, "/health/alerts", nil)
	respAlerts, err := app.Test(reqAlerts)
	if err != nil {
		t.Fatalf("alerts request failed: %v", err)
	}
	if respAlerts.StatusCode != fiber.StatusOK {
		t.Fatalf("expected 200 for /health/alerts, got %d", respAlerts.StatusCode)
	}

	reqRules := httptest.NewRequest(http.MethodGet, "/health/alerts/rules", nil)
	respRules, err := app.Test(reqRules)
	if err != nil {
		t.Fatalf("alerts rules request failed: %v", err)
	}
	if respRules.StatusCode != fiber.StatusOK {
		t.Fatalf("expected 200 for /health/alerts/rules, got %d", respRules.StatusCode)
	}

	reqAM := httptest.NewRequest(http.MethodGet, "/health/alerts/alertmanager", nil)
	respAM, err := app.Test(reqAM)
	if err != nil {
		t.Fatalf("alerts alertmanager request failed: %v", err)
	}
	if respAM.StatusCode != fiber.StatusOK {
		t.Fatalf("expected 200 for /health/alerts/alertmanager, got %d", respAM.StatusCode)
	}

	reqSLO := httptest.NewRequest(http.MethodGet, "/health/slo", nil)
	respSLO, err := app.Test(reqSLO)
	if err != nil {
		t.Fatalf("slo request failed: %v", err)
	}
	if respSLO.StatusCode != fiber.StatusOK {
		t.Fatalf("expected 200 for /health/slo, got %d", respSLO.StatusCode)
	}
}
