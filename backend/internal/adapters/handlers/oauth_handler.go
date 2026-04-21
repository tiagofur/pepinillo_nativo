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
	Nonce   string `json:"nonce"`
}

type linkAccountRequest struct {
	IDToken string `json:"idToken"`
}

func NewOAuthHandler(oauth *services.OAuthService) *OAuthHandler {
	return &OAuthHandler{oauth: oauth}
}

func mapOAuthError(err error) error {
	switch {
	case errors.Is(err, services.ErrGoogleAudienceNotConfigured):
		return fiber.NewError(fiber.StatusServiceUnavailable, err.Error())
	case errors.Is(err, services.ErrInvalidOAuthToken):
		return fiber.NewError(fiber.StatusUnauthorized, err.Error())
	case errors.Is(err, services.ErrOAuthEmailMissing):
		return fiber.NewError(fiber.StatusBadRequest, err.Error())
	case errors.Is(err, services.ErrUserNotFound):
		return fiber.NewError(fiber.StatusNotFound, err.Error())
	case errors.Is(err, services.ErrAccountAlreadyLinked):
		return fiber.NewError(fiber.StatusConflict, err.Error())
	case errors.Is(err, services.ErrAccountLinkedToOtherUser):
		return fiber.NewError(fiber.StatusConflict, err.Error())
	case errors.Is(err, services.ErrOAuthProviderAlreadyLinked):
		return fiber.NewError(fiber.StatusConflict, err.Error())
	case errors.Is(err, services.ErrCannotUnlinkLastAuth):
		return fiber.NewError(fiber.StatusBadRequest, err.Error())
	default:
		return err
	}
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
		return mapOAuthError(err)
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
	if req.Nonce == "" {
		return fiber.NewError(fiber.StatusBadRequest, "missing_required_fields")
	}

	user, tokens, err := h.oauth.LoginWithApple(c.Context(), req.IDToken, req.Nonce)
	if err != nil {
		return mapOAuthError(err)
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
		return mapOAuthError(err)
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
		return mapOAuthError(err)
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
		return mapOAuthError(err)
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
		return mapOAuthError(err)
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
		return mapOAuthError(err)
	}

	return c.JSON(providers)
}
