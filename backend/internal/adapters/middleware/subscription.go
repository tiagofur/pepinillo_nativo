package middleware

import (
	"github.com/gofiber/fiber/v2"

	"pepinillo/backend/internal/ports"
)

const (
	FreeTier          string = "free"
	PepinilloPlus     string = "pepinillo_plus"
	EverywhereMonthly string = "everywhere_monthly"
	EverywhereAnnual  string = "everywhere_annual"
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
	case PepinilloPlus:
		return TierLimits{
			Tier:              tier,
			MaxTasks:          10000,
			MaxRecurrences:    500,
			AIInsights:        false,
			Predictions:       false,
			AdvancedAnalytics: true,
			CustomTimer:       true,
			ModeSwitching:     true,
		}
	case EverywhereMonthly, EverywhereAnnual:
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

// CanSync returns true only for the Everywhere+ tiers that have backend
// VPS sync. Free and Pepinillo+ do not have backend sync capability.
func CanSync(tier string) bool {
	return tier == EverywhereMonthly || tier == EverywhereAnnual
}

// NormalizeTier maps a raw tier string from the database to one of the canonical
// tier constants. Unknown or legacy strings map to "free".
// This is a clean cutover — no legacy aliases are accepted.
func NormalizeTier(tier string) string {
	switch tier {
	case FreeTier:
		return FreeTier
	case PepinilloPlus:
		return PepinilloPlus
	case EverywhereMonthly:
		return EverywhereMonthly
	case EverywhereAnnual:
		return EverywhereAnnual
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
		c.Locals("isPro", CanSync(tier))
		c.Locals("subscription_expires_at", user.SubscriptionExpiresAt)

		return c.Next()
	}
}
