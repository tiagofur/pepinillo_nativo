package handlers

import (
	"errors"
	"testing"

	"github.com/gofiber/fiber/v2"

	"pepinillo/backend/internal/services"
)

// TestMapAIError verifies that typed AI denial errors are surfaced with the
// correct HTTP status, and that unknown errors pass through untouched so the
// generic ErrorHandler can decide.
func TestMapAIError(t *testing.T) {
	tests := []struct {
		name       string
		err        error
		statusCode int
		message    string
	}{
		{
			name:       "tier insufficient maps to 402 Payment Required",
			err:        services.ErrTierInsufficientForCloudAI,
			statusCode: fiber.StatusPaymentRequired,
			message:    "tier_insufficient_for_cloud_ai",
		},
		{
			name:       "insufficient credits maps to 429 Too Many Requests",
			err:        services.ErrInsufficientAICredits,
			statusCode: fiber.StatusTooManyRequests,
			message:    "insufficient_ai_credits",
		},
		{
			name:       "wrapped tier insufficient still maps to 402",
			err:        errors.Join(services.ErrTierInsufficientForCloudAI, errors.New("ctx")),
			statusCode: fiber.StatusPaymentRequired,
			message:    "tier_insufficient_for_cloud_ai",
		},
		{
			name:       "unknown error passthrough",
			err:        errors.New("boom"),
			statusCode: 0,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			mapped := mapAIError(tt.err)

			if tt.statusCode == 0 {
				if mapped != tt.err {
					t.Fatalf("expected passthrough error, got %v", mapped)
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
			if fe.Message != tt.message {
				t.Fatalf("expected message %q, got %q", tt.message, fe.Message)
			}
		})
	}
}
