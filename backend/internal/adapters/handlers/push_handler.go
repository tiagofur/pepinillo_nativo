package handlers

import (
	"errors"

	"github.com/gofiber/fiber/v2"

	"pepinillo/backend/internal/observability"
	"pepinillo/backend/internal/services"
)

type PushHandler struct {
	pushService *services.PushService
}

func NewPushHandler(pushService *services.PushService) *PushHandler {
	return &PushHandler{pushService: pushService}
}

type registerDeviceRequest struct {
	Platform   string  `json:"platform"`
	Token      string  `json:"token"`
	DeviceID   *string `json:"deviceId"`
	AppVersion *string `json:"appVersion"`
}

type sendPushTestRequest struct {
	Title string `json:"title"`
	Body  string `json:"body"`
}

func (h *PushHandler) RegisterDevice(c *fiber.Ctx) error {
	userID := c.Locals("userID").(string)

	var req registerDeviceRequest
	if err := c.BodyParser(&req); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "invalid request body"})
	}

	if err := h.pushService.RegisterDevice(c.Context(), userID, req.Platform, req.Token, req.DeviceID, req.AppVersion); err != nil {
		switch {
		case errors.Is(err, services.ErrInvalidPushPlatform),
			errors.Is(err, services.ErrInvalidPushToken):
			return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": err.Error()})
		default:
			observability.CaptureError(err, map[string]string{"handler": "push_register"})
			return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "failed to register device"})
		}
	}

	return c.Status(fiber.StatusCreated).JSON(fiber.Map{"message": "device registered"})
}

func (h *PushHandler) ListDevices(c *fiber.Ctx) error {
	userID := c.Locals("userID").(string)
	items, err := h.pushService.ListDevices(c.Context(), userID)
	if err != nil {
		observability.CaptureError(err, map[string]string{"handler": "push_list"})
			return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "failed to list devices"})
	}
	return c.JSON(items)
}

func (h *PushHandler) UnregisterDevice(c *fiber.Ctx) error {
	userID := c.Locals("userID").(string)
	token := c.Params("token")
	if err := h.pushService.UnregisterDevice(c.Context(), userID, token); err != nil {
		if errors.Is(err, services.ErrInvalidPushToken) {
			return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": err.Error()})
		}
		observability.CaptureError(err, map[string]string{"handler": "push_unregister"})
			return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "failed to unregister device"})
	}
	return c.JSON(fiber.Map{"message": "device unregistered"})
}

func (h *PushHandler) SendTestPush(c *fiber.Ctx) error {
	userID := c.Locals("userID").(string)

	var req sendPushTestRequest
	if err := c.BodyParser(&req); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "invalid request body"})
	}

	if err := h.pushService.SendTestPush(c.Context(), userID, req.Title, req.Body); err != nil {
		if errors.Is(err, services.ErrPushMessageEmpty) {
			return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": err.Error()})
		}
		observability.CaptureError(err, map[string]string{"handler": "push_send_test"})
			return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "failed to send push"})
	}

	return c.JSON(fiber.Map{"message": "push sent"})
}
