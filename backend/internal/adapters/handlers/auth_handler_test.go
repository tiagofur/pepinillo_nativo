package handlers

import (
	"bytes"
	"context"
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
	"pepinillo/backend/internal/domain"
	"pepinillo/backend/internal/services"
)

type fakeUserRepository struct {
	byID    map[string]*domain.User
	byEmail map[string]*domain.User
}

func newFakeUserRepository() *fakeUserRepository {
	return &fakeUserRepository{byID: map[string]*domain.User{}, byEmail: map[string]*domain.User{}}
}

func (r *fakeUserRepository) Create(_ context.Context, user *domain.User) error {
	r.byID[user.ID] = user
	r.byEmail[user.Email] = user
	return nil
}

func (r *fakeUserRepository) GetByID(_ context.Context, userID string) (*domain.User, error) {
	if user, ok := r.byID[userID]; ok {
		return user, nil
	}
	return nil, nil
}

func (r *fakeUserRepository) GetByEmail(_ context.Context, email string) (*domain.User, error) {
	if user, ok := r.byEmail[email]; ok {
		return user, nil
	}
	return nil, nil
}

func (r *fakeUserRepository) Update(_ context.Context, user *domain.User) error {
	r.byID[user.ID] = user
	r.byEmail[user.Email] = user
	return nil
}

func (r *fakeUserRepository) Delete(_ context.Context, userID string) error {
	if user, ok := r.byID[userID]; ok {
		delete(r.byEmail, user.Email)
	}
	delete(r.byID, userID)
	return nil
}

func (r *fakeUserRepository) MarkEmailVerified(_ context.Context, userID string) error {
	if user, ok := r.byID[userID]; ok {
		user.EmailVerified = true
	}
	return nil
}

func (r *fakeUserRepository) UpdateEmailPending(_ context.Context, userID, newEmail string) error {
	if user, ok := r.byID[userID]; ok {
		user.PendingEmail = &newEmail
	}
	return nil
}

func (r *fakeUserRepository) ConfirmEmailChange(_ context.Context, userID, newEmail string) error {
	if user, ok := r.byID[userID]; ok {
		delete(r.byEmail, user.Email)
		user.Email = newEmail
		user.PendingEmail = nil
		user.EmailVerified = true
		r.byEmail[newEmail] = user
	}
	return nil
}

func (r *fakeUserRepository) RollbackEmailChange(_ context.Context, userID string) error {
	if user, ok := r.byID[userID]; ok {
		user.PendingEmail = nil
	}
	return nil
}

func (r *fakeUserRepository) GetByGoogleID(_ context.Context, googleID string) (*domain.User, error) {
	for _, user := range r.byID {
		if user.GoogleID != nil && *user.GoogleID == googleID {
			return user, nil
		}
	}
	return nil, nil
}

func (r *fakeUserRepository) GetByAppleID(_ context.Context, appleID string) (*domain.User, error) {
	for _, user := range r.byID {
		if user.AppleID != nil && *user.AppleID == appleID {
			return user, nil
		}
	}
	return nil, nil
}

func (r *fakeUserRepository) LinkGoogleAccount(_ context.Context, userID, googleID, email, name, picture string) error {
	if user, ok := r.byID[userID]; ok {
		user.GoogleID = &googleID
		user.GoogleEmail = &email
		user.GoogleName = &name
		user.GooglePicture = &picture
	}
	return nil
}

func (r *fakeUserRepository) UnlinkGoogleAccount(_ context.Context, userID string) error {
	if user, ok := r.byID[userID]; ok {
		user.GoogleID = nil
		user.GoogleEmail = nil
		user.GoogleName = nil
		user.GooglePicture = nil
	}
	return nil
}

func (r *fakeUserRepository) LinkAppleAccount(_ context.Context, userID, appleID, email, name string) error {
	if user, ok := r.byID[userID]; ok {
		user.AppleID = &appleID
		user.AppleEmail = &email
		user.AppleName = &name
	}
	return nil
}

func (r *fakeUserRepository) UnlinkAppleAccount(_ context.Context, userID string) error {
	if user, ok := r.byID[userID]; ok {
		user.AppleID = nil
		user.AppleEmail = nil
		user.AppleName = nil
	}
	return nil
}

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
