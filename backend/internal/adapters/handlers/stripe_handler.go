package handlers

import (
	"errors"

	"github.com/gofiber/fiber/v2"

	"pepinillo/backend/internal/services"
)

// StripeHandler implements the contract endpoints under /billing/stripe.
// checkout-session and portal-session are JWT-protected (registered inside
// the protected billing group); the webhook is public (registered before the
// protected group, like /webhooks/revenuecat).
type StripeHandler struct {
	stripe *services.StripeService
}

func NewStripeHandler(stripe *services.StripeService) *StripeHandler {
	return &StripeHandler{stripe: stripe}
}

type stripeCheckoutRequest struct {
	Plan       string `json:"plan"`
	SuccessURL string `json:"successUrl,omitempty"`
	CancelURL  string `json:"cancelUrl,omitempty"`
}

func (h *StripeHandler) CheckoutSession(c *fiber.Ctx) error {
	userID, ok := c.Locals("userID").(string)
	if !ok || userID == "" {
		return fiber.NewError(fiber.StatusUnauthorized, "invalid_claims")
	}
	var req stripeCheckoutRequest
	if err := c.BodyParser(&req); err != nil {
		return fiber.NewError(fiber.StatusBadRequest, "invalid_request_body")
	}

	result, err := h.stripe.CreateCheckoutSession(c.Context(), userID, req.Plan, req.SuccessURL, req.CancelURL)
	if err != nil {
		return mapStripeError(err)
	}
	return c.JSON(result)
}

func (h *StripeHandler) PortalSession(c *fiber.Ctx) error {
	userID, ok := c.Locals("userID").(string)
	if !ok || userID == "" {
		return fiber.NewError(fiber.StatusUnauthorized, "invalid_claims")
	}
	result, err := h.stripe.CreatePortalSession(c.Context(), userID)
	if err != nil {
		return mapStripeError(err)
	}
	return c.JSON(result)
}

func (h *StripeHandler) Webhook(c *fiber.Ctx) error {
	input := services.StripeWebhookInput{
		Payload:   c.Body(),
		Signature: c.Get("Stripe-Signature"),
	}
	if err := h.stripe.HandleWebhook(c.Context(), input); err != nil {
		return mapStripeError(err)
	}
	return c.JSON(fiber.Map{"received": true})
}

func mapStripeError(err error) error {
	switch {
	case errors.Is(err, services.ErrStripeInvalidPlan), errors.Is(err, services.ErrStripeInvalidSignature):
		return fiber.NewError(fiber.StatusBadRequest, err.Error())
	case errors.Is(err, services.ErrStripeNotConfigured):
		return fiber.NewError(fiber.StatusServiceUnavailable, err.Error())
	case errors.Is(err, services.ErrStripeUnknownCustomer), errors.Is(err, services.ErrUserNotFound):
		return fiber.NewError(fiber.StatusNotFound, err.Error())
	case errors.Is(err, services.ErrStripeAPIFailed):
		return fiber.NewError(fiber.StatusBadGateway, err.Error())
	default:
		return err
	}
}
