package handlers

import (
	"bytes"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/gofiber/fiber/v2"
)

func TestOAuthHandler_LoginWithApple_RequiresNonce(t *testing.T) {
	app := fiber.New()
	handler := NewOAuthHandler(nil)
	app.Post("/auth/apple", handler.LoginWithApple)

	req := httptest.NewRequest(http.MethodPost, "/auth/apple", bytes.NewBufferString(`{"idToken":"some-token"}`))
	req.Header.Set("Content-Type", "application/json")

	resp, err := app.Test(req)
	if err != nil {
		t.Fatalf("expected request to be handled, got error: %v", err)
	}
	if resp.StatusCode != http.StatusBadRequest {
		t.Fatalf("expected %d, got %d", http.StatusBadRequest, resp.StatusCode)
	}
}

// TestOAuthHandler_LinkAppleAccount_RequiresNonce covers the F2 fix: a stolen
// Apple ID token must NOT be replayable against POST /auth/link/apple within
// the 10-minute appleTokenMaxAge window. The handler must reject any link
// request that omits the nonce with HTTP 400 missing_required_fields, mirroring
// the LoginWithApple contract.
func TestOAuthHandler_LinkAppleAccount_RequiresNonce(t *testing.T) {
	cases := []struct {
		name string
		body string
	}{
		{
			name: "missing nonce entirely",
			body: `{"idToken":"some-token"}`,
		},
		{
			name: "empty nonce string",
			body: `{"idToken":"some-token","nonce":""}`,
		},
		{
			name: "missing idToken too",
			body: `{}`,
		},
	}

	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			app := fiber.New()
			handler := NewOAuthHandler(nil)
			// Stub userID via Locals so the handler reaches the body check
			// instead of returning 401 invalid_claims.
			app.Use(func(c *fiber.Ctx) error {
				c.Locals("userID", "user-123")
				return c.Next()
			})
			app.Post("/auth/link/apple", handler.LinkAppleAccount)

			req := httptest.NewRequest(http.MethodPost, "/auth/link/apple", bytes.NewBufferString(tc.body))
			req.Header.Set("Content-Type", "application/json")

			resp, err := app.Test(req)
			if err != nil {
				t.Fatalf("expected request to be handled, got error: %v", err)
			}
			if resp.StatusCode != http.StatusBadRequest {
				t.Fatalf("expected %d for %s, got %d", http.StatusBadRequest, tc.name, resp.StatusCode)
			}
		})
	}
}

