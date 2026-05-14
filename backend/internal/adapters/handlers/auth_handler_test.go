package handlers

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/gofiber/fiber/v2"
	"github.com/gofiber/fiber/v2/middleware/limiter"

	"pepinillo/backend/internal/adapters/behavior"
	"pepinillo/backend/internal/adapters/notifier"
	"pepinillo/backend/internal/adapters/stores/memory"
	"pepinillo/backend/internal/services"
)


func makeAuthApp() *fiber.App {
	repo := newFakeUserRepository()
	authService := services.NewAuthService(
		repo,
		memory.NewAuthStore(),
		notifier.NewLogNotifier(),
		behavior.NewNoopLogger(),
		nil, // wsManager not needed for handler tests
		"test-secret",
		"test-issuer",
		900,
		3600,
	)
	handler := NewAuthHandler(authService)

	app := fiber.New(fiber.Config{
		ErrorHandler:  ErrorHandler,
		ReadTimeout:   10 * time.Second,
		WriteTimeout:  10 * time.Second,
		IdleTimeout:   10 * time.Second,
	})
	auth := app.Group("/api/v1/auth")
	loginRegisterLimiter := limiter.New(limiter.Config{Max: 5})
	auth.Post("/register", loginRegisterLimiter, handler.Register)
	auth.Post("/login", loginRegisterLimiter, handler.Login)
	auth.Post("/refresh", handler.Refresh)
	auth.Post("/forgot-password", handler.ForgotPassword)
	auth.Post("/reset-password", handler.ResetPassword)
	return app
}

// testTimeout is the timeout in ms for app.Test() calls.
// Fiber defaults to 1000ms which is too short for CI environments.
const testTimeout = 10000

func TestAuthRegisterAndLoginHTTP(t *testing.T) {
	app := makeAuthApp()

	registerPayload := map[string]any{
		"email":    "http@test.com",
		"name":     "HTTP User",
		"password": "Password123",
	}
	body, _ := json.Marshal(registerPayload)
	req := httptest.NewRequest(http.MethodPost, "/api/v1/auth/register", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	resp, err := app.Test(req, testTimeout)
	if err != nil {
		t.Fatalf("register request failed: %v", err)
	}
	if resp.StatusCode != http.StatusCreated {
		t.Fatalf("expected 201, got %d", resp.StatusCode)
	}

	loginPayload := map[string]any{
		"email":    "http@test.com",
		"password": "Password123",
	}
	body, _ = json.Marshal(loginPayload)
	req = httptest.NewRequest(http.MethodPost, "/api/v1/auth/login", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	resp, err = app.Test(req, testTimeout)
	if err != nil {
		t.Fatalf("login request failed: %v", err)
	}
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("expected 200, got %d", resp.StatusCode)
	}
}

func TestAuthLoginRateLimitHTTP(t *testing.T) {
	app := makeAuthApp()

	payload := map[string]any{
		"email":    "missing@test.com",
		"password": "password123",
	}
	body, _ := json.Marshal(payload)

	for i := 0; i < 5; i++ {
		req := httptest.NewRequest(http.MethodPost, "/api/v1/auth/login", bytes.NewReader(body))
		req.Header.Set("Content-Type", "application/json")
		_, err := app.Test(req, testTimeout)
		if err != nil {
			t.Fatalf("login request %d failed: %v", i+1, err)
		}
	}

	req := httptest.NewRequest(http.MethodPost, "/api/v1/auth/login", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	resp, err := app.Test(req, testTimeout)
	if err != nil {
		t.Fatalf("limited login request failed: %v", err)
	}
	if resp.StatusCode != http.StatusTooManyRequests {
		t.Fatalf("expected 429 after limit, got %d", resp.StatusCode)
	}
}
