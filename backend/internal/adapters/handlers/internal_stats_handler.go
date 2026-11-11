package handlers

import (
	"time"

	"github.com/gofiber/fiber/v2"

	"pepinillo/backend/internal/adapters/middleware"
	"pepinillo/backend/internal/ports"
)

// InternalStatsHandler serves GET /internal/stats: consent-filtered aggregates
// for the CRM metrics collector. Aggregate-only, never PII.
type InternalStatsHandler struct {
	repo ports.InternalStatsRepository
}

func NewInternalStatsHandler(repo ports.InternalStatsRepository) *InternalStatsHandler {
	return &InternalStatsHandler{repo: repo}
}

func (h *InternalStatsHandler) Get(c *fiber.Ctx) error {
	stats, err := h.repo.Compute(c.Context(), time.Now().UTC())
	if err != nil {
		return err
	}
	c.Set(fiber.HeaderCacheControl, "no-store")
	return c.JSON(stats)
}

// RegisterInternalRoutes mounts /internal/* on the root router (outside
// /api/v1). With an empty token the route stays registered but always 401s.
func RegisterInternalRoutes(app fiber.Router, h *InternalStatsHandler, token string) {
	internal := app.Group("/internal", middleware.RequireMetricsToken(token))
	internal.Get("/stats", h.Get)
}
