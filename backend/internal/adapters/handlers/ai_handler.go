package handlers

import (
	"errors"
	"strconv"

	"github.com/gofiber/fiber/v2"

	"pepinillo/backend/internal/services"
)

type AIHandler struct {
	ai *services.AIService
}

type analyzeRequest struct {
	Days    int    `json:"days"`
	Context string `json:"context"`
}

func NewAIHandler(ai *services.AIService) *AIHandler {
	return &AIHandler{ai: ai}
}

// mapAIError translates typed AI service errors into the correct HTTP status.
// Tier/credit denials must surface as 402/429 so clients can distinguish them
// from server-side failures; everything else is passed through for ErrorHandler.
func mapAIError(err error) error {
	switch {
	case errors.Is(err, services.ErrTierInsufficientForCloudAI):
		return fiber.NewError(fiber.StatusPaymentRequired, services.ErrTierInsufficientForCloudAI.Error())
	case errors.Is(err, services.ErrInsufficientAICredits):
		return fiber.NewError(fiber.StatusTooManyRequests, services.ErrInsufficientAICredits.Error())
	default:
		return err
	}
}

func (h *AIHandler) DailyTip(c *fiber.Ctx) error {
	userID := c.Locals("userID").(string)
	insight, err := h.ai.GenerateDailyTip(c.Context(), userID)
	if err != nil {
		return mapAIError(err)
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
		return mapAIError(err)
	}
	return c.JSON(insights)
}

func (h *AIHandler) WeeklyReport(c *fiber.Ctx) error {
	userID := c.Locals("userID").(string)
	insight, err := h.ai.GenerateWeeklyReport(c.Context(), userID)
	if err != nil {
		return mapAIError(err)
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
		return mapAIError(err)
	}
	return c.JSON(insight)
}

func (h *AIHandler) ProductivityPrediction(c *fiber.Ctx) error {
	userID := c.Locals("userID").(string)
	result, err := h.ai.ProductivityPrediction(c.Context(), userID)
	if err != nil {
		return mapAIError(err)
	}
	return c.JSON(result)
}

func (h *AIHandler) BurnoutRisk(c *fiber.Ctx) error {
	userID := c.Locals("userID").(string)
	result, err := h.ai.BurnoutRisk(c.Context(), userID)
	if err != nil {
		return mapAIError(err)
	}
	return c.JSON(result)
}

func (h *AIHandler) OptimalHours(c *fiber.Ctx) error {
	userID := c.Locals("userID").(string)
	result, err := h.ai.OptimalHours(c.Context(), userID)
	if err != nil {
		return mapAIError(err)
	}
	return c.JSON(result)
}

// Report handles POST /ai/report. The Android client posts a rich ReportPayload
// (built on-device from local focus sessions) and expects an AIReportResponse
// (title + highlights + insights + recommendations). The shape is distinct from
// weekly-report/analyze, so it cannot be aliased — see AIService.Report.
func (h *AIHandler) Report(c *fiber.Ctx) error {
	userID := c.Locals("userID").(string)
	var payload services.ReportPayload
	if err := c.BodyParser(&payload); err != nil {
		return fiber.NewError(fiber.StatusBadRequest, "invalid_request_body")
	}
	resp, err := h.ai.Report(c.Context(), userID, payload)
	if err != nil {
		return mapAIError(err)
	}
	return c.JSON(resp)
}
