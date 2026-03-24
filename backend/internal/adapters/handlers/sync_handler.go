package handlers

import (
	"github.com/gofiber/fiber/v2"

	"pepinillo/backend/internal/services"
)

type SyncHandler struct {
	sync *services.SyncService
}

func NewSyncHandler(sync *services.SyncService) *SyncHandler {
	return &SyncHandler{sync: sync}
}

func (h *SyncHandler) SyncSessions(c *fiber.Ctx) error {
	userID, ok := c.Locals("userID").(string)
	if !ok || userID == "" {
		return fiber.NewError(fiber.StatusUnauthorized, "invalid_claims")
	}

	var req services.SessionSyncRequest
	if err := c.BodyParser(&req); err != nil {
		return fiber.NewError(fiber.StatusBadRequest, "invalid_request_body")
	}

	result, err := h.sync.SyncSessions(c.Context(), userID, req.Sessions, req.LastSyncAt)
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
		return err
	}

	return c.JSON(result)
}

func (h *SyncHandler) InitialUpload(c *fiber.Ctx) error {
	userID, ok := c.Locals("userID").(string)
	if !ok || userID == "" {
		return fiber.NewError(fiber.StatusUnauthorized, "invalid_claims")
	}

	var req services.InitialUploadRequest
	if err := c.BodyParser(&req); err != nil {
		return fiber.NewError(fiber.StatusBadRequest, "invalid_request_body")
	}

	result, err := h.sync.InitialUpload(c.Context(), userID, &req)
	if err != nil {
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
