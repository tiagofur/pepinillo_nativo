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
		return c.Status(code).JSON(fiber.Map{"error": err.Error(), "code": "ERR_TIER_INSUFFICIENT"})
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

// buildBoundSyncTestApp simulates the middleware chain with a sync_device_id
// binding (#942 S5) and issues the request with an optional X-Device-ID.
func buildBoundSyncTestApp(tier string, expiresAt *time.Time, bound string) *fiber.App {
	app := fiber.New()
	app.Get("/sync/full", func(c *fiber.Ctx) error {
		c.Locals("tier", tier)
		c.Locals("subscription_expires_at", expiresAt)
		c.Locals("sync_device_id", bound)
		return c.Next()
	}, NewRequireBackendSync(), func(c *fiber.Ctx) error {
		return c.Status(fiber.StatusOK).JSON(fiber.Map{"ok": true})
	})
	return app
}

func doGetWithDevice(app *fiber.App, path, deviceID string) (*http.Response, []byte) {
	req := httptest.NewRequest(http.MethodGet, path, nil)
	if deviceID != "" {
		req.Header.Set("X-Device-ID", deviceID)
	}
	resp, err := app.Test(req)
	if err != nil {
		panic(err)
	}
	body, _ := io.ReadAll(resp.Body)
	defer resp.Body.Close()
	return resp, body
}

func doGet(app *fiber.App, path string) (*http.Response, []byte) {
	return doGetWithDevice(app, path, "")
}

// #942 S5: Free and Pepinillo+ no longer 402 outright — they sync in the
// device-bound lane (see the bound/unbound cases below). The 402 path now
// only serves expired Everywhere+ and fail-closed misconfiguration.

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
		return c.Status(code).JSON(fiber.Map{"error": err.Error(), "code": "ERR_TIER_INSUFFICIENT"})
	}})
	app.Get("/sync/full", NewRequireBackendSync(), func(c *fiber.Ctx) error {
		return c.Status(fiber.StatusOK).JSON(fiber.Map{"ok": true})
	})

	resp, body := doGet(app, "/sync/full")
	if resp.StatusCode != http.StatusPaymentRequired {
		t.Errorf("expected 402 when no locals set, got %d. body: %s", resp.StatusCode, body)
	}
}

// ---- #942 S5: device-bound backup lane ----

func TestRequireBackendSync_FreeUnbound_PassesAndClaimsOnUpload(t *testing.T) {
	app := buildBoundSyncTestApp("free", nil, "")
	resp, _ := doGetWithDevice(app, "/sync/full", "device-A")
	if resp.StatusCode != http.StatusOK {
		t.Errorf("expected 200 for unbound free tier, got %d", resp.StatusCode)
	}
}

func TestRequireBackendSync_FreeBoundSameDevice_Returns200(t *testing.T) {
	app := buildBoundSyncTestApp("free", nil, "device-A")
	resp, _ := doGetWithDevice(app, "/sync/full", "device-A")
	if resp.StatusCode != http.StatusOK {
		t.Errorf("expected 200 for bound device, got %d", resp.StatusCode)
	}
}

func TestRequireBackendSync_FreeBoundOtherDevice_Returns403(t *testing.T) {
	app := buildBoundSyncTestApp("free", nil, "device-A")
	resp, body := doGetWithDevice(app, "/sync/full", "device-B")
	if resp.StatusCode != http.StatusForbidden {
		t.Errorf("expected 403, got %d. body: %s", resp.StatusCode, body)
	}
	var payload map[string]any
	if err := json.Unmarshal(body, &payload); err != nil {
		t.Fatalf("response is not JSON: %s", body)
	}
	if payload["code"] != "ERR_DEVICE_BOUND" {
		t.Errorf("expected code=ERR_DEVICE_BOUND, got %v", payload["code"])
	}
	if payload["upgrade_url"] == nil {
		t.Errorf("expected upgrade_url in payload: %s", body)
	}
}

func TestRequireBackendSync_PepinilloPlusBoundSameDevice_Returns200(t *testing.T) {
	app := buildBoundSyncTestApp("pepinillo_plus", nil, "device-A")
	resp, _ := doGetWithDevice(app, "/sync/full", "device-A")
	if resp.StatusCode != http.StatusOK {
		t.Errorf("expected 200 for pepinillo_plus bound device, got %d", resp.StatusCode)
	}
}

func TestRequireBackendSync_PepinilloPlusBoundOtherDevice_Returns403(t *testing.T) {
	app := buildBoundSyncTestApp("pepinillo_plus", nil, "device-A")
	resp, _ := doGetWithDevice(app, "/sync/full", "device-B")
	if resp.StatusCode != http.StatusForbidden {
		t.Errorf("expected 403, got %d", resp.StatusCode)
	}
}

func TestRequireBackendSync_EverywhereIgnoresBinding_MultiDevice(t *testing.T) {
	// Everywhere+ is multi-device: any device id passes regardless of binding.
	app := buildBoundSyncTestApp("everywhere_monthly", nil, "device-A")
	resp, _ := doGetWithDevice(app, "/sync/full", "device-ZZ")
	if resp.StatusCode != http.StatusOK {
		t.Errorf("expected 200 for everywhere on any device, got %d", resp.StatusCode)
	}
}

func TestRequireBackendSync_FreeMissingHeader_PassesWhenUnbound(t *testing.T) {
	// A missing device header cannot match a binding — only unbound accounts
	// pass without a header (and the upload path never binds an empty id).
	app := buildBoundSyncTestApp("free", nil, "")
	resp, _ := doGetWithDevice(app, "/sync/full", "")
	if resp.StatusCode != http.StatusOK {
		t.Errorf("expected 200, got %d", resp.StatusCode)
	}
}

func TestRequireBackendSync_FreeMissingHeader_BoundDevice_Returns403(t *testing.T) {
	app := buildBoundSyncTestApp("free", nil, "device-A")
	resp, _ := doGetWithDevice(app, "/sync/full", "")
	if resp.StatusCode != http.StatusForbidden {
		t.Errorf("expected 403, got %d", resp.StatusCode)
	}
}
