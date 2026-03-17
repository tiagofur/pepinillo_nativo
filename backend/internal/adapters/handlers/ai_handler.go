package handlers

import (
	"strconv"

	"github.com/gofiber/fiber/v2"

	"pepinillo/backend/internal/services"
)

type AIHandler struct {
	ai *services.AIService
}

type analyzeRequest struct {
	Days int `json:"days"`
	Context string `json:"context"`
}

func NewAIHandler(ai *services.AIService) *AIHandler {
	return &AIHandler{ai: ai}
}

func (h *AIHandler) DailyTip(c *fiber.Ctx) error {
	userID := c.Locals("userID").(string)
	insight, err := h.ai.GenerateDailyTip(c.Context(), userID)
	if err != nil {
		return err
	}
	return c.JSON(insight)
}

func (h *AIHandler) ListInsights(c *fiber.Ctx) error {
	userID := c.Locals("userID").(string)
	limit, _ := strconv.Atoi(c.Query("limit", "20"))
	offset, _ := strconv.Atoi(c.Query("offset", "0"))
	if limit <= 0 || limit > 100 {
		limit = 20
	}
	if offset < 0 {
		offset = 0
	}
	insights, err := h.ai.ListInsights(c.Context(), userID, limit, offset)
	if err != nil {
		return err
	}
	return c.JSON(insights)
}

func (h *AIHandler) WeeklyReport(c *fiber.Ctx) error {
	userID := c.Locals("userID").(string)
	insight, err := h.ai.GenerateWeeklyReport(c.Context(), userID)
	if err != nil {
		return err
	}
	return c.JSON(insight)
}

func (h *AIHandler) Analyze(c *fiber.Ctx) error {
	userID := c.Locals("userID").(string)
	var req analyzeRequest
	if err := c.BodyParser(&req); err != nil {
		return fiber.NewError(fiber.StatusBadRequest, "invalid_request_body")
	}
	insight, err := h.ai.Analyze(c.Context(), userID, services.AnalyzeInput{Days: req.Days, Context: req.Context})
	if err != nil {
		return err
	}
	return c.JSON(insight)
}

func (h *AIHandler) ProductivityPrediction(c *fiber.Ctx) error {
	userID := c.Locals("userID").(string)
	return c.JSON(h.ai.ProductivityPrediction(c.Context(), userID))
}

func (h *AIHandler) BurnoutRisk(c *fiber.Ctx) error {
	userID := c.Locals("userID").(string)
	return c.JSON(h.ai.BurnoutRisk(c.Context(), userID))
}

func (h *AIHandler) OptimalHours(c *fiber.Ctx) error {
	userID := c.Locals("userID").(string)
	return c.JSON(h.ai.OptimalHours(c.Context(), userID))
}
