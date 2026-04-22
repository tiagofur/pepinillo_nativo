package middleware

import (
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/gofiber/fiber/v2"
)

// buildSyncTestApp creates a minimal Fiber app that simulates the middleware
// chain: it pre-populates Locals (as SubscriptionMiddleware would) then runs
// RequireBackendSync, then a 200 handler.
func buildSyncTestApp(tier string, expiresAt *time.Time) *fiber.App {
	app := fiber.New(fiber.Config{ErrorHandler: func(c *fiber.Ctx, err error) error {
		code := fiber.StatusInternalServerError
		if e, ok := err.(*fiber.Error); ok {
			code = e.Code
		}
		return c.Status(code).JSON(fiber.Map{"error": err.Error()})
	}})

	app.Get("/sync/full", func(c *fiber.Ctx) error {
		// Simulate what SubscriptionMiddleware sets.
		c.Locals("tier", tier)
		c.Locals("subscription_expires_at", expiresAt)
		return c.Next()
	}, NewRequireBackendSync(), func(c *fiber.Ctx) error {
		return c.Status(fiber.StatusOK).JSON(fiber.Map{"ok": true})
	})

	return app
}

func doGet(app *fiber.App, path string) (*http.Response, []byte) {
	req := httptest.NewRequest(http.MethodGet, path, nil)
	resp, err := app.Test(req)
	if err != nil {
		panic(err)
	}
	body, _ := io.ReadAll(resp.Body)
	defer resp.Body.Close()
	return resp, body
}

func TestRequireBackendSync_FreeTier_Returns402(t *testing.T) {
	app := buildSyncTestApp("free", nil)
	resp, body := doGet(app, "/sync/full")
	if resp.StatusCode != http.StatusPaymentRequired {
		t.Errorf("expected 402, got %d. body: %s", resp.StatusCode, body)
	}
	var payload map[string]any
	if err := json.Unmarshal(body, &payload); err != nil {
		t.Fatalf("response is not JSON: %s", body)
	}
	if payload["code"] != "ERR_TIER_INSUFFICIENT" {
		t.Errorf("expected code=ERR_TIER_INSUFFICIENT, got %v", payload["code"])
	}
}

func TestRequireBackendSync_PepinilloPlus_Returns402(t *testing.T) {
	app := buildSyncTestApp("pepinillo_plus", nil)
	resp, body := doGet(app, "/sync/full")
	if resp.StatusCode != http.StatusPaymentRequired {
		t.Errorf("expected 402, got %d. body: %s", resp.StatusCode, body)
	}
	var payload map[string]any
	if err := json.Unmarshal(body, &payload); err != nil {
		t.Fatalf("response is not JSON: %s", body)
	}
	if payload["code"] != "ERR_TIER_INSUFFICIENT" {
		t.Errorf("expected code=ERR_TIER_INSUFFICIENT, got %v", payload["code"])
	}
}

func TestRequireBackendSync_EverywhereMonthlyActive_Returns200(t *testing.T) {
	future := time.Now().Add(30 * 24 * time.Hour)
	app := buildSyncTestApp("everywhere_monthly", &future)
	resp, _ := doGet(app, "/sync/full")
	if resp.StatusCode != http.StatusOK {
		t.Errorf("expected 200, got %d", resp.StatusCode)
	}
}

func TestRequireBackendSync_EverywhereAnnualActive_Returns200(t *testing.T) {
	future := time.Now().Add(365 * 24 * time.Hour)
	app := buildSyncTestApp("everywhere_annual", &future)
	resp, _ := doGet(app, "/sync/full")
	if resp.StatusCode != http.StatusOK {
		t.Errorf("expected 200, got %d", resp.StatusCode)
	}
}

func TestRequireBackendSync_EverywhereLifetime_Returns200(t *testing.T) {
	// Lifetime has no expiry.
	app := buildSyncTestApp("everywhere_lifetime", nil)
	resp, _ := doGet(app, "/sync/full")
	if resp.StatusCode != http.StatusOK {
		t.Errorf("expected 200, got %d", resp.StatusCode)
	}
}

func TestRequireBackendSync_ExpiredEverywhere_Returns402(t *testing.T) {
	past := time.Now().Add(-24 * time.Hour)
	app := buildSyncTestApp("everywhere_monthly", &past)
	resp, body := doGet(app, "/sync/full")
	if resp.StatusCode != http.StatusPaymentRequired {
		t.Errorf("expected 402, got %d. body: %s", resp.StatusCode, body)
	}
	var payload map[string]any
	if err := json.Unmarshal(body, &payload); err != nil {
		t.Fatalf("response is not JSON: %s", body)
	}
	if payload["code"] != "ERR_TIER_INSUFFICIENT" {
		t.Errorf("expected code=ERR_TIER_INSUFFICIENT, got %v", payload["code"])
	}
}

func TestRequireBackendSync_NoTierLocals_Returns402(t *testing.T) {
	// When no Locals are set (missing subscription middleware), should 402.
	app := fiber.New(fiber.Config{ErrorHandler: func(c *fiber.Ctx, err error) error {
		code := fiber.StatusInternalServerError
		if e, ok := err.(*fiber.Error); ok {
			code = e.Code
		}
		return c.Status(code).JSON(fiber.Map{"error": err.Error()})
	}})
	app.Get("/sync/full", NewRequireBackendSync(), func(c *fiber.Ctx) error {
		return c.Status(fiber.StatusOK).JSON(fiber.Map{"ok": true})
	})

	resp, body := doGet(app, "/sync/full")
	if resp.StatusCode != http.StatusPaymentRequired {
		t.Errorf("expected 402 when no locals set, got %d. body: %s", resp.StatusCode, body)
	}
}
