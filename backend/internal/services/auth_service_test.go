package services

import (
	"context"
	"testing"

	"pepinillo/backend/internal/adapters/behavior"
	"pepinillo/backend/internal/adapters/notifier"
	"pepinillo/backend/internal/adapters/stores/memory"
	"pepinillo/backend/internal/domain"
)

type fakeUserRepo struct {
	byID    map[string]*domain.User
	byEmail map[string]*domain.User
}

func newFakeUserRepo() *fakeUserRepo {
	return &fakeUserRepo{byID: map[string]*domain.User{}, byEmail: map[string]*domain.User{}}
}

func (r *fakeUserRepo) Create(_ context.Context, user *domain.User) error {
	r.byID[user.ID] = user
	r.byEmail[user.Email] = user
	return nil
}

func (r *fakeUserRepo) GetByID(_ context.Context, userID string) (*domain.User, error) {
	if user, ok := r.byID[userID]; ok {
		return user, nil
	}
	return nil, nil
}

func (r *fakeUserRepo) GetByEmail(_ context.Context, email string) (*domain.User, error) {
	if user, ok := r.byEmail[email]; ok {
		return user, nil
	}
	return nil, nil
}

func (r *fakeUserRepo) Update(_ context.Context, user *domain.User) error {
	r.byID[user.ID] = user
	r.byEmail[user.Email] = user
	return nil
}

func (r *fakeUserRepo) Delete(_ context.Context, userID string) error {
	if user, ok := r.byID[userID]; ok {
		delete(r.byEmail, user.Email)
	}
	delete(r.byID, userID)
	return nil
}

func (r *fakeUserRepo) MarkEmailVerified(_ context.Context, userID string) error {
	if user, ok := r.byID[userID]; ok {
		user.EmailVerified = true
	}
	return nil
}

func (r *fakeUserRepo) UpdateEmailPending(_ context.Context, userID, newEmail string) error {
	if user, ok := r.byID[userID]; ok {
		user.PendingEmail = &newEmail
	}
	return nil
}

func (r *fakeUserRepo) ConfirmEmailChange(_ context.Context, userID, newEmail string) error {
	if user, ok := r.byID[userID]; ok {
		delete(r.byEmail, user.Email)
		user.Email = newEmail
		user.PendingEmail = nil
		user.EmailVerified = true
		r.byEmail[newEmail] = user
	}
	return nil
}

func (r *fakeUserRepo) RollbackEmailChange(_ context.Context, userID string) error {
	if user, ok := r.byID[userID]; ok {
		user.PendingEmail = nil
	}
	return nil
}

func (r *fakeUserRepo) GetByGoogleID(_ context.Context, googleID string) (*domain.User, error) {
	for _, user := range r.byID {
		if user.GoogleID != nil && *user.GoogleID == googleID {
			return user, nil
		}
	}
	return nil, nil
}

func (r *fakeUserRepo) GetByAppleID(_ context.Context, appleID string) (*domain.User, error) {
	for _, user := range r.byID {
		if user.AppleID != nil && *user.AppleID == appleID {
			return user, nil
		}
	}
	return nil, nil
}

func (r *fakeUserRepo) LinkGoogleAccount(_ context.Context, userID, googleID, email, name, picture string) error {
	if user, ok := r.byID[userID]; ok {
		user.GoogleID = &googleID
		user.GoogleEmail = &email
		user.GoogleName = &name
		user.GooglePicture = &picture
	}
	return nil
}

func (r *fakeUserRepo) UnlinkGoogleAccount(_ context.Context, userID string) error {
	if user, ok := r.byID[userID]; ok {
		user.GoogleID = nil
		user.GoogleEmail = nil
		user.GoogleName = nil
		user.GooglePicture = nil
	}
	return nil
}

func (r *fakeUserRepo) LinkAppleAccount(_ context.Context, userID, appleID, email, name string) error {
	if user, ok := r.byID[userID]; ok {
		user.AppleID = &appleID
		user.AppleEmail = &email
		user.AppleName = &name
	}
	return nil
}

func (r *fakeUserRepo) UnlinkAppleAccount(_ context.Context, userID string) error {
	if user, ok := r.byID[userID]; ok {
		user.AppleID = nil
		user.AppleEmail = nil
		user.AppleName = nil
	}
	return nil
}

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
