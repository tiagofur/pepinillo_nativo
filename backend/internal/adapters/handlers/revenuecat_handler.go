package handlers

import (
	"errors"

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
	bodyBytes := c.Body()

	// Parse payload
	var payload services.RevenueCatWebhookPayload
	if err := c.App().Config().JSONDecoder(bodyBytes, &payload); err != nil {
		return fiber.NewError(fiber.StatusBadRequest, "invalid_request_body")
	}

	// Process webhook event
	if err := h.revenuecat.ProcessWebhookEvent(c.Context(), &payload); err != nil {
		if errors.Is(err, services.ErrUserNotFound) {
			// User not found is not a failure, just log it.
			return c.SendStatus(fiber.StatusOK)
		}
		if errors.Is(err, services.ErrInvalidBillingPayload) {
			// Permanently unprocessable: ack so RevenueCat drops it.
			return fiber.NewError(fiber.StatusBadRequest, err.Error())
		}
		// B2: transient failures (DB errors, downstream timeouts) must
		// return 5xx so RevenueCat retries. The old code returned 200 for
		// everything, permanently losing events (e.g. EXPIRATION).
		return fiber.NewError(fiber.StatusBadGateway, "webhook_processing_failed")
	}

	return c.SendStatus(fiber.StatusOK)
}
