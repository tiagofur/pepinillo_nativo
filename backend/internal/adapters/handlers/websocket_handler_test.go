package handlers

import (
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/gofiber/fiber/v2"
	"github.com/golang-jwt/jwt/v5"

	"pepinillo/backend/internal/adapters/middleware"
)

const testWSJWTSecret = "test-ws-secret"

// makeAccessToken builds a valid access JWT for the WebSocket tests.
func makeAccessToken(t *testing.T, userID string) string {
	t.Helper()
	claims := middleware.UserClaims{
		UserID:    userID,
		TokenType: "access",
		RegisteredClaims: jwt.RegisteredClaims{
			ExpiresAt: jwt.NewNumericDate(time.Now().Add(15 * time.Minute)),
		},
	}
	tok := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	signed, err := tok.SignedString([]byte(testWSJWTSecret))
	if err != nil {
		t.Fatalf("sign token: %v", err)
	}
	return signed
}

// wsTestApp mounts WebSocketUpgrade at /ws with a terminal handler that
// returns 200 + the resolved userID, so the test can verify the middleware
// accepted the token without actually opening a WebSocket.
func wsTestApp(allowQueryAuth bool) *fiber.App {
	h := NewWebSocketHandler(nil, testWSJWTSecret, allowQueryAuth)
	app := fiber.New()
	app.Get("/ws", h.WebSocketUpgrade, func(c *fiber.Ctx) error {
		uid, _ := c.Locals("userID").(string)
		return c.Status(fiber.StatusOK).SendString(uid)
	})
	return app
}

// wsUpgradeRequest builds a minimal WebSocket upgrade request so that
// fiberws.IsWebSocketUpgrade returns true.
func wsUpgradeRequest(path string) *http.Request {
	req := httptest.NewRequest(http.MethodGet, path, nil)
	req.Header.Set("Connection", "Upgrade")
	req.Header.Set("Upgrade", "websocket")
	req.Header.Set("Sec-WebSocket-Version", "13")
	req.Header.Set("Sec-WebSocket-Key", "dGhlIHNhbXBsZSBub25jZQ==")
	return req
}

func TestWebSocketUpgrade_AcceptsAuthorizationHeader(t *testing.T) {
	app := wsTestApp(false)
	token := makeAccessToken(t, "user-header")

	req := wsUpgradeRequest("/ws")
	req.Header.Set("Authorization", "Bearer "+token)

	resp, err := app.Test(req, 5000)
	if err != nil {
		t.Fatalf("request failed: %v", err)
	}
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("expected 200, got %d", resp.StatusCode)
	}
}

func TestWebSocketUpgrade_AcceptsSubprotocolHeader(t *testing.T) {
	app := wsTestApp(false)
	token := makeAccessToken(t, "user-subproto")

	req := wsUpgradeRequest("/ws")
	req.Header.Set("Sec-WebSocket-Protocol", "bearer, "+token)

	resp, err := app.Test(req, 5000)
	if err != nil {
		t.Fatalf("request failed: %v", err)
	}
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("expected 200, got %d", resp.StatusCode)
	}
	if got := resp.Header.Get("Sec-WebSocket-Protocol"); got != "bearer" {
		t.Fatalf("expected Sec-WebSocket-Protocol=bearer, got %q", got)
	}
}

func TestWebSocketUpgrade_RejectsQueryTokenByDefault(t *testing.T) {
	app := wsTestApp(false) // DEPRECATED_WS_QUERY_AUTH=false
	token := makeAccessToken(t, "user-query")

	req := wsUpgradeRequest("/ws?token=" + token)

	resp, err := app.Test(req, 5000)
	if err != nil {
		t.Fatalf("request failed: %v", err)
	}
	if resp.StatusCode != http.StatusUnauthorized {
		t.Fatalf("expected 401 when query auth disabled, got %d", resp.StatusCode)
	}
}

func TestWebSocketUpgrade_AcceptsQueryTokenWhenFlagEnabled(t *testing.T) {
	app := wsTestApp(true) // DEPRECATED_WS_QUERY_AUTH=true
	token := makeAccessToken(t, "user-deprecated")

	req := wsUpgradeRequest("/ws?token=" + token)

	resp, err := app.Test(req, 5000)
	if err != nil {
		t.Fatalf("request failed: %v", err)
	}
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("expected 200 when query auth enabled, got %d", resp.StatusCode)
	}
}

func TestWebSocketUpgrade_RejectsMissingToken(t *testing.T) {
	app := wsTestApp(false)

	req := wsUpgradeRequest("/ws")

	resp, err := app.Test(req, 5000)
	if err != nil {
		t.Fatalf("request failed: %v", err)
	}
	if resp.StatusCode != http.StatusUnauthorized {
		t.Fatalf("expected 401, got %d", resp.StatusCode)
	}
}

func TestWebSocketUpgrade_RejectsInvalidToken(t *testing.T) {
	app := wsTestApp(false)

	req := wsUpgradeRequest("/ws")
	req.Header.Set("Authorization", "Bearer not-a-valid-jwt")

	resp, err := app.Test(req, 5000)
	if err != nil {
		t.Fatalf("request failed: %v", err)
	}
	if resp.StatusCode != http.StatusUnauthorized {
		t.Fatalf("expected 401, got %d", resp.StatusCode)
	}
}

func TestWebSocketUpgrade_RejectsNonUpgradeRequest(t *testing.T) {
	app := wsTestApp(false)

	req := httptest.NewRequest(http.MethodGet, "/ws", nil)
	req.Header.Set("Authorization", "Bearer "+makeAccessToken(t, "u"))

	resp, err := app.Test(req, 5000)
	if err != nil {
		t.Fatalf("request failed: %v", err)
	}
	if resp.StatusCode != http.StatusUpgradeRequired {
		t.Fatalf("expected 426, got %d", resp.StatusCode)
	}
}
