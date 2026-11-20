package handlers

import (
	"errors"

	"github.com/gofiber/fiber/v2"

	"pepinillo/backend/internal/ports"
	"pepinillo/backend/internal/services"
)

type SyncHandler struct {
	sync  *services.SyncService
	users ports.UserRepository
}

func NewSyncHandler(sync *services.SyncService, users ports.UserRepository) *SyncHandler {
	return &SyncHandler{sync: sync, users: users}
}

// claimSyncDeviceBinding implements #942 S5 bind-on-upload: the gate only
// lets the request through when the binding is empty or already ours, so
// reaching this point with an empty binding means THIS device is claiming
// the single-device backup. The guarded UPDATE in the repository is the
// race guard — first writer wins, later devices are silent no-ops.
func (h *SyncHandler) claimSyncDeviceBinding(c *fiber.Ctx, userID string) error {
	bound, _ := c.Locals("sync_device_id").(string)
	if bound != "" {
		return nil
	}
	deviceID := c.Get("X-Device-ID", "")
	if deviceID == "" {
		return nil
	}
	return h.users.BindSyncDevice(c.Context(), userID, deviceID)
}

func (h *SyncHandler) SyncSessions(c *fiber.Ctx) error {
	userID, ok := c.Locals("userID").(string)
	if !ok || userID == "" {
		return fiber.NewError(fiber.StatusUnauthorized, "invalid_claims")
	}

	deviceID := c.Get("X-Device-ID", "")

	var req services.SessionSyncRequest
	if err := c.BodyParser(&req); err != nil {
		return fiber.NewError(fiber.StatusBadRequest, "invalid_request_body")
	}

	result, err := h.sync.SyncSessions(c.Context(), userID, deviceID, req.Sessions, req.LastSyncAt)
	if err != nil {
		return err
	}

	return c.JSON(fiber.Map{
		"sessions":        result.Sessions,
		"serverTimestamp": result.ServerTimestamp,
	})
}

func (h *SyncHandler) FullSync(c *fiber.Ctx) error {
	userID, ok := c.Locals("userID").(string)
	if !ok || userID == "" {
		return fiber.NewError(fiber.StatusUnauthorized, "invalid_claims")
	}

	req := services.FullSyncRequest{
		TaskCursor:    c.Query("taskCursor", ""),
		SessionCursor: c.Query("sessionCursor", ""),
		Limit:         c.QueryInt("limit", 100),
	}

	result, err := h.sync.FullSync(c.Context(), userID, req)
	if err != nil {
		// A6: malformed client cursors are 400s, not 500s (and not Sentry
		// alerting noise).
		if errors.Is(err, services.ErrInvalidCursor) {
			return fiber.NewError(fiber.StatusBadRequest, err.Error())
		}
		return err
	}

	return c.JSON(result)
}

func (h *SyncHandler) HasData(c *fiber.Ctx) error {
	userID, ok := c.Locals("userID").(string)
	if !ok || userID == "" {
		return fiber.NewError(fiber.StatusUnauthorized, "invalid_claims")
	}

	hasData, err := h.sync.HasServerData(c.Context(), userID)
	if err != nil {
		return err
	}

	return c.JSON(fiber.Map{"hasData": hasData})
}

func (h *SyncHandler) InitialUpload(c *fiber.Ctx) error {
	userID, ok := c.Locals("userID").(string)
	if !ok || userID == "" {
		return fiber.NewError(fiber.StatusUnauthorized, "invalid_claims")
	}

	deviceID := c.Get("X-Device-ID", "")

	var req services.InitialUploadRequest
	if err := c.BodyParser(&req); err != nil {
		return fiber.NewError(fiber.StatusBadRequest, "invalid_request_body")
	}

	if err := h.claimSyncDeviceBinding(c, userID); err != nil {
		return err
	}

	result, err := h.sync.InitialUpload(c.Context(), userID, deviceID, &req)
	if err != nil {
		if errors.Is(err, services.ErrInvalidPreferenceKey) {
			return fiber.NewError(fiber.StatusBadRequest, err.Error())
		}
		return err
	}

	return c.JSON(fiber.Map{
		"tasks":           result.Tasks,
		"sessions":        result.Sessions,
		"settings":        result.Settings,
		"serverTimestamp": result.ServerTimestamp,
		"hasExistingData": result.HasExistingData,
	})
}
