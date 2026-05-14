package services

import (
	"context"
	"testing"

	"pepinillo/backend/internal/adapters/behavior"
	"pepinillo/backend/internal/adapters/notifier"
	"pepinillo/backend/internal/adapters/stores/memory"
)

func newAuthServiceForTest(repo *fakeUserRepo) *AuthService {
	return NewAuthService(
		repo,
		memory.NewAuthStore(),
		notifier.NewLogNotifier(),
		behavior.NewNoopLogger(),
		nil, // wsManager not needed for these tests
		"test-secret",
		"test-issuer",
		900,
		3600,
	)
}

func TestRegisterAndLogin(t *testing.T) {
	repo := newFakeUserRepo()
	service := newAuthServiceForTest(repo)
	ctx := context.Background()

	user, tokens, err := service.Register(ctx, "user@test.com", "User", "Password123")
	if err != nil {
		t.Fatalf("register failed: %v", err)
	}
	if user == nil || tokens == nil {
		t.Fatalf("expected user and tokens")
	}
	if tokens.AccessToken == "" || tokens.RefreshToken == "" {
		t.Fatalf("expected non-empty tokens")
	}

	_, loginTokens, err := service.Login(ctx, "user@test.com", "Password123")
	if err != nil {
		t.Fatalf("login failed: %v", err)
	}
	if loginTokens.AccessToken == "" || loginTokens.RefreshToken == "" {
		t.Fatalf("expected login tokens")
	}
}

func TestRefreshFlow(t *testing.T) {
	repo := newFakeUserRepo()
	service := newAuthServiceForTest(repo)
	ctx := context.Background()

	_, tokens, err := service.Register(ctx, "refresh@test.com", "Refresh", "Password123")
	if err != nil {
		t.Fatalf("register failed: %v", err)
	}

	newTokens, err := service.Refresh(ctx, tokens.RefreshToken)
	if err != nil {
		t.Fatalf("refresh failed: %v", err)
	}
	if newTokens.AccessToken == "" || newTokens.RefreshToken == "" {
		t.Fatalf("expected refreshed tokens")
	}
}

func TestChangePassword(t *testing.T) {
	repo := newFakeUserRepo()
	service := newAuthServiceForTest(repo)
	ctx := context.Background()

	user, _, err := service.Register(ctx, "changepwd@test.com", "User", "Password123")
	if err != nil {
		t.Fatalf("register failed: %v", err)
	}

	if err := service.ChangePassword(ctx, user.ID, "Password123", "NewPassword123"); err != nil {
		t.Fatalf("change password failed: %v", err)
	}

	if _, _, err := service.Login(ctx, "changepwd@test.com", "NewPassword123"); err != nil {
		t.Fatalf("login with new password failed: %v", err)
	}
}

func TestResetPassword(t *testing.T) {
	repo := newFakeUserRepo()
	store := memory.NewAuthStore()
	service := NewAuthService(
		repo,
		store,
		notifier.NewLogNotifier(),
		behavior.NewNoopLogger(),
		nil, // wsManager not needed for this test
		"test-secret",
		"test-issuer",
		900,
		3600,
	)
	ctx := context.Background()

	_, _, err := service.Register(ctx, "reset@test.com", "Reset", "Password123")
	if err != nil {
		t.Fatalf("register failed: %v", err)
	}

	if err := store.StorePasswordResetCode(ctx, "reset@test.com", "123456", 600); err != nil {
		t.Fatalf("store reset code failed: %v", err)
	}

	if err := service.ResetPassword(ctx, "reset@test.com", "123456", "NewPassword123"); err != nil {
		t.Fatalf("reset password failed: %v", err)
	}

	if _, _, err := service.Login(ctx, "reset@test.com", "NewPassword123"); err != nil {
		t.Fatalf("login after reset failed: %v", err)
	}
}
