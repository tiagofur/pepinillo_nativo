package handlers

import (
	"errors"
	"testing"

	"github.com/gofiber/fiber/v2"

	"pepinillo/backend/internal/services"
)

func TestMapOAuthError(t *testing.T) {
	tests := []struct {
		name       string
		err        error
		statusCode int
	}{
		{
			name:       "google audience not configured",
			err:        services.ErrGoogleAudienceNotConfigured,
			statusCode: fiber.StatusServiceUnavailable,
		},
		{
			name:       "oauth email missing",
			err:        services.ErrOAuthEmailMissing,
			statusCode: fiber.StatusBadRequest,
		},
		{
			name:       "invalid oauth token",
			err:        services.ErrInvalidOAuthToken,
			statusCode: fiber.StatusUnauthorized,
		},
		{
			name:       "user not found",
			err:        services.ErrUserNotFound,
			statusCode: fiber.StatusNotFound,
		},
		{
			name:       "unknown error passthrough",
			err:        errors.New("boom"),
			statusCode: 0,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			mapped := mapOAuthError(tt.err)

			if tt.statusCode == 0 {
				if mapped != tt.err {
					t.Fatalf("expected passthrough error")
				}
				return
			}

			fe, ok := mapped.(*fiber.Error)
			if !ok {
				t.Fatalf("expected *fiber.Error, got %T", mapped)
			}
			if fe.Code != tt.statusCode {
				t.Fatalf("expected status %d, got %d", tt.statusCode, fe.Code)
			}
		})
	}
}
