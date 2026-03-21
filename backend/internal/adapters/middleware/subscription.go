package middleware

import (
	"strings"

	"github.com/gofiber/fiber/v2"

	"pepinillo/backend/internal/ports"
)

const (
	FreeTier   string = "free"
	ProMonthly string = "pro_monthly"
	ProAnnual  string = "pro_annual"
)

type SubscriptionTier string

type TierLimits struct {
	Tier              string `json:"tier"`
	MaxTasks          int    `json:"maxTasks"`
	MaxRecurrences    int    `json:"maxRecurrences"`
	AIInsights        bool   `json:"aiInsights"`
	Predictions       bool   `json:"predictions"`
	AdvancedAnalytics bool   `json:"advancedAnalytics"`
	CustomTimer       bool   `json:"customTimer"`
	ModeSwitching     bool   `json:"modeSwitching"`
}

func GetTierLimits(tier string) TierLimits {
	switch tier {
	case FreeTier:
		return TierLimits{
			Tier:              tier,
			MaxTasks:          100,
			MaxRecurrences:    5,
			AIInsights:        false,
			Predictions:       false,
			AdvancedAnalytics: false,
			CustomTimer:       false,
			ModeSwitching:     false,
		}
	case ProMonthly, ProAnnual:
		return TierLimits{
			Tier:              tier,
			MaxTasks:          10000,
			MaxRecurrences:    500,
			AIInsights:        true,
			Predictions:       true,
			AdvancedAnalytics: true,
			CustomTimer:       true,
			ModeSwitching:     true,
		}
	default:
		return TierLimits{
			Tier:              tier,
			MaxTasks:          100,
			MaxRecurrences:    5,
			AIInsights:        false,
			Predictions:       false,
			AdvancedAnalytics: false,
			CustomTimer:       false,
			ModeSwitching:     false,
		}
	}
}

func IsProTier(tier string) bool {
	return tier == ProMonthly || tier == ProAnnual
}

func NormalizeTier(tier string) string {
	normalized := strings.ToLower(strings.TrimSpace(tier))
	switch normalized {
	case "pro", "pro_monthly", "pro-monthly":
		return ProMonthly
	case "pro_annual", "pro-annual":
		return ProAnnual
	case "free", "":
		return FreeTier
	default:
		return FreeTier
	}
}

func CheckFeatureAccess(feature string, tier string) bool {
	limits := GetTierLimits(tier)
	switch feature {
	case "ai_insights":
		return limits.AIInsights
	case "predictions":
		return limits.Predictions
	case "advanced_analytics":
		return limits.AdvancedAnalytics
	case "custom_timer":
		return limits.CustomTimer
	case "mode_switching":
		return limits.ModeSwitching
	default:
		return false
	}
}

func RequireProTier(feature string, tier string) bool {
	if !CheckFeatureAccess(feature, tier) {
		return true
	}
	return false
}

type SubscriptionMiddleware struct {
	userRepo ports.UserRepository
}

func NewSubscriptionMiddleware(userRepo ports.UserRepository) fiber.Handler {
	return func(c *fiber.Ctx) error {
		userID := c.Locals("userID")
		if userID == nil {
			return c.Next()
		}

		user, err := userRepo.GetByID(c.Context(), userID.(string))
		if err != nil || user == nil {
			return c.Next()
		}

		tier := NormalizeTier(user.SubscriptionTier)

		c.Locals("tier", tier)
		c.Locals("tierLimits", GetTierLimits(tier))
		c.Locals("isPro", IsProTier(tier))

		return c.Next()
	}
}
