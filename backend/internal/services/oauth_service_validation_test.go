package services

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
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
	// Fail-closed contract: an empty raw nonce means replay protection is OFF,
	// so validateAppleNonce MUST reject it regardless of the token claim.
	// This protects any future caller that forgets to enforce the nonce at the
	// handler boundary.
	if err := validateAppleNonce("any-claim", ""); err == nil {
		t.Fatal("expected error when no nonce provided, got nil (fail-closed violated)")
	} else if !errors.Is(err, ErrInvalidOAuthToken) {
		t.Fatalf("expected error to wrap ErrInvalidOAuthToken, got %v", err)
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

// --- Apple email_verified decoder ---
//
// Apple has historically sent "email_verified" as a STRING ("true"/"false")
// in the ID token, even though many libraries expect a bool. The decoder must
// accept both representations and never fail (which would kill Apple Sign-In).

func TestParseAppleEmailVerified(t *testing.T) {
	tests := []struct {
		name string
		raw  string
		want bool
	}{
		{name: "empty payload is false", raw: "", want: false},
		{name: "json bool true", raw: "true", want: true},
		{name: "json bool false", raw: "false", want: false},
		{name: "string \"true\"", raw: `"true"`, want: true},
		{name: "string \"false\"", raw: `"false"`, want: false},
		{name: "string \"TRUE\" case-insensitive", raw: `"TRUE"`, want: true},
		{name: "whitespace-padded bool", raw: "  true  ", want: true},
		{name: "unknown string is false", raw: `"maybe"`, want: false},
		{name: "garbage payload is false", raw: `"---`, want: false},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := parseAppleEmailVerified(json.RawMessage(tt.raw))
			if got != tt.want {
				t.Fatalf("parseAppleEmailVerified(%q) = %v, want %v", tt.raw, got, tt.want)
			}
		})
	}
}
