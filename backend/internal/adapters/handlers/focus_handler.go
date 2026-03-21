package handlers

import (
	"strconv"
	"time"

	"github.com/gofiber/fiber/v2"
	"github.com/google/uuid"

	"pepinillo/backend/internal/domain"
	"pepinillo/backend/internal/services"
)

type FocusHandler struct {
	focus *services.FocusService
}

func NewFocusHandler(focus *services.FocusService) *FocusHandler {
	return &FocusHandler{focus: focus}
}

func (h *FocusHandler) GetConfig(c *fiber.Ctx) error {
	userID, ok := c.Locals("userID").(string)
	if !ok || userID == "" {
		return fiber.NewError(fiber.StatusUnauthorized, "invalid_claims")
	}
	cfg, err := h.focus.GetConfig(c.Context(), userID)
	if err != nil {
		return err
	}
	if cfg == nil {
		return c.JSON(fiber.Map{})
	}
	return c.JSON(cfg)
}

func (h *FocusHandler) UpsertConfig(c *fiber.Ctx) error {
	userID, ok := c.Locals("userID").(string)
	if !ok || userID == "" {
		return fiber.NewError(fiber.StatusUnauthorized, "invalid_claims")
	}
	var cfg domain.FocusConfig
	if err := c.BodyParser(&cfg); err != nil {
		return fiber.NewError(fiber.StatusBadRequest, "invalid_request_body")
	}
	cfg.UserID = userID
	if err := h.focus.UpsertConfig(c.Context(), &cfg); err != nil {
		return err
	}
	return c.JSON(cfg)
}

func (h *FocusHandler) UpsertStats(c *fiber.Ctx) error {
	userID, ok := c.Locals("userID").(string)
	if !ok || userID == "" {
		return fiber.NewError(fiber.StatusUnauthorized, "invalid_claims")
	}
	var stats domain.FocusStats
	if err := c.BodyParser(&stats); err != nil {
		return fiber.NewError(fiber.StatusBadRequest, "invalid_request_body")
	}
	stats.UserID = userID
	if err := h.focus.UpsertStats(c.Context(), &stats); err != nil {
		return err
	}
	return c.JSON(stats)
}

func (h *FocusHandler) ListStats(c *fiber.Ctx) error {
	userID, ok := c.Locals("userID").(string)
	if !ok || userID == "" {
		return fiber.NewError(fiber.StatusUnauthorized, "invalid_claims")
	}

	// Single date query
	if dateStr := c.Query("date"); dateStr != "" {
		date, err := time.Parse("2006-01-02", dateStr)
		if err != nil {
			return fiber.NewError(fiber.StatusBadRequest, "invalid_date")
		}
		stats, err := h.focus.GetStatsByDate(c.Context(), userID, date)
		if err != nil {
			return err
		}
		if stats == nil {
			return c.JSON(fiber.Map{})
		}
		return c.JSON(stats)
	}

	// Range query
	fromStr := c.Query("from")
	toStr := c.Query("to")
	if fromStr == "" || toStr == "" {
		return fiber.NewError(fiber.StatusBadRequest, "provide either date or from+to parameters")
	}
	from, err := time.Parse("2006-01-02", fromStr)
	if err != nil {
		return fiber.NewError(fiber.StatusBadRequest, "invalid_from_date")
	}
	to, err := time.Parse("2006-01-02", toStr)
	if err != nil {
		return fiber.NewError(fiber.StatusBadRequest, "invalid_to_date")
	}
	stats, err := h.focus.ListStatsByRange(c.Context(), userID, from, to)
	if err != nil {
		return err
	}
	return c.JSON(stats)
}

func (h *FocusHandler) InsertSession(c *fiber.Ctx) error {
	userID, ok := c.Locals("userID").(string)
	if !ok || userID == "" {
		return fiber.NewError(fiber.StatusUnauthorized, "invalid_claims")
	}
	var session domain.FocusSession
	if err := c.BodyParser(&session); err != nil {
		return fiber.NewError(fiber.StatusBadRequest, "invalid_request_body")
	}
	// Always generate session ID server-side to prevent client from overwriting other users' sessions.
	session.ID = uuid.NewString()
	session.UserID = userID
	if err := h.focus.InsertSession(c.Context(), &session); err != nil {
		return err
	}
	return c.JSON(session)
}

func (h *FocusHandler) ListSessionsByTask(c *fiber.Ctx) error {
	userID, ok := c.Locals("userID").(string)
	if !ok || userID == "" {
		return fiber.NewError(fiber.StatusUnauthorized, "invalid_claims")
	}
	taskID, err := strconv.Atoi(c.Query("taskId"))
	if err != nil {
		return fiber.NewError(fiber.StatusBadRequest, "invalid_task_id")
	}
	sessions, err := h.focus.ListSessionsByTask(c.Context(), userID, taskID)
	if err != nil {
		return err
	}
	return c.JSON(sessions)
}

func (h *FocusHandler) ListSessionsByRange(c *fiber.Ctx) error {
	userID, ok := c.Locals("userID").(string)
	if !ok || userID == "" {
		return fiber.NewError(fiber.StatusUnauthorized, "invalid_claims")
	}
	from, err := time.Parse(time.RFC3339, c.Query("from"))
	if err != nil {
		return fiber.NewError(fiber.StatusBadRequest, "invalid_from_date")
	}
	to, err := time.Parse(time.RFC3339, c.Query("to"))
	if err != nil {
		return fiber.NewError(fiber.StatusBadRequest, "invalid_to_date")
	}
	sessions, err := h.focus.ListSessionsByRange(c.Context(), userID, from, to)
	if err != nil {
		return err
	}
	return c.JSON(sessions)
}

func (h *FocusHandler) UpdateSession(c *fiber.Ctx) error {
	userID, ok := c.Locals("userID").(string)
	if !ok || userID == "" {
		return fiber.NewError(fiber.StatusUnauthorized, "invalid_claims")
	}
	sessionID := c.Params("id")
	var session domain.FocusSession
	if err := c.BodyParser(&session); err != nil {
		return fiber.NewError(fiber.StatusBadRequest, "invalid_request_body")
	}
	session.ID = sessionID
	session.UserID = userID
	if err := h.focus.UpdateSession(c.Context(), &session); err != nil {
		return err
	}
	return c.JSON(session)
}

func (h *FocusHandler) ListAllSessions(c *fiber.Ctx) error {
	userID, ok := c.Locals("userID").(string)
	if !ok || userID == "" {
		return fiber.NewError(fiber.StatusUnauthorized, "invalid_claims")
	}
	sessions, err := h.focus.ListAllSessions(c.Context(), userID)
	if err != nil {
		return err
	}
	return c.JSON(sessions)
}

func (h *FocusHandler) GetTaskStats(c *fiber.Ctx) error {
	userID, ok := c.Locals("userID").(string)
	if !ok || userID == "" {
		return fiber.NewError(fiber.StatusUnauthorized, "invalid_claims")
	}
	taskID, err := strconv.Atoi(c.Params("taskId"))
	if err != nil {
		return fiber.NewError(fiber.StatusBadRequest, "invalid_task_id")
	}
	stats, err := h.focus.GetTaskStats(c.Context(), userID, taskID)
	if err != nil {
		return err
	}
	return c.JSON(stats)
}
