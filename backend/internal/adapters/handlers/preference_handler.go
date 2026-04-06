package handlers

import (
	"time"

	"github.com/gofiber/fiber/v2"

	"pepinillo/backend/internal/domain"
	"pepinillo/backend/internal/services"
)

type PreferenceHandler struct {
	preferences *services.PreferenceService
}

func NewPreferenceHandler(preferences *services.PreferenceService) *PreferenceHandler {
	return &PreferenceHandler{preferences: preferences}
}

func (h *PreferenceHandler) List(c *fiber.Ctx) error {
	userID, ok := c.Locals("userID").(string)
	if !ok || userID == "" {
		return fiber.NewError(fiber.StatusUnauthorized, "invalid_claims")
	}
	prefs, err := h.preferences.GetPreferences(c.Context(), userID)
	if err != nil {
		return err
	}
	return c.JSON(prefs)
}

type upsertPreferencesRequest struct {
	Preferences []domain.UserPreference `json:"preferences"`
}

func (h *PreferenceHandler) Upsert(c *fiber.Ctx) error {
	userID, ok := c.Locals("userID").(string)
	if !ok || userID == "" {
		return fiber.NewError(fiber.StatusUnauthorized, "invalid_claims")
	}

	deviceID := c.Get("X-Device-ID", "")

	var req upsertPreferencesRequest
	if err := c.BodyParser(&req); err != nil {
		return fiber.NewError(fiber.StatusBadRequest, "invalid_request_body")
	}

	merged, err := h.preferences.UpsertPreferences(c.Context(), userID, deviceID, req.Preferences)
	if err != nil {
		return err
	}

	return c.JSON(fiber.Map{
		"preferences":     merged,
		"serverTimestamp": time.Now().UTC(),
	})
}
