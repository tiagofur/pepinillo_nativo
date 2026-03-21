package handlers

import (
	"errors"
	"io"

	"github.com/gofiber/fiber/v2"

	"pepinillo/backend/internal/services"
)

type RevenueCatHandler struct {
	revenuecat *services.RevenueCatService
}

func NewRevenueCatHandler(revenuecat *services.RevenueCatService) *RevenueCatHandler {
	return &RevenueCatHandler{revenuecat: revenuecat}
}

// Webhook handles incoming RevenueCat webhook events
// POST /api/v1/webhooks/revenuecat
func (h *RevenueCatHandler) Webhook(c *fiber.Ctx) error {
	// Validate webhook authorization
	authHeader := c.Get("Authorization", "")
	if err := h.revenuecat.ValidateWebhookAuth(authHeader); err != nil {
		if errors.Is(err, services.ErrRevenueCatNotConfigured) {
			return fiber.NewError(fiber.StatusServiceUnavailable, "webhook_not_configured")
		}
		if errors.Is(err, services.ErrInvalidWebhookAuth) {
			return fiber.NewError(fiber.StatusUnauthorized, "invalid_webhook_auth")
		}
		return fiber.NewError(fiber.StatusUnauthorized, "invalid_authorization")
	}

	// Read body
	bodyBytes, err := io.ReadAll(c.Request().Body)
	if err != nil {
		return fiber.NewError(fiber.StatusBadRequest, "failed_to_read_body")
	}

	// Parse payload
	var payload services.RevenueCatWebhookPayload
	if err := c.App().Config().JSONDecoder(bodyBytes, &payload); err != nil {
		return fiber.NewError(fiber.StatusBadRequest, "invalid_request_body")
	}

	// Process webhook event
	if err := h.revenuecat.ProcessWebhookEvent(c.Context(), &payload); err != nil {
		// Log the error but still return 200 OK (RevenueCat expects fast responses)
		// The event is already logged via BehaviorLogger in the service
		if errors.Is(err, services.ErrUserNotFound) {
			// User not found is not a failure, just log it
			return c.SendStatus(fiber.StatusOK)
		}
		// For other errors, still return 200 OK to prevent RevenueCat retries
		// but the error is logged in the service
		return c.SendStatus(fiber.StatusOK)
	}

	return c.SendStatus(fiber.StatusOK)
}
