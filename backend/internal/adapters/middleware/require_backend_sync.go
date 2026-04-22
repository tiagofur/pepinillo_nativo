package middleware

import (
	"time"

	"github.com/gofiber/fiber/v2"
)

// NewRequireBackendSync returns a Fiber middleware that rejects requests from
// users whose effective tier does not include backend VPS sync (i.e. any tier
// other than the three Everywhere+ variants).
//
// Prerequisites: the JWT middleware and SubscriptionMiddleware must have run
// before this middleware, so that "tier" and "subscription_expires_at" are
// already populated in c.Locals.
//
// On rejection: HTTP 402 with JSON body:
//
//	{"error":"subscription_required","code":"ERR_TIER_INSUFFICIENT","message":"...","upgrade_url":"..."}
func NewRequireBackendSync() fiber.Handler {
	return func(c *fiber.Ctx) error {
		tier, _ := c.Locals("tier").(string)
		expiresAt, _ := c.Locals("subscription_expires_at").(*time.Time)

		if !CanSync(tier) {
			return insufficientTierError(c)
		}

		// CanSync is true — check expiry. Lifetime tiers have no expiry (nil).
		if expiresAt != nil && !expiresAt.After(time.Now().UTC()) {
			return insufficientTierError(c)
		}

		return c.Next()
	}
}

func insufficientTierError(c *fiber.Ctx) error {
	return c.Status(fiber.StatusPaymentRequired).JSON(fiber.Map{
		"error":       "subscription_required",
		"code":        "ERR_TIER_INSUFFICIENT",
		"message":     "An Everywhere+ subscription is required to use backend sync",
		"upgrade_url": "https://pepinillo.app/upgrade",
	})
}
