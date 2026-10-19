package handlers

import (
	"errors"

	"github.com/gofiber/fiber/v2"

	"pepinillo/backend/internal/services"
)

type BillingHandler struct {
	billing *services.BillingService
}

func NewBillingHandler(billing *services.BillingService) *BillingHandler {
	return &BillingHandler{billing: billing}
}

func (h *BillingHandler) VerifyReceipt(c *fiber.Ctx) error {
	userID, ok := c.Locals("userID").(string)
	if !ok || userID == "" {
		return fiber.NewError(fiber.StatusUnauthorized, "invalid_claims")
	}

	var req services.VerifyReceiptInput
	if err := c.BodyParser(&req); err != nil {
		return fiber.NewError(fiber.StatusBadRequest, "invalid_request_body")
	}

	result, err := h.billing.VerifyReceipt(c.Context(), userID, req)
	if err != nil {
		if errors.Is(err, services.ErrInvalidBillingPlatform) || errors.Is(err, services.ErrInvalidBillingPayload) || errors.Is(err, services.ErrUnsupportedProductID) || errors.Is(err, services.ErrInvalidReceipt) {
			return fiber.NewError(fiber.StatusBadRequest, err.Error())
		}
		if errors.Is(err, services.ErrBillingProviderNotConfigured) {
			return fiber.NewError(fiber.StatusServiceUnavailable, err.Error())
		}
		if errors.Is(err, services.ErrPurchaseTokenClaimed) {
			return fiber.NewError(fiber.StatusConflict, err.Error())
		}
		if errors.Is(err, services.ErrUserNotFound) {
			return fiber.NewError(fiber.StatusNotFound, err.Error())
		}
		return err
	}

	return c.JSON(result)
}
