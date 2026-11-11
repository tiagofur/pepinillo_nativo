package handlers

import (
	"bytes"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/gofiber/fiber/v2"

	"pepinillo/backend/internal/domain"
)

// S1: PUT /users/me must never change the email address — email changes go
// through the verified RequestEmailChange/ConfirmEmailChange flow.
func TestUserHandler_UpdateMe_RejectsEmailChange(t *testing.T) {
	users := newFakeUserRepository()
	_ = users.Create(t.Context(), &domain.User{ID: "user-1", Email: "old@example.com", Name: "Old"})
	handler := NewUserHandler(users, nil)

	app := fiber.New()
	app.Use(func(c *fiber.Ctx) error {
		c.Locals("userID", "user-1")
		return c.Next()
	})
	app.Put("/users/me", handler.UpdateMe)

	req := httptest.NewRequest(http.MethodPut, "/users/me", bytes.NewBufferString(`{"email":"victim@example.com","name":"New"}`))
	req.Header.Set("Content-Type", "application/json")

	resp, err := app.Test(req)
	if err != nil {
		t.Fatalf("expected request to be handled, got error: %v", err)
	}
	if resp.StatusCode != http.StatusBadRequest {
		t.Fatalf("expected %d, got %d", http.StatusBadRequest, resp.StatusCode)
	}

	user, _ := users.GetByID(t.Context(), "user-1")
	if user.Email != "old@example.com" {
		t.Fatalf("email must be unchanged, got %q", user.Email)
	}
	if user.Name != "Old" {
		t.Fatalf("no partial update expected on rejection, name is %q", user.Name)
	}
}

func TestUserHandler_UpdateMe_CapsNameLength(t *testing.T) {
	users := newFakeUserRepository()
	_ = users.Create(t.Context(), &domain.User{ID: "user-1", Email: "old@example.com", Name: "Old"})
	handler := NewUserHandler(users, nil)

	app := fiber.New()
	app.Use(func(c *fiber.Ctx) error {
		c.Locals("userID", "user-1")
		return c.Next()
	})
	app.Put("/users/me", handler.UpdateMe)

	req := httptest.NewRequest(http.MethodPut, "/users/me", bytes.NewBufferString(`{"name":"`+strings.Repeat("x", 5000)+`"}`))
	req.Header.Set("Content-Type", "application/json")

	resp, err := app.Test(req)
	if err != nil {
		t.Fatalf("expected request to be handled, got error: %v", err)
	}
	if resp.StatusCode != http.StatusBadRequest {
		t.Fatalf("expected %d, got %d", http.StatusBadRequest, resp.StatusCode)
	}
}

// S3: metricsOptIn persists, survives unrelated updates, and omitting it never
// changes consent.
func TestUserHandler_UpdateMe_MetricsOptIn(t *testing.T) {
	users := newFakeUserRepository()
	_ = users.Create(t.Context(), &domain.User{ID: "user-1", Email: "a@example.com", Name: "A"})
	app := fiber.New()
	app.Use(func(c *fiber.Ctx) error {
		c.Locals("userID", "user-1")
		return c.Next()
	})
	app.Put("/users/me", NewUserHandler(users, nil).UpdateMe)

	put := func(body string) {
		t.Helper()
		req := httptest.NewRequest(http.MethodPut, "/users/me", bytes.NewBufferString(body))
		req.Header.Set("Content-Type", "application/json")
		resp, err := app.Test(req)
		if err != nil || resp.StatusCode != http.StatusOK {
			t.Fatalf("PUT %s: status=%v err=%v", body, resp, err)
		}
	}
	optIn := func() bool {
		u, _ := users.GetByID(t.Context(), "user-1")
		return u.MetricsOptIn
	}

	if optIn() {
		t.Fatal("default must be opted out")
	}
	put(`{"metricsOptIn":true}`)
	if !optIn() {
		t.Fatal("opt-in not persisted")
	}
	put(`{"name":"Renamed"}`)
	if !optIn() {
		t.Fatal("unrelated update must not clear consent")
	}
	put(`{"metricsOptIn":false}`)
	if optIn() {
		t.Fatal("opt-out not persisted")
	}
}
