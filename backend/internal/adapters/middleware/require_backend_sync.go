package middleware

import (
	"time"

	"github.com/gofiber/fiber/v2"
)

// NewRequireBackendSync gates the sync endpoints (#942 S5):
//
//   - Everywhere+ tiers: full multi-device sync (previous behavior). The
//     expiry check still applies — a lapsed subscription falls to the
//     effective tier below.
//   - Free and Pepinillo+ tiers: single-device server backup. The request
//     must carry the bound X-Device-ID; an EMPTY binding passes so the
//     first successful initial-upload can claim it (bind-on-upload in the
//     handler).
//
// Prerequisites: JWT + SubscriptionMiddleware must have run first, so
// "tier", "subscription_expires_at" and "sync_device_id" are in c.Locals.
//
// On rejection:
//
//	402 {"code":"ERR_TIER_INSUFFICIENT"} — expired Everywhere+ (unchanged)
//	403 {"code":"ERR_DEVICE_BOUND"}      — another device owns the backup
func NewRequireBackendSync() fiber.Handler {
	return requireBackendSync(false)
}

// NewRequireEverywhereSync keeps the pre-#942 strict gate for surfaces that
// are NOT part of the device-bound lane (PUT /preferences): only an active
// Everywhere+ subscription passes.
func NewRequireEverywhereSync() fiber.Handler {
	return requireBackendSync(true)
}

func requireBackendSync(strict bool) fiber.Handler {
	return func(c *fiber.Ctx) error {
		tier, _ := c.Locals("tier").(string)
		expiresAt, _ := c.Locals("subscription_expires_at").(*time.Time)

		// Fail closed (B5 convention): an absent tier means the middleware
		// chain is misconfigured — never fall through to the bound lane.
		if tier == "" {
			return insufficientTierError(c)
		}

		if CanSync(tier) {
			// Everywhere lane — check expiry. Lifetime tiers have no expiry (nil).
			if expiresAt != nil && !expiresAt.After(time.Now().UTC()) {
				return insufficientTierError(c)
			}
			return c.Next()
		}

		if strict {
			return insufficientTierError(c)
		}

		// Device-bound lane (free / pepinillo_plus). Fail-closed on a
		// missing header too (#942 review P2-2): a client that never sends
		// X-Device-ID could otherwise stay unbound forever and sync from
		// any device, bypassing the gate.
		deviceID := c.Get("X-Device-ID", "")
		bound, _ := c.Locals("sync_device_id").(string)
		if deviceID == "" || (bound != "" && bound != deviceID) {
			return deviceBoundError(c)
		}
		return c.Next()
	}
}

func insufficientTierError(c *fiber.Ctx) error {
	return c.Status(fiber.StatusPaymentRequired).JSON(fiber.Map{
		"error":       "subscription_required",
		"code":        "ERR_TIER_INSUFFICIENT",
		"message":     "An Everywhere+ subscription is required to use backend sync",
		"upgrade_url": "https://app.pepinillo.app/upgrade",
	})
}

func deviceBoundError(c *fiber.Ctx) error {
	return c.Status(fiber.StatusForbidden).JSON(fiber.Map{
		"error":       "device_bound",
		"code":        "ERR_DEVICE_BOUND",
		"message":     "This account's server backup is bound to another device. Everywhere+ syncs across devices",
		"upgrade_url": "https://app.pepinillo.app/upgrade",
	})
}
