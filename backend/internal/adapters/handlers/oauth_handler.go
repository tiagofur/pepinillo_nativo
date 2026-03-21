package handlers

import (
	"errors"

	"github.com/gofiber/fiber/v2"

	"pepinillo/backend/internal/services"
)

type OAuthHandler struct {
	oauth *services.OAuthService
}

type googleLoginRequest struct {
	IDToken string `json:"idToken"`
}

type appleLoginRequest struct {
	IDToken string `json:"idToken"`
}

type linkAccountRequest struct {
	IDToken string `json:"idToken"`
}

func NewOAuthHandler(oauth *services.OAuthService) *OAuthHandler {
	return &OAuthHandler{oauth: oauth}
}

func (h *OAuthHandler) LoginWithGoogle(c *fiber.Ctx) error {
	var req googleLoginRequest
	if err := c.BodyParser(&req); err != nil {
		return fiber.NewError(fiber.StatusBadRequest, "invalid_request_body")
	}
	if req.IDToken == "" {
		return fiber.NewError(fiber.StatusBadRequest, "missing_required_fields")
	}

	user, tokens, err := h.oauth.LoginWithGoogle(c.Context(), req.IDToken)
	if err != nil {
		if errors.Is(err, services.ErrUserNotFound) {
			return fiber.NewError(fiber.StatusNotFound, err.Error())
		}
		return err
	}

	return c.JSON(fiber.Map{
		"user":   user,
		"tokens": tokens,
	})
}

func (h *OAuthHandler) LoginWithApple(c *fiber.Ctx) error {
	var req appleLoginRequest
	if err := c.BodyParser(&req); err != nil {
		return fiber.NewError(fiber.StatusBadRequest, "invalid_request_body")
	}
	if req.IDToken == "" {
		return fiber.NewError(fiber.StatusBadRequest, "missing_required_fields")
	}

	user, tokens, err := h.oauth.LoginWithApple(c.Context(), req.IDToken)
	if err != nil {
		if errors.Is(err, services.ErrUserNotFound) {
			return fiber.NewError(fiber.StatusNotFound, err.Error())
		}
		return err
	}

	return c.JSON(fiber.Map{
		"user":   user,
		"tokens": tokens,
	})
}

func (h *OAuthHandler) LinkGoogleAccount(c *fiber.Ctx) error {
	userID, ok := c.Locals("userID").(string)
	if !ok || userID == "" {
		return fiber.NewError(fiber.StatusUnauthorized, "invalid_claims")
	}

	var req linkAccountRequest
	if err := c.BodyParser(&req); err != nil {
		return fiber.NewError(fiber.StatusBadRequest, "invalid_request_body")
	}
	if req.IDToken == "" {
		return fiber.NewError(fiber.StatusBadRequest, "missing_required_fields")
	}

	user, err := h.oauth.LinkGoogleAccount(c.Context(), userID, req.IDToken)
	if err != nil {
		if errors.Is(err, services.ErrUserNotFound) {
			return fiber.NewError(fiber.StatusNotFound, err.Error())
		}
		return err
	}

	return c.JSON(fiber.Map{
		"message": "google_account_linked",
		"user":    user,
	})
}

func (h *OAuthHandler) UnlinkGoogleAccount(c *fiber.Ctx) error {
	userID, ok := c.Locals("userID").(string)
	if !ok || userID == "" {
		return fiber.NewError(fiber.StatusUnauthorized, "invalid_claims")
	}

	if err := h.oauth.UnlinkGoogleAccount(c.Context(), userID); err != nil {
		if errors.Is(err, services.ErrUserNotFound) {
			return fiber.NewError(fiber.StatusNotFound, err.Error())
		}
		return err
	}

	return c.JSON(fiber.Map{
		"message": "google_account_unlinked",
	})
}

func (h *OAuthHandler) LinkAppleAccount(c *fiber.Ctx) error {
	userID, ok := c.Locals("userID").(string)
	if !ok || userID == "" {
		return fiber.NewError(fiber.StatusUnauthorized, "invalid_claims")
	}

	var req linkAccountRequest
	if err := c.BodyParser(&req); err != nil {
		return fiber.NewError(fiber.StatusBadRequest, "invalid_request_body")
	}
	if req.IDToken == "" {
		return fiber.NewError(fiber.StatusBadRequest, "missing_required_fields")
	}

	user, err := h.oauth.LinkAppleAccount(c.Context(), userID, req.IDToken)
	if err != nil {
		if errors.Is(err, services.ErrUserNotFound) {
			return fiber.NewError(fiber.StatusNotFound, err.Error())
		}
		return err
	}

	return c.JSON(fiber.Map{
		"message": "apple_account_linked",
		"user":    user,
	})
}

func (h *OAuthHandler) UnlinkAppleAccount(c *fiber.Ctx) error {
	userID, ok := c.Locals("userID").(string)
	if !ok || userID == "" {
		return fiber.NewError(fiber.StatusUnauthorized, "invalid_claims")
	}

	if err := h.oauth.UnlinkAppleAccount(c.Context(), userID); err != nil {
		if errors.Is(err, services.ErrUserNotFound) {
			return fiber.NewError(fiber.StatusNotFound, err.Error())
		}
		return err
	}

	return c.JSON(fiber.Map{
		"message": "apple_account_unlinked",
	})
}

func (h *OAuthHandler) GetLinkedProviders(c *fiber.Ctx) error {
	userID, ok := c.Locals("userID").(string)
	if !ok || userID == "" {
		return fiber.NewError(fiber.StatusUnauthorized, "invalid_claims")
	}

	providers, err := h.oauth.GetLinkedProviders(c.Context(), userID)
	if err != nil {
		if errors.Is(err, services.ErrUserNotFound) {
			return fiber.NewError(fiber.StatusNotFound, err.Error())
		}
		return err
	}

	return c.JSON(providers)
}
