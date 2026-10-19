package handlers

import (
	"errors"
	"strconv"
	"time"

	"github.com/gofiber/fiber/v2"
	"gorm.io/gorm"

	"pepinillo/backend/internal/domain"
	"pepinillo/backend/internal/services"
)

type TaskHandler struct {
	tasks *services.TaskService
}

type taskSyncRequest struct {
	Tasks          []domain.Task `json:"tasks"`
	DeletedSyncIDs []string      `json:"deletedSyncIds"`
	LastSyncAt     *time.Time    `json:"lastSyncAt"`
}

type generateRecurrencesRequest struct {
	From string `json:"from"`
	To   string `json:"to"`
}

func NewTaskHandler(tasks *services.TaskService) *TaskHandler {
	return &TaskHandler{tasks: tasks}
}

func (h *TaskHandler) List(c *fiber.Ctx) error {
	userID, ok := c.Locals("userID").(string)
	if !ok || userID == "" {
		return fiber.NewError(fiber.StatusUnauthorized, "invalid_claims")
	}

	// Optional filter by finish date
	if dateStr := c.Query("finishDate"); dateStr != "" {
		date, err := time.Parse("2006-01-02", dateStr)
		if err != nil {
			return fiber.NewError(fiber.StatusBadRequest, "invalid_finish_date")
		}
		items, err := h.tasks.ListByFinishDate(c.Context(), userID, date)
		if err != nil {
			return err
		}
		return c.JSON(items)
	}

	items, err := h.tasks.ListByUser(c.Context(), userID)
	if err != nil {
		return err
	}
	return c.JSON(items)
}

func (h *TaskHandler) Upsert(c *fiber.Ctx) error {
	userID, ok := c.Locals("userID").(string)
	if !ok || userID == "" {
		return fiber.NewError(fiber.StatusUnauthorized, "invalid_claims")
	}
	var task domain.Task
	if err := c.BodyParser(&task); err != nil {
		return fiber.NewError(fiber.StatusBadRequest, "invalid_request_body")
	}
	task.UserID = userID
	if err := h.tasks.Upsert(c.Context(), &task); err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return fiber.NewError(fiber.StatusNotFound, "task_not_found")
		}
		return err
	}
	return c.JSON(task)
}

func (h *TaskHandler) Delete(c *fiber.Ctx) error {
	userID, ok := c.Locals("userID").(string)
	if !ok || userID == "" {
		return fiber.NewError(fiber.StatusUnauthorized, "invalid_claims")
	}
	taskID, err := strconv.Atoi(c.Params("id"))
	if err != nil {
		return fiber.NewError(fiber.StatusBadRequest, "invalid_task_id")
	}
	if err := h.tasks.Delete(c.Context(), userID, taskID); err != nil {
		return err
	}
	return c.SendStatus(fiber.StatusNoContent)
}

func (h *TaskHandler) Sync(c *fiber.Ctx) error {
	userID, ok := c.Locals("userID").(string)
	if !ok || userID == "" {
		return fiber.NewError(fiber.StatusUnauthorized, "invalid_claims")
	}
	var req taskSyncRequest
	if err := c.BodyParser(&req); err != nil {
		return fiber.NewError(fiber.StatusBadRequest, "invalid_request_body")
	}

	result, err := h.tasks.Sync(
		c.Context(),
		userID,
		req.Tasks,
		req.DeletedSyncIDs,
		req.LastSyncAt,
	)
	if err != nil {
		return err
	}

	return c.JSON(fiber.Map{
		"tasks":           result.ServerTasks,
		"deletedSyncIds":  result.DeletedSyncIDs,
		"appliedSyncIds":  result.AppliedSyncIDs,
		"rejectedSyncIds": result.RejectedSyncIDs,
		"syncTimestamp":   result.SyncedAt,
	})
}

func (h *TaskHandler) ListRecurrences(c *fiber.Ctx) error {
	userID, ok := c.Locals("userID").(string)
	if !ok || userID == "" {
		return fiber.NewError(fiber.StatusUnauthorized, "invalid_claims")
	}

	fromStr := c.Query("from")
	toStr := c.Query("to")
	if (fromStr == "") != (toStr == "") {
		return fiber.NewError(fiber.StatusBadRequest, "provide_both_from_to")
	}

	var (
		from *time.Time
		to   *time.Time
	)
	if fromStr != "" && toStr != "" {
		parsedFrom, err := parseFlexibleDate(fromStr)
		if err != nil {
			return fiber.NewError(fiber.StatusBadRequest, "invalid_from_date")
		}
		parsedTo, err := parseFlexibleDate(toStr)
		if err != nil {
			return fiber.NewError(fiber.StatusBadRequest, "invalid_to_date")
		}
		if parsedTo.Before(parsedFrom) {
			return fiber.NewError(fiber.StatusBadRequest, "invalid_date_range")
		}
		from = &parsedFrom
		to = &parsedTo
	}

	items, err := h.tasks.ListRecurrences(c.Context(), userID, from, to)
	if err != nil {
		return err
	}
	return c.JSON(items)
}

func (h *TaskHandler) GenerateRecurrences(c *fiber.Ctx) error {
	userID, ok := c.Locals("userID").(string)
	if !ok || userID == "" {
		return fiber.NewError(fiber.StatusUnauthorized, "invalid_claims")
	}

	var req generateRecurrencesRequest
	if err := c.BodyParser(&req); err != nil {
		return fiber.NewError(fiber.StatusBadRequest, "invalid_request_body")
	}
	if req.From == "" || req.To == "" {
		return fiber.NewError(fiber.StatusBadRequest, "missing_required_fields")
	}

	from, err := parseFlexibleDate(req.From)
	if err != nil {
		return fiber.NewError(fiber.StatusBadRequest, "invalid_from_date")
	}
	to, err := parseFlexibleDate(req.To)
	if err != nil {
		return fiber.NewError(fiber.StatusBadRequest, "invalid_to_date")
	}
	if to.Before(from) {
		return fiber.NewError(fiber.StatusBadRequest, "invalid_date_range")
	}

	created, err := h.tasks.GenerateRecurrences(c.Context(), userID, from, to)
	if err != nil {
		if errors.Is(err, services.ErrRecurrenceWindowInProgress) {
			return fiber.NewError(fiber.StatusConflict, err.Error())
		}
		if err.Error() == "date_range_too_large" || err.Error() == "invalid_date_range" {
			return fiber.NewError(fiber.StatusBadRequest, err.Error())
		}
		return err
	}

	return c.JSON(fiber.Map{
		"created": created,
		"count":   len(created),
	})
}

func parseFlexibleDate(value string) (time.Time, error) {
	if parsed, err := time.Parse(time.RFC3339, value); err == nil {
		return parsed.UTC(), nil
	}
	parsed, err := time.Parse("2006-01-02", value)
	if err != nil {
		return time.Time{}, err
	}
	return parsed.UTC(), nil
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
	var req struct {
		Mode string `json:"mode"`
	}
	if err := c.BodyParser(&req); err != nil {
		return fiber.NewError(fiber.StatusBadRequest, "invalid_request_body")
	}
	if req.Mode == "" {
		return fiber.NewError(fiber.StatusBadRequest, "missing_required_fields")
	}

	if err := h.tasks.UpdateTaskTrackingMode(c.Context(), userID, taskID, req.Mode); err != nil {
		if errors.Is(err, services.ErrInvalidTrackingMode) {
			return fiber.NewError(fiber.StatusBadRequest, err.Error())
		}
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return fiber.NewError(fiber.StatusNotFound, "task_not_found")
		}
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
	var req struct {
		Mode string `json:"mode"`
	}
	if err := c.BodyParser(&req); err != nil {
		return fiber.NewError(fiber.StatusBadRequest, "invalid_request_body")
	}
	if req.Mode == "" {
		return fiber.NewError(fiber.StatusBadRequest, "missing_required_fields")
	}

	if err := h.tasks.IncrementTaskCompletion(c.Context(), userID, taskID, req.Mode); err != nil {
		if errors.Is(err, services.ErrInvalidTrackingMode) {
			return fiber.NewError(fiber.StatusBadRequest, err.Error())
		}
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return fiber.NewError(fiber.StatusNotFound, "task_not_found")
		}
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
	var req struct {
		Mode    string `json:"mode"`
		Seconds int    `json:"seconds"`
	}
	if err := c.BodyParser(&req); err != nil {
		return fiber.NewError(fiber.StatusBadRequest, "invalid_request_body")
	}
	if req.Mode == "" || req.Seconds <= 0 || req.Seconds > 86400 {
		return fiber.NewError(fiber.StatusBadRequest, "invalid_request_body")
	}

	if err := h.tasks.IncrementTaskFocusTime(c.Context(), userID, taskID, req.Mode, req.Seconds); err != nil {
		if errors.Is(err, services.ErrInvalidTrackingMode) {
			return fiber.NewError(fiber.StatusBadRequest, err.Error())
		}
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return fiber.NewError(fiber.StatusNotFound, "task_not_found")
		}
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

	if err := h.tasks.SetTaskActiveSession(c.Context(), userID, taskID, req.SessionID); err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return fiber.NewError(fiber.StatusNotFound, "task_not_found")
		}
		return err
	}
	return c.SendStatus(fiber.StatusNoContent)
}
