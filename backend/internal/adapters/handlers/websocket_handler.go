package handlers

import (
	fiberws "github.com/gofiber/contrib/websocket"
	"github.com/gofiber/fiber/v2"
	"github.com/golang-jwt/jwt/v5"

	"pepinillo/backend/internal/adapters/middleware"
	adapterws "pepinillo/backend/internal/adapters/websocket"
	"pepinillo/backend/internal/ports"
)

type WebSocketHandler struct {
	wsManager ports.WebSocketManager
	jwtSecret string
}

func NewWebSocketHandler(wsManager ports.WebSocketManager, jwtSecret string) *WebSocketHandler {
	return &WebSocketHandler{
		wsManager: wsManager,
		jwtSecret: jwtSecret,
	}
}

// WebSocketUpgrade validates the JWT query param and sets userID in locals before the WebSocket upgrade.
func (h *WebSocketHandler) WebSocketUpgrade(c *fiber.Ctx) error {
	if !fiberws.IsWebSocketUpgrade(c) {
		return fiber.ErrUpgradeRequired
	}

	token := c.Query("token")
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

	c.Locals("userID", claims.UserID)
	return c.Next()
}

// HandleWebSocket handles the WebSocket connection after JWT validation by WebSocketUpgrade.
func (h *WebSocketHandler) HandleWebSocket(c *fiberws.Conn) {
	userID, ok := c.Locals("userID").(string)
	if !ok || userID == "" {
		return
	}

	wsMgr, ok := h.wsManager.(*adapterws.Manager)
	if !ok {
		return
	}

	wsMgr.HandleFiberConn(c, userID)
}
