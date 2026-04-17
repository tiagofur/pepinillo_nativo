package services

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
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

// --- Apple nonce helpers ---

// sha256HexTest mirrors the iOS sha256Hex helper so tests are self-contained.
func sha256HexTest(s string) string {
	h := sha256.Sum256([]byte(s))
	return hex.EncodeToString(h[:])
}

// checkAppleNonce isolates the nonce-validation branch so it can be unit-tested
// without a real Apple JWT.
func checkAppleNonce(tokenNonce, providedNonce string) error {
	if providedNonce == "" {
		return nil // nonce is optional; skip validation when not provided
	}
	if tokenNonce == "" {
		return errors.New("apple token missing nonce claim")
	}
	expected := sha256HexTest(providedNonce)
	if tokenNonce != expected {
		return errors.New("apple token nonce mismatch")
	}
	return nil
}

func TestCheckAppleNonce_NoNonce(t *testing.T) {
	// When client sends no nonce, validation is skipped regardless of token claim.
	if err := checkAppleNonce("any-claim", ""); err != nil {
		t.Fatalf("expected nil when no nonce provided, got %v", err)
	}
}

func TestCheckAppleNonce_ValidNonce(t *testing.T) {
	raw := "test-raw-nonce-abc123"
	hashed := sha256HexTest(raw)
	if err := checkAppleNonce(hashed, raw); err != nil {
		t.Fatalf("expected nil for matching nonce, got %v", err)
	}
}

func TestCheckAppleNonce_MismatchedNonce(t *testing.T) {
	raw := "test-raw-nonce-abc123"
	hashed := sha256HexTest(raw)
	if err := checkAppleNonce(hashed, "wrong-nonce"); err == nil {
		t.Fatal("expected error for mismatched nonce, got nil")
	}
}

func TestCheckAppleNonce_MissingTokenClaim(t *testing.T) {
	if err := checkAppleNonce("", "some-nonce"); err == nil {
		t.Fatal("expected error when token has no nonce claim, got nil")
	}
}
