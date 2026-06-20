package handlers

import (
	"errors"
	"strconv"

	"github.com/gofiber/fiber/v2"
	"gorm.io/gorm"

	"pepinillo/backend/internal/domain"
	"pepinillo/backend/internal/services"
)

type SubTaskHandler struct {
	subtasks *services.SubTaskService
}

func NewSubTaskHandler(subtasks *services.SubTaskService) *SubTaskHandler {
	return &SubTaskHandler{subtasks: subtasks}
}

func (h *SubTaskHandler) List(c *fiber.Ctx) error {
	userID := c.Locals("userID").(string)
	taskID, err := strconv.Atoi(c.Params("taskId"))
	if err != nil {
		return fiber.NewError(fiber.StatusBadRequest, "invalid_task_id")
	}
	items, err := h.subtasks.ListByTask(c.Context(), userID, taskID)
	if err != nil {
		if err == services.ErrTaskNotFound {
			return fiber.NewError(fiber.StatusNotFound, "task_not_found")
		}
		return err
	}
	return c.JSON(items)
}

func (h *SubTaskHandler) Create(c *fiber.Ctx) error {
	userID := c.Locals("userID").(string)
	taskID, err := strconv.Atoi(c.Params("taskId"))
	if err != nil {
		return fiber.NewError(fiber.StatusBadRequest, "invalid_task_id")
	}
	var subtask domain.SubTask
	if err := c.BodyParser(&subtask); err != nil {
		return fiber.NewError(fiber.StatusBadRequest, "invalid_request_body")
	}
	if err := h.subtasks.Create(c.Context(), userID, taskID, &subtask); err != nil {
		if err == services.ErrTaskNotFound {
			return fiber.NewError(fiber.StatusNotFound, "task_not_found")
		}
		return err
	}
	return c.Status(fiber.StatusCreated).JSON(subtask)
}

func (h *SubTaskHandler) Update(c *fiber.Ctx) error {
	userID := c.Locals("userID").(string)
	taskID, err := strconv.Atoi(c.Params("taskId"))
	if err != nil {
		return fiber.NewError(fiber.StatusBadRequest, "invalid_task_id")
	}
	subtaskID, err := strconv.Atoi(c.Params("subtaskId"))
	if err != nil {
		return fiber.NewError(fiber.StatusBadRequest, "invalid_subtask_id")
	}
	var subtask domain.SubTask
	if err := c.BodyParser(&subtask); err != nil {
		return fiber.NewError(fiber.StatusBadRequest, "invalid_request_body")
	}
	subtask.ID = subtaskID
	if err := h.subtasks.Update(c.Context(), userID, taskID, &subtask); err != nil {
		if err == services.ErrTaskNotFound || errors.Is(err, gorm.ErrRecordNotFound) {
			return fiber.NewError(fiber.StatusNotFound, "task_not_found")
		}
		return err
	}
	return c.JSON(subtask)
}

func (h *SubTaskHandler) Delete(c *fiber.Ctx) error {
	userID := c.Locals("userID").(string)
	taskID, err := strconv.Atoi(c.Params("taskId"))
	if err != nil {
		return fiber.NewError(fiber.StatusBadRequest, "invalid_task_id")
	}
	subtaskID, err := strconv.Atoi(c.Params("subtaskId"))
	if err != nil {
		return fiber.NewError(fiber.StatusBadRequest, "invalid_subtask_id")
	}
	if err := h.subtasks.Delete(c.Context(), userID, taskID, subtaskID); err != nil {
		if err == services.ErrTaskNotFound {
			return fiber.NewError(fiber.StatusNotFound, "task_not_found")
		}
		return err
	}
	return c.SendStatus(fiber.StatusNoContent)
}
