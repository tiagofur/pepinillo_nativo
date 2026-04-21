package middleware

import "github.com/gofiber/fiber/v2"

// RequireEmailVerified blocks requests from JWT-authenticated users whose
// email has not yet been verified.  Apply this middleware to any route group
// that should only be reachable after the user has confirmed their address.
//
// The "emailVerified" flag is embedded in the access token by generateTokens
// (both AuthService and OAuthService).  A user who just verified their email
// receives fresh tokens from POST /auth/verify-email, so subsequent requests
// will carry the updated claim automatically.
func RequireEmailVerified() fiber.Handler {
	return func(c *fiber.Ctx) error {
		verified, _ := c.Locals("emailVerified").(bool)
		if !verified {
			return fiber.NewError(fiber.StatusForbidden, "email_not_verified")
		}
		return c.Next()
	}
}
