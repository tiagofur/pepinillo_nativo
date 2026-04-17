package services

import (
	"context"
	"errors"
	"testing"
)

func TestIsValidGoogleAudience(t *testing.T) {
	svc := &OAuthService{googleClientIDs: []string{"a-client-id", "b-client-id"}}

	if !svc.isValidGoogleAudience("a-client-id") {
		t.Fatalf("expected configured audience to be valid")
	}

	if svc.isValidGoogleAudience("unknown-client-id") {
		t.Fatalf("expected unknown audience to be invalid")
	}
}

func TestVerifyGoogleTokenRequiresConfiguredAudience(t *testing.T) {
	svc := &OAuthService{}

	_, err := svc.verifyGoogleToken(context.Background(), "any-token")
	if !errors.Is(err, ErrGoogleAudienceNotConfigured) {
		t.Fatalf("expected ErrGoogleAudienceNotConfigured, got %v", err)
	}
}
