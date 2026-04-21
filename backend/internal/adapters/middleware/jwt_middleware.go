package middleware

import (
	"strings"

	"github.com/gofiber/fiber/v2"
	"github.com/golang-jwt/jwt/v5"
)

type UserClaims struct {
	UserID        string `json:"userId"`
	Email         string `json:"email"`
	Tier          string `json:"tier"`
	TokenType     string `json:"tokenType"`
	EmailVerified bool   `json:"emailVerified"`
	jwt.RegisteredClaims
}

func JWT(secret string) fiber.Handler {
	return func(c *fiber.Ctx) error {
		authHeader := c.Get("Authorization")
		if authHeader == "" {
			return fiber.NewError(fiber.StatusUnauthorized, "missing_auth_header")
		}

		parts := strings.SplitN(authHeader, " ", 2)
		if len(parts) != 2 || strings.ToLower(parts[0]) != "bearer" {
			return fiber.NewError(fiber.StatusUnauthorized, "invalid_auth_header")
		}

		tokenString := parts[1]
		token, err := jwt.ParseWithClaims(tokenString, &UserClaims{}, func(token *jwt.Token) (any, error) {
			return []byte(secret), nil
		})
		if err != nil || !token.Valid {
			return fiber.NewError(fiber.StatusUnauthorized, "invalid_token")
		}

		claims, ok := token.Claims.(*UserClaims)
		if !ok {
			return fiber.NewError(fiber.StatusUnauthorized, "invalid_claims")
		}
		if claims.TokenType != "access" {
			return fiber.NewError(fiber.StatusUnauthorized, "invalid_token_type")
		}

		c.Locals("userID", claims.UserID)
		c.Locals("email", claims.Email)
		c.Locals("tier", claims.Tier)
		c.Locals("emailVerified", claims.EmailVerified)
		return c.Next()
	}
}
