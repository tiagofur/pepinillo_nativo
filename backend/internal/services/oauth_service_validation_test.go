package services

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"testing"
	"time"
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

// --- Apple nonce helpers ---

// sha256HexTest mirrors the iOS sha256Hex helper so tests are self-contained.
func sha256HexTest(s string) string {
	h := sha256.Sum256([]byte(s))
	return hex.EncodeToString(h[:])
}

func TestCheckAppleNonce_NoNonce(t *testing.T) {
	// When client sends no nonce, validation is skipped regardless of token claim.
	if err := validateAppleNonce("any-claim", ""); err != nil {
		t.Fatalf("expected nil when no nonce provided, got %v", err)
	}
}

func TestCheckAppleNonce_ValidNonce(t *testing.T) {
	raw := "test-raw-nonce-abc123"
	hashed := sha256HexTest(raw)
	if err := validateAppleNonce(hashed, raw); err != nil {
		t.Fatalf("expected nil for matching nonce, got %v", err)
	}
}

func TestCheckAppleNonce_MismatchedNonce(t *testing.T) {
	raw := "test-raw-nonce-abc123"
	hashed := sha256HexTest(raw)
	if err := validateAppleNonce(hashed, "wrong-nonce"); err == nil {
		t.Fatal("expected error for mismatched nonce, got nil")
	}
}

func TestCheckAppleNonce_MissingTokenClaim(t *testing.T) {
	if err := validateAppleNonce("", "some-nonce"); err == nil {
		t.Fatal("expected error when token has no nonce claim, got nil")
	}
}

func TestValidateAppleIssuedAt_Valid(t *testing.T) {
	now := time.Now()
	iat := now.Add(-2 * time.Minute)
	if err := validateAppleIssuedAt(iat, now); err != nil {
		t.Fatalf("expected valid iat, got %v", err)
	}
}

func TestValidateAppleIssuedAt_Missing(t *testing.T) {
	if err := validateAppleIssuedAt(time.Time{}, time.Now()); err == nil {
		t.Fatal("expected error for missing iat, got nil")
	}
}

func TestValidateAppleIssuedAt_TooOld(t *testing.T) {
	now := time.Now()
	iat := now.Add(-appleTokenMaxAge).Add(-time.Second)
	if err := validateAppleIssuedAt(iat, now); err == nil {
		t.Fatal("expected error for old iat, got nil")
	}
}

func TestValidateAppleIssuedAt_Future(t *testing.T) {
	now := time.Now()
	iat := now.Add(35 * time.Second)
	if err := validateAppleIssuedAt(iat, now); err == nil {
		t.Fatal("expected error for future iat, got nil")
	}
}
