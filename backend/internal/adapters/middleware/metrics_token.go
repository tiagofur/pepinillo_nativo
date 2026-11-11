package middleware

import (
	"crypto/sha256"
	"crypto/subtle"
	"strings"

	"github.com/gofiber/fiber/v2"
)

// RequireMetricsToken guards the internal stats endpoint with a static opaque
// Bearer token. It fails closed: an empty configured token disables the route
// (always 401), and comparison is constant-time over fixed-length digests.
func RequireMetricsToken(expected string) fiber.Handler {
	want := sha256.Sum256([]byte(expected))
	return func(c *fiber.Ctx) error {
		if expected == "" {
			return fiber.NewError(fiber.StatusUnauthorized, "invalid_token")
		}
		header := c.Get(fiber.HeaderAuthorization)
		const prefix = "Bearer "
		if len(header) <= len(prefix) || !strings.EqualFold(header[:len(prefix)], prefix) {
			return fiber.NewError(fiber.StatusUnauthorized, "invalid_token")
		}
		got := sha256.Sum256([]byte(strings.TrimSpace(header[len(prefix):])))
		if subtle.ConstantTimeCompare(got[:], want[:]) != 1 {
			return fiber.NewError(fiber.StatusUnauthorized, "invalid_token")
		}
		return c.Next()
	}
}
