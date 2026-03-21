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

func RequireProFeatureAccess(feature string, tier string) bool {
	switch feature {
	case "ai_insights":
		return tier == "pro_monthly" || tier == "pro_annual"
	case "predictions":
		return tier == "pro_monthly" || tier == "pro_annual"
	case "advanced_analytics":
		return tier == "pro_monthly" || tier == "pro_annual"
	case "custom_timer":
		return tier == "pro_monthly" || tier == "pro_annual"
	case "mode_switching":
		return tier == "pro_monthly" || tier == "pro_annual"
	default:
		return false
	}
}
