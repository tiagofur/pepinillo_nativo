package handlers

import (
	"strconv"

	"github.com/gofiber/fiber/v2"

	"pepinillo/backend/internal/services"
)

type TaskTrackingRequest struct {
	Mode    string `json:"mode"`
	Seconds *int   `json:"seconds,omitempty"`
}

func (h *TaskHandler) UpdateTrackingMode(c *fiber.Ctx) error {
	userID, ok := c.Locals("userID").(string)
	if !ok || userID == "" {
		return fiber.NewError(fiber.StatusUnauthorized, "invalid_claims")
	}
	taskID, err := strconv.Atoi(c.Params("id"))
	if err != nil {
		return fiber.NewError(fiber.StatusBadRequest, "invalid_task_id")
	}
	var req TaskTrackingRequest
	if err := c.BodyParser(&req); err != nil {
		return fiber.NewError(fiber.StatusBadRequest, "invalid_request_body")
	}
	if req.Mode == "" {
		return fiber.NewError(fiber.StatusBadRequest, "missing_required_fields")
	}

	if err := h.tasks.UpdateTaskTrackingMode(c.Context(), taskID, req.Mode); err != nil {
		return err
	}
	return c.SendStatus(fiber.StatusNoContent)
}

func (h *TaskHandler) IncrementCompletion(c *fiber.Ctx) error {
	userID, ok := c.Locals("userID").(string)
	if !ok || userID == "" {
		return fiber.NewError(fiber.StatusUnauthorized, "invalid_claims")
	}
	taskID, err := strconv.Atoi(c.Params("id"))
	if err != nil {
		return fiber.NewError(fiber.StatusBadRequest, "invalid_task_id")
	}
	var req TaskTrackingRequest
	if err := c.BodyParser(&req); err != nil {
		return fiber.NewError(fiber.StatusBadRequest, "invalid_request_body")
	}
	if req.Mode == "" {
		return fiber.NewError(fiber.StatusBadRequest, "missing_required_fields")
	}

	if err := h.tasks.IncrementTaskCompletion(c.Context(), taskID, req.Mode); err != nil {
		return err
	}
	return c.SendStatus(fiber.StatusNoContent)
}

func (h *TaskHandler) IncrementFocusTime(c *fiber.Ctx) error {
	userID, ok := c.Locals("userID").(string)
	if !ok || userID == "" {
		return fiber.NewError(fiber.StatusUnauthorized, "invalid_claims")
	}
	taskID, err := strconv.Atoi(c.Params("id"))
	if err != nil {
		return fiber.NewError(fiber.StatusBadRequest, "invalid_task_id")
	}
	var req TaskTrackingRequest
	if err := c.BodyParser(&req); err != nil {
		return fiber.NewError(fiber.StatusBadRequest, "invalid_request_body")
	}
	if req.Mode == "" || req.Seconds == nil || *req.Seconds <= 0 {
		return fiber.NewError(fiber.StatusBadRequest, "invalid_request_body")
	}

	if err := h.tasks.IncrementTaskFocusTime(c.Context(), taskID, req.Mode, *req.Seconds); err != nil {
		return err
	}
	return c.SendStatus(fiber.StatusNoContent)
}

func (h *TaskHandler) SetActiveSession(c *fiber.Ctx) error {
	userID, ok := c.Locals("userID").(string)
	if !ok || userID == "" {
		return fiber.NewError(fiber.StatusUnauthorized, "invalid_claims")
	}
	taskID, err := strconv.Atoi(c.Params("id"))
	if err != nil {
		return fiber.NewError(fiber.StatusBadRequest, "invalid_task_id")
	}
	var req struct {
		SessionID *string `json:"sessionId"`
	}
	if err := c.BodyParser(&req); err != nil {
		return fiber.NewError(fiber.StatusBadRequest, "invalid_request_body")
	}

	if err := h.tasks.SetTaskActiveSession(c.Context(), taskID, req.SessionID); err != nil {
		return err
	}
	return c.SendStatus(fiber.StatusNoContent)
}
