package handlers

import (
	"strconv"
	"time"

	"github.com/gofiber/fiber/v2"
	"github.com/google/uuid"

	"pepinillo/backend/internal/domain"
	"pepinillo/backend/internal/services"
)

type PomodoroHandler struct {
	pomodoro *services.PomodoroService
}

func NewPomodoroHandler(pomodoro *services.PomodoroService) *PomodoroHandler {
	return &PomodoroHandler{pomodoro: pomodoro}
}

func (h *PomodoroHandler) GetConfig(c *fiber.Ctx) error {
	userID, ok := c.Locals("userID").(string)
	if !ok || userID == "" {
		return fiber.NewError(fiber.StatusUnauthorized, "invalid_claims")
	}
	cfg, err := h.pomodoro.GetConfig(c.Context(), userID)
	if err != nil {
		return err
	}
	if cfg == nil {
		return c.JSON(fiber.Map{})
	}
	return c.JSON(cfg)
}

func (h *PomodoroHandler) UpsertConfig(c *fiber.Ctx) error {
	userID, ok := c.Locals("userID").(string)
	if !ok || userID == "" {
		return fiber.NewError(fiber.StatusUnauthorized, "invalid_claims")
	}
	var cfg domain.PomodoroConfig
	if err := c.BodyParser(&cfg); err != nil {
		return fiber.NewError(fiber.StatusBadRequest, "invalid_request_body")
	}
	cfg.UserID = userID
	if err := h.pomodoro.UpsertConfig(c.Context(), &cfg); err != nil {
		return err
	}
	return c.JSON(cfg)
}

func (h *PomodoroHandler) UpsertStats(c *fiber.Ctx) error {
	userID, ok := c.Locals("userID").(string)
	if !ok || userID == "" {
		return fiber.NewError(fiber.StatusUnauthorized, "invalid_claims")
	}
	var stats domain.PomodoroStats
	if err := c.BodyParser(&stats); err != nil {
		return fiber.NewError(fiber.StatusBadRequest, "invalid_request_body")
	}
	stats.UserID = userID
	if err := h.pomodoro.UpsertStats(c.Context(), &stats); err != nil {
		return err
	}
	return c.JSON(stats)
}

func (h *PomodoroHandler) ListStats(c *fiber.Ctx) error {
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
		stats, err := h.pomodoro.GetStatsByDate(c.Context(), userID, date)
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
	stats, err := h.pomodoro.ListStatsByRange(c.Context(), userID, from, to)
	if err != nil {
		return err
	}
	return c.JSON(stats)
}

func (h *PomodoroHandler) InsertSession(c *fiber.Ctx) error {
	userID, ok := c.Locals("userID").(string)
	if !ok || userID == "" {
		return fiber.NewError(fiber.StatusUnauthorized, "invalid_claims")
	}
	var session domain.PomodoroSession
	if err := c.BodyParser(&session); err != nil {
		return fiber.NewError(fiber.StatusBadRequest, "invalid_request_body")
	}
	if session.ID == "" {
		session.ID = uuid.NewString()
	}
	session.UserID = userID
	if err := h.pomodoro.InsertSession(c.Context(), &session); err != nil {
		return err
	}
	return c.JSON(session)
}

func (h *PomodoroHandler) ListSessionsByTask(c *fiber.Ctx) error {
	userID, ok := c.Locals("userID").(string)
	if !ok || userID == "" {
		return fiber.NewError(fiber.StatusUnauthorized, "invalid_claims")
	}
	taskID, err := strconv.Atoi(c.Query("taskId"))
	if err != nil {
		return fiber.NewError(fiber.StatusBadRequest, "invalid_task_id")
	}
	sessions, err := h.pomodoro.ListSessionsByTask(c.Context(), userID, taskID)
	if err != nil {
		return err
	}
	return c.JSON(sessions)
}

func (h *PomodoroHandler) ListSessionsByRange(c *fiber.Ctx) error {
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
	sessions, err := h.pomodoro.ListSessionsByRange(c.Context(), userID, from, to)
	if err != nil {
		return err
	}
	return c.JSON(sessions)
}

func (h *PomodoroHandler) UpdateSession(c *fiber.Ctx) error {
	userID, ok := c.Locals("userID").(string)
	if !ok || userID == "" {
		return fiber.NewError(fiber.StatusUnauthorized, "invalid_claims")
	}
	sessionID := c.Params("id")
	var session domain.PomodoroSession
	if err := c.BodyParser(&session); err != nil {
		return fiber.NewError(fiber.StatusBadRequest, "invalid_request_body")
	}
	session.ID = sessionID
	session.UserID = userID
	if err := h.pomodoro.UpdateSession(c.Context(), &session); err != nil {
		return err
	}
	return c.JSON(session)
}

func (h *PomodoroHandler) ListAllSessions(c *fiber.Ctx) error {
	userID, ok := c.Locals("userID").(string)
	if !ok || userID == "" {
		return fiber.NewError(fiber.StatusUnauthorized, "invalid_claims")
	}
	sessions, err := h.pomodoro.ListAllSessions(c.Context(), userID)
	if err != nil {
		return err
	}
	return c.JSON(sessions)
}

func (h *PomodoroHandler) GetTaskStats(c *fiber.Ctx) error {
	userID, ok := c.Locals("userID").(string)
	if !ok || userID == "" {
		return fiber.NewError(fiber.StatusUnauthorized, "invalid_claims")
	}
	taskID, err := strconv.Atoi(c.Params("taskId"))
	if err != nil {
		return fiber.NewError(fiber.StatusBadRequest, "invalid_task_id")
	}
	stats, err := h.pomodoro.GetTaskStats(c.Context(), userID, taskID)
	if err != nil {
		return err
	}
	return c.JSON(stats)
}
