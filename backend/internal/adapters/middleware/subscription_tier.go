package middleware

import (
	"github.com/gofiber/fiber/v2"
)

type RequireProFeature struct {
	Feature string
}

func NewRequireProFeatureMiddleware(feature string) fiber.Handler {
	return func(c *fiber.Ctx) error {
		userID := c.Locals("userID")
		if userID == nil {
			return c.Next()
		}

		tier := c.Locals("tier")
		if tier == nil {
			return c.Next()
		}

		if RequireProFeatureAccess(feature, tier.(string)) {
			return fiber.NewError(fiber.StatusForbidden, "feature_not_available")
		}

		return c.Next()
	}
}

// RequireProFeatureAccess returns true when the given feature requires premium
// access AND the current tier does NOT have it, i.e. access should be blocked.
func RequireProFeatureAccess(feature string, tier string) bool {
	limits := GetTierLimits(tier)
	switch feature {
	case "ai_insights":
		return !limits.AIInsights
	case "predictions":
		return !limits.Predictions
	case "advanced_analytics":
		return !limits.AdvancedAnalytics
	case "custom_timer":
		return !limits.CustomTimer
	case "mode_switching":
		return !limits.ModeSwitching
	default:
		return false
	}
}
