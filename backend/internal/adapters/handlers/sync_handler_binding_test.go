package handlers

import (
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/gofiber/fiber/v2"

	"pepinillo/backend/internal/domain"
)

// #942 S5: bind-on-upload — the first device to claim an unbound account
// wins; later claimants are silent no-ops (the guarded UPDATE decides).
func TestClaimSyncDeviceBinding_FirstWriterWins(t *testing.T) {
	users := &fakeUserRepository{
		byID:    map[string]*domain.User{"u1": {ID: "u1"}},
		byEmail: map[string]*domain.User{},
	}
	h := &SyncHandler{users: users}
	app := fiber.New()
	app.Post("/upload", func(c *fiber.Ctx) error {
		// SubscriptionMiddleware would set this; unbound here.
		c.Locals("sync_device_id", "")
		if err := h.claimSyncDeviceBinding(c, "u1"); err != nil {
			return err
		}
		return c.SendStatus(fiber.StatusOK)
	})

	req := httptest.NewRequest(http.MethodPost, "/upload", nil)
	req.Header.Set("X-Device-ID", "device-A")
	resp, err := app.Test(req)
	if err != nil {
		t.Fatal(err)
	}
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("expected 200, got %d", resp.StatusCode)
	}
	if got := users.boundDevices["u1"]; got != "device-A" {
		t.Fatalf("expected device-A to claim the binding, got %q", got)
	}

	// A later device is a silent no-op (locals stale is realistic: the gate
	// would have rejected it, but the guarded UPDATE is the backstop).
	req = httptest.NewRequest(http.MethodPost, "/upload", nil)
	req.Header.Set("X-Device-ID", "device-B")
	if _, err := app.Test(req); err != nil {
		t.Fatal(err)
	}
	if got := users.boundDevices["u1"]; got != "device-A" {
		t.Fatalf("expected binding to stay with device-A, got %q", got)
	}
}

func TestClaimSyncDeviceBinding_AlreadyBound_NoOp(t *testing.T) {
	users := &fakeUserRepository{
		byID:         map[string]*domain.User{"u1": {ID: "u1"}},
		byEmail:      map[string]*domain.User{},
		boundDevices: map[string]string{"u1": "device-A"},
	}
	h := &SyncHandler{users: users}
	app := fiber.New()
	app.Post("/upload", func(c *fiber.Ctx) error {
		c.Locals("sync_device_id", "device-A") // bound to us
		if err := h.claimSyncDeviceBinding(c, "u1"); err != nil {
			return err
		}
		return c.SendStatus(fiber.StatusOK)
	})
	req := httptest.NewRequest(http.MethodPost, "/upload", nil)
	req.Header.Set("X-Device-ID", "device-A")
	if _, err := app.Test(req); err != nil {
		t.Fatal(err)
	}
	if got := users.boundDevices["u1"]; got != "device-A" {
		t.Fatalf("expected binding unchanged, got %q", got)
	}
}

func TestClaimSyncDeviceBinding_MissingHeader_NoClaim(t *testing.T) {
	users := &fakeUserRepository{
		byID:    map[string]*domain.User{"u1": {ID: "u1"}},
		byEmail: map[string]*domain.User{},
	}
	h := &SyncHandler{users: users}
	app := fiber.New()
	app.Post("/upload", func(c *fiber.Ctx) error {
		c.Locals("sync_device_id", "")
		if err := h.claimSyncDeviceBinding(c, "u1"); err != nil {
			return err
		}
		return c.SendStatus(fiber.StatusOK)
	})
	req := httptest.NewRequest(http.MethodPost, "/upload", nil)
	if _, err := app.Test(req); err != nil {
		t.Fatal(err)
	}
	if got, ok := users.boundDevices["u1"]; ok && got != "" {
		t.Fatalf("expected no claim without a device header, got %q", got)
	}
}
