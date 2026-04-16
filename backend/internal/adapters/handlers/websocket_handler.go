package handlers

import (
	"log/slog"
	"strings"

	fiberws "github.com/gofiber/contrib/websocket"
	"github.com/gofiber/fiber/v2"
	"github.com/golang-jwt/jwt/v5"

	"pepinillo/backend/internal/adapters/middleware"
	adapterws "pepinillo/backend/internal/adapters/websocket"
	"pepinillo/backend/internal/ports"
)

type WebSocketHandler struct {
	wsManager        ports.WebSocketManager
	jwtSecret        string
	allowQueryAuth   bool // DEPRECATED_WS_QUERY_AUTH — remove in v1.1
}

// NewWebSocketHandler builds a WebSocket handler.
//
// allowQueryAuth toggles the legacy ?token= query-param fallback. It exists
// only to keep older native clients booting during the header-auth rollout and
// is scheduled for removal in v1.1. Default (false) enforces header-only auth.
func NewWebSocketHandler(wsManager ports.WebSocketManager, jwtSecret string, allowQueryAuth bool) *WebSocketHandler {
	return &WebSocketHandler{
		wsManager:      wsManager,
		jwtSecret:      jwtSecret,
		allowQueryAuth: allowQueryAuth,
	}
}

// WebSocketUpgrade authenticates the handshake and sets userID in locals before
// the WebSocket upgrade. Supported token sources, in order:
//
//  1. Authorization: Bearer <token> header — the primary supported form.
//  2. Sec-WebSocket-Protocol: bearer, <token> — browser workaround, since the
//     WebSocket API does not let JS set arbitrary headers but does allow a
//     sub-protocol list. We echo "bearer" back on acceptance.
//  3. ?token=<token> query param — DEPRECATED, only honoured when
//     DEPRECATED_WS_QUERY_AUTH=true. Logs a warning on every use.
func (h *WebSocketHandler) WebSocketUpgrade(c *fiber.Ctx) error {
	if !fiberws.IsWebSocketUpgrade(c) {
		return fiber.ErrUpgradeRequired
	}

	token, subprotocolAck := extractWSToken(c, h.allowQueryAuth)
	if token == "" {
		return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{
			"error": "missing_token",
		})
	}

	parsedToken, err := jwt.ParseWithClaims(token, &middleware.UserClaims{}, func(token *jwt.Token) (any, error) {
		return []byte(h.jwtSecret), nil
	})
	if err != nil || !parsedToken.Valid {
		return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{
			"error": "invalid_token",
		})
	}

	claims, ok := parsedToken.Claims.(*middleware.UserClaims)
	if !ok || claims.UserID == "" || claims.TokenType != "access" {
		return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{
			"error": "invalid_claims",
		})
	}

	// When the client used the Sec-WebSocket-Protocol trick, echo "bearer" back
	// per RFC 6455 so the browser's WebSocket accepts the handshake.
	if subprotocolAck {
		c.Set("Sec-WebSocket-Protocol", "bearer")
	}

	c.Locals("userID", claims.UserID)
	c.Locals("deviceID", c.Query("deviceId", ""))
	return c.Next()
}

// extractWSToken resolves the JWT from (in order) the Authorization header, the
// Sec-WebSocket-Protocol header, and finally the ?token= query param (only
// when allowQueryAuth is true). The boolean result is true when the caller
// must echo "bearer" back as the accepted sub-protocol.
func extractWSToken(c *fiber.Ctx, allowQueryAuth bool) (string, bool) {
	if authHeader := c.Get("Authorization"); authHeader != "" {
		if token, ok := parseBearer(authHeader); ok {
			return token, false
		}
	}

	// Browsers can't set Authorization on a WebSocket handshake, but they CAN
	// send a sub-protocol list. Convention: `Sec-WebSocket-Protocol: bearer, <jwt>`.
	if proto := c.Get("Sec-WebSocket-Protocol"); proto != "" {
		parts := strings.Split(proto, ",")
		if len(parts) >= 2 && strings.EqualFold(strings.TrimSpace(parts[0]), "bearer") {
			return strings.TrimSpace(parts[1]), true
		}
	}

	if allowQueryAuth {
		if token := c.Query("token"); token != "" {
			slog.Warn("DEPRECATION: WebSocket connection authenticated via query param — set DEPRECATED_WS_QUERY_AUTH=false and migrate clients to Authorization header (removal in v1.1)",
				"remoteIp", c.IP(),
			)
			return token, false
		}
	}

	return "", false
}

func parseBearer(header string) (string, bool) {
	parts := strings.SplitN(header, " ", 2)
	if len(parts) != 2 || !strings.EqualFold(parts[0], "bearer") {
		return "", false
	}
	token := strings.TrimSpace(parts[1])
	if token == "" {
		return "", false
	}
	return token, true
}

// HandleWebSocket handles the WebSocket connection after JWT validation by WebSocketUpgrade.
func (h *WebSocketHandler) HandleWebSocket(c *fiberws.Conn) {
	userID, ok := c.Locals("userID").(string)
	if !ok || userID == "" {
		return
	}

	deviceID, _ := c.Locals("deviceID").(string)

	wsMgr, ok := h.wsManager.(*adapterws.Manager)
	if !ok {
		return
	}

	wsMgr.HandleFiberConn(c, userID, deviceID)
}
