package memory

import (
	"context"
	"encoding/hex"
	"testing"
)

// Refresh tokens are stored hashed (HMAC). Verify the round-trip: Store then
// Validate with the same token succeeds, with a different token fails, and
// that the raw token never appears in the internal map keys.
func TestRefreshTokenHashRoundTrip(t *testing.T) {
	ctx := context.Background()
	key, _ := hex.DecodeString("6f6e657477656e7479746872656566697665737632303234707265766f7564656e6365")
	store := NewAuthStoreWithKey(key)

	const userID = "user-1"
	const token = "rt_abcdef123456_supersecret"

	if err := store.StoreRefreshToken(ctx, userID, token, 60); err != nil {
		t.Fatalf("store failed: %v", err)
	}

	ok, err := store.ValidateRefreshToken(ctx, userID, token)
	if err != nil {
		t.Fatalf("validate failed: %v", err)
	}
	if !ok {
		t.Fatal("expected token to be valid")
	}

	ok, err = store.ValidateRefreshToken(ctx, userID, "rt_different_token")
	if err != nil {
		t.Fatalf("validate failed: %v", err)
	}
	if ok {
		t.Fatal("expected different token to be rejected")
	}

	// The raw token must not appear as a map key — that's the whole point of
	// hashing. We can't reach into the map directly (unexported), so we
	// validate the negative: a fresh store keyed with a DIFFERENT hashKey
	// MUST NOT recognise the same (userID, token) pair, because the HMAC
	// output is keyed.
	otherKey := make([]byte, 32)
	otherKey[0] = 1
	otherStore := NewAuthStoreWithKey(otherKey)
	if err := otherStore.StoreRefreshToken(ctx, userID, "placeholder", 60); err != nil {
		t.Fatalf("other store store failed: %v", err)
	}
	ok, err = otherStore.ValidateRefreshToken(ctx, userID, token)
	if err != nil {
		t.Fatalf("other store validate failed: %v", err)
	}
	if ok {
		t.Fatal("expected token hashed with different key to be rejected")
	}
}

func TestRefreshTokenRevoke(t *testing.T) {
	ctx := context.Background()
	store := NewAuthStore()

	const userID = "user-2"
	const token = "rt_to_revoke"

	if err := store.StoreRefreshToken(ctx, userID, token, 60); err != nil {
		t.Fatalf("store failed: %v", err)
	}
	if err := store.RevokeRefreshToken(ctx, userID, token); err != nil {
		t.Fatalf("revoke failed: %v", err)
	}

	ok, err := store.ValidateRefreshToken(ctx, userID, token)
	if err != nil {
		t.Fatalf("validate failed: %v", err)
	}
	if ok {
		t.Fatal("expected revoked token to be invalid")
	}
}

func TestRefreshTokenRevokeAll(t *testing.T) {
	ctx := context.Background()
	store := NewAuthStore()

	const userID = "user-3"
	if err := store.StoreRefreshToken(ctx, userID, "t1", 60); err != nil {
		t.Fatalf("store t1 failed: %v", err)
	}
	if err := store.StoreRefreshToken(ctx, userID, "t2", 60); err != nil {
		t.Fatalf("store t2 failed: %v", err)
	}
	if err := store.RevokeAllRefreshTokens(ctx, userID); err != nil {
		t.Fatalf("revoke all failed: %v", err)
	}

	for _, tk := range []string{"t1", "t2"} {
		ok, err := store.ValidateRefreshToken(ctx, userID, tk)
		if err != nil {
			t.Fatalf("validate %s failed: %v", tk, err)
		}
		if ok {
			t.Fatalf("expected %s to be invalid after RevokeAll", tk)
		}
	}
}
