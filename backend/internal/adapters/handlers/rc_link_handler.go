package handlers

import (
	"errors"
	"time"

	"github.com/gofiber/fiber/v2"

	"pepinillo/backend/internal/services"
)

// RcLinkHandler implements the #953 license-bridge endpoints:
//   - POST /account/link-code (JWT): web account generates the claim code.
//   - POST /rc/link (public): the native app claims it with its RC
//     app_user_id; entitlement is verified server-side against RevenueCat.
type RcLinkHandler struct {
	link *services.RcLinkService
}

func NewRcLinkHandler(link *services.RcLinkService) *RcLinkHandler {
	return &RcLinkHandler{link: link}
}

func (h *RcLinkHandler) CreateCode(c *fiber.Ctx) error {
	userID, ok := c.Locals("userID").(string)
	if !ok || userID == "" {
		return fiber.NewError(fiber.StatusUnauthorized, "invalid_claims")
	}
	code, expiresAt, err := h.link.CreateLinkCode(c.Context(), userID)
	if err != nil {
		return fiber.NewError(fiber.StatusServiceUnavailable, "rc_link_unavailable")
	}
	return c.JSON(fiber.Map{
		"code":      code,
		"expiresAt": expiresAt.UTC().Format(time.RFC3339Nano),
	})
}

type rcLinkClaimRequest struct {
	Code      string `json:"code"`
	AppUserID string `json:"appUserId"`
	Platform  string `json:"platform,omitempty"`
}

func (h *RcLinkHandler) Claim(c *fiber.Ctx) error {
	var req rcLinkClaimRequest
	if err := c.BodyParser(&req); err != nil {
		return fiber.NewError(fiber.StatusBadRequest, "invalid_request_body")
	}

	user, tier, expiresAt, err := h.link.ClaimLinkCode(c.Context(), req.Code, req.AppUserID)
	if err != nil {
		return mapRcLinkError(err)
	}

	resp := fiber.Map{
		"userId": user.ID,
		"tier":   tier,
	}
	if expiresAt != nil {
		resp["expiresAt"] = expiresAt.UTC().Format(time.RFC3339Nano)
	}
	return c.JSON(resp)
}

// mapRcLinkError keeps the public surface coarse: invalid code and absent
// entitlement share one 404 so the endpoint can't be probed for which codes
// exist (same rationale as the reset/verification code paths).
func mapRcLinkError(err error) error {
	switch {
	case errors.Is(err, services.ErrRcLinkInvalidPayload):
		return fiber.NewError(fiber.StatusBadRequest, "invalid_request_body")
	case errors.Is(err, services.ErrRcLinkInvalidCode), errors.Is(err, services.ErrRcLinkNoEntitlement):
		return fiber.NewError(fiber.StatusNotFound, "rc_link_not_claimable")
	case errors.Is(err, services.ErrRevenueCatNotConfigured):
		return fiber.NewError(fiber.StatusServiceUnavailable, "revenuecat_not_configured")
	case errors.Is(err, services.ErrRcLinkVerifyFailed):
		return fiber.NewError(fiber.StatusBadGateway, "revenuecat_verification_failed")
	default:
		return fiber.NewError(fiber.StatusServiceUnavailable, "rc_link_unavailable")
	}
}
