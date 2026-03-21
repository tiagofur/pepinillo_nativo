package handlers

import (
	"time"

	"github.com/gofiber/fiber/v2"

	"pepinillo/backend/internal/services"
)

type AnalyticsHandler struct {
	analytics *services.AnalyticsService
}

func NewAnalyticsHandler(analytics *services.AnalyticsService) *AnalyticsHandler {
	return &AnalyticsHandler{analytics: analytics}
}

func (h *AnalyticsHandler) WeeklyReport(c *fiber.Ctx) error {
	userID, ok := c.Locals("userID").(string)
	if !ok || userID == "" {
		return fiber.NewError(fiber.StatusUnauthorized, "invalid_claims")
	}

	dateStr := c.Query("date")
	if dateStr == "" {
		dateStr = time.Now().Format("2006-01-02")
	}

	date, err := time.Parse("2006-01-02", dateStr)
	if err != nil {
		return fiber.NewError(fiber.StatusBadRequest, "invalid_date")
	}

	weekStart := date.AddDate(0, 0, -int(date.Weekday()-time.Monday))
	weekEnd := weekStart.AddDate(0, 0, 6)

	report, err := h.analytics.GenerateWeeklyReport(c.Context(), userID, weekStart, weekEnd)
	if err != nil {
		return err
	}
	return c.JSON(report)
}

func (h *AnalyticsHandler) MonthlyReport(c *fiber.Ctx) error {
	userID, ok := c.Locals("userID").(string)
	if !ok || userID == "" {
		return fiber.NewError(fiber.StatusUnauthorized, "invalid_claims")
	}

	monthStr := c.Query("month")
	if monthStr == "" {
		monthStr = time.Now().Format("2006-01")
	}

	date, err := time.Parse("2006-01", monthStr)
	if err != nil {
		return fiber.NewError(fiber.StatusBadRequest, "invalid_month")
	}

	monthStart := time.Date(date.Year(), date.Month(), 1, 0, 0, 0, 0, time.UTC)
	monthEnd := monthStart.AddDate(0, 1, -1).Add(23*time.Hour + 59*time.Minute + 59*time.Second)

	report, err := h.analytics.GenerateMonthlyReport(c.Context(), userID, monthStart, monthEnd)
	if err != nil {
		return err
	}
	return c.JSON(report)
}

func (h *AnalyticsHandler) CompletionRate(c *fiber.Ctx) error {
	userID, ok := c.Locals("userID").(string)
	if !ok || userID == "" {
		return fiber.NewError(fiber.StatusUnauthorized, "invalid_claims")
	}

	fromStr := c.Query("from")
	toStr := c.Query("to")
	if fromStr == "" || toStr == "" {
		return fiber.NewError(fiber.StatusBadRequest, "missing_date_range")
	}

	periodStart, err := time.Parse("2006-01-02", fromStr)
	if err != nil {
		return fiber.NewError(fiber.StatusBadRequest, "invalid_from_date")
	}

	periodEnd, err := time.Parse("2006-01-02", toStr)
	if err != nil {
		return fiber.NewError(fiber.StatusBadRequest, "invalid_to_date")
	}

	stats, err := h.analytics.GetCompletionRate(c.Context(), userID, periodStart, periodEnd)
	if err != nil {
		return err
	}
	return c.JSON(stats)
}

func (h *AnalyticsHandler) StreakStats(c *fiber.Ctx) error {
	userID, ok := c.Locals("userID").(string)
	if !ok || userID == "" {
		return fiber.NewError(fiber.StatusUnauthorized, "invalid_claims")
	}

	stats, err := h.analytics.GetStreakStats(c.Context(), userID)
	if err != nil {
		return err
	}
	return c.JSON(stats)
}
