package handlers

import (
	"bytes"
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/gofiber/fiber/v2"
	"github.com/gofiber/fiber/v2/middleware/limiter"
	"github.com/golang-jwt/jwt/v5"

	"pepinillo/backend/internal/adapters/middleware"
)

// emailKeyGenerator: same email from many IPs must share a bucket.
func TestEmailKeyGenerator_SharesBucketAcrossIPs(t *testing.T) {
	app := fiber.New()
	byEmail := limiter.New(limiter.Config{
		Max:          3,
		Expiration:   time.Minute,
		KeyGenerator: emailKeyGenerator("test"),
	})
	app.Post("/login", byEmail, func(c *fiber.Ctx) error {
		return c.SendStatus(fiber.StatusOK)
	})

	body := mustJSON(map[string]any{"email": "target@example.com", "password": "whatever"})

	// 3 requests with rotating IPs — all should succeed (under Max=3).
	for i := 0; i < 3; i++ {
		req := httptest.NewRequest(http.MethodPost, "/login", bytes.NewReader(body))
		req.Header.Set("Content-Type", "application/json")
		req.Header.Set("X-Forwarded-For", fmt.Sprintf("10.0.0.%d", i+1))
		resp, err := app.Test(req, 5000)
		if err != nil {
			t.Fatalf("req %d: %v", i, err)
		}
		if resp.StatusCode != http.StatusOK {
			t.Fatalf("req %d: expected 200, got %d", i, resp.StatusCode)
		}
	}

	// 4th request with yet another IP — must be limited because same email.
	req := httptest.NewRequest(http.MethodPost, "/login", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("X-Forwarded-For", "10.0.0.99")
	resp, err := app.Test(req, 5000)
	if err != nil {
		t.Fatalf("final req: %v", err)
	}
	if resp.StatusCode != http.StatusTooManyRequests {
		t.Fatalf("expected 429 for credential-stuffing pattern, got %d", resp.StatusCode)
	}
}

// emailKeyGenerator: different emails from the same IP get separate buckets.
func TestEmailKeyGenerator_DifferentEmailsDoNotShare(t *testing.T) {
	app := fiber.New()
	byEmail := limiter.New(limiter.Config{
		Max:          2,
		Expiration:   time.Minute,
		KeyGenerator: emailKeyGenerator("test2"),
	})
	app.Post("/login", byEmail, func(c *fiber.Ctx) error {
		return c.SendStatus(fiber.StatusOK)
	})

	for i, email := range []string{"a@x.com", "b@x.com", "c@x.com", "d@x.com"} {
		body := mustJSON(map[string]any{"email": email})
		req := httptest.NewRequest(http.MethodPost, "/login", bytes.NewReader(body))
		req.Header.Set("Content-Type", "application/json")
		resp, err := app.Test(req, 5000)
		if err != nil {
			t.Fatalf("req %d: %v", i, err)
		}
		if resp.StatusCode != http.StatusOK {
			t.Fatalf("email %s: expected 200, got %d", email, resp.StatusCode)
		}
	}
}

// refreshTokenUserKeyGenerator: same userID across different IPs shares a bucket.
func TestRefreshTokenUserKeyGenerator_SharesBucketAcrossIPs(t *testing.T) {
	app := fiber.New()
	byUser := limiter.New(limiter.Config{
		Max:          2,
		Expiration:   time.Minute,
		KeyGenerator: refreshTokenUserKeyGenerator(),
	})
	app.Post("/refresh", byUser, func(c *fiber.Ctx) error {
		return c.SendStatus(fiber.StatusOK)
	})

	token := makeRefreshTokenForRateLimit(t, "user-42")
	body := mustJSON(map[string]any{"refreshToken": token})

	for i := 0; i < 2; i++ {
		req := httptest.NewRequest(http.MethodPost, "/refresh", bytes.NewReader(body))
		req.Header.Set("Content-Type", "application/json")
		req.Header.Set("X-Forwarded-For", fmt.Sprintf("192.0.2.%d", i+1))
		resp, err := app.Test(req, 5000)
		if err != nil {
			t.Fatalf("req %d: %v", i, err)
		}
		if resp.StatusCode != http.StatusOK {
			t.Fatalf("req %d: expected 200, got %d", i, resp.StatusCode)
		}
	}

	req := httptest.NewRequest(http.MethodPost, "/refresh", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("X-Forwarded-For", "192.0.2.99")
	resp, err := app.Test(req, 5000)
	if err != nil {
		t.Fatalf("final: %v", err)
	}
	if resp.StatusCode != http.StatusTooManyRequests {
		t.Fatalf("expected 429 for same-user refresh flood, got %d", resp.StatusCode)
	}
}

// unsafeUserIDFromJWT tolerates garbage without panicking.
func TestUnsafeUserIDFromJWT_RejectsGarbage(t *testing.T) {
	if uid := unsafeUserIDFromJWT("not-a-jwt"); uid != "" {
		t.Fatalf("expected empty uid, got %q", uid)
	}
	if uid := unsafeUserIDFromJWT(""); uid != "" {
		t.Fatalf("expected empty uid for empty token, got %q", uid)
	}
}

func mustJSON(v any) []byte {
	b, err := json.Marshal(v)
	if err != nil {
		panic(err)
	}
	return b
}

func makeRefreshTokenForRateLimit(t *testing.T, userID string) string {
	t.Helper()
	claims := middleware.UserClaims{
		UserID:    userID,
		TokenType: "refresh",
		RegisteredClaims: jwt.RegisteredClaims{
			ExpiresAt: jwt.NewNumericDate(time.Now().Add(time.Hour)),
		},
	}
	tok := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	signed, err := tok.SignedString([]byte("anything-we-are-not-verifying"))
	if err != nil {
		t.Fatalf("sign: %v", err)
	}
	return signed
}
