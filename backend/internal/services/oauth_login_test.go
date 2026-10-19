package services

import (
	"context"
	"testing"

	"github.com/stretchr/testify/mock"
	"github.com/stretchr/testify/require"

	"pepinillo/backend/internal/domain"
)

// ---------------------------------------------------------------------------
// S-P0-1: Apple login must never resolve an existing account via the
// unverified client-supplied email.
// ---------------------------------------------------------------------------

func newOAuthServiceForTest(users *MockUserRepository, store *MockAuthStore) *OAuthService {
	return NewOAuthService(users, store, "test-jwt-secret-0123456789", "test-issuer", 900, 2592000, nil, "com.test.app", "", "", "")
}

func TestResolveAppleLogin_ClientEmailDoesNotTakeOverExistingAccount(t *testing.T) {
	users := &MockUserRepository{}
	store := &MockAuthStore{}
	svc := newOAuthServiceForTest(users, store)

	victimID := "victim-user-id"
	victim := &domain.User{ID: victimID, Email: "victim@example.com"}

	users.On("GetByAppleID", mock.Anything, "attacker-apple-sub").Return(nil, nil)
	users.On("GetByEmail", mock.Anything, "victim@example.com").Return(victim, nil)

	// Attacker presents their own valid Apple token (JWT carries no email)
	// plus the victim's address as clientEmail.
	tokenInfo := &appleTokenInfo{Sub: "attacker-apple-sub", Email: ""}
	_, _, err := svc.resolveAppleLogin(context.Background(), tokenInfo, "Attacker", "victim@example.com")

	require.ErrorIs(t, err, ErrOAuthEmailTaken)
	users.AssertNotCalled(t, "LinkAppleAccount", mock.Anything, mock.Anything, mock.Anything, mock.Anything, mock.Anything)
}

func TestResolveAppleLogin_ClientEmailCreatesNewUnverifiedAccount(t *testing.T) {
	users := &MockUserRepository{}
	store := &MockAuthStore{}
	svc := newOAuthServiceForTest(users, store)

	users.On("GetByAppleID", mock.Anything, "fresh-apple-sub").Return(nil, nil)
	users.On("GetByEmail", mock.Anything, "new@example.com").Return(nil, nil)
	users.On("Create", mock.Anything, mock.AnythingOfType("*domain.User")).Return(nil)
	store.On("StoreRefreshToken", mock.Anything, mock.Anything, mock.Anything, mock.Anything).Return(nil)

	tokenInfo := &appleTokenInfo{Sub: "fresh-apple-sub", Email: ""}
	user, tokens, err := svc.resolveAppleLogin(context.Background(), tokenInfo, "New User", "new@example.com")

	require.NoError(t, err)
	require.NotNil(t, user)
	require.NotNil(t, tokens)
	require.False(t, user.EmailVerified, "client-supplied email must stay unverified")
	require.Equal(t, "new@example.com", user.Email)
}

func TestResolveAppleLogin_JWTEmailStillLinksExistingAccount(t *testing.T) {
	users := &MockUserRepository{}
	store := &MockAuthStore{}
	svc := newOAuthServiceForTest(users, store)

	existing := &domain.User{ID: "user-1", Email: "user@example.com"}
	users.On("GetByAppleID", mock.Anything, "apple-sub-1").Return(nil, nil)
	users.On("GetByEmail", mock.Anything, "user@example.com").Return(existing, nil)
	users.On("LinkAppleAccount", mock.Anything, "user-1", "apple-sub-1", "user@example.com", mock.Anything).Return(nil)
	store.On("StoreRefreshToken", mock.Anything, "user-1", mock.Anything, mock.Anything).Return(nil)

	tokenInfo := &appleTokenInfo{Sub: "apple-sub-1", Email: "user@example.com"}
	user, tokens, err := svc.resolveAppleLogin(context.Background(), tokenInfo, "", "")

	require.NoError(t, err)
	require.Equal(t, "user-1", user.ID)
	require.NotNil(t, tokens)
}

// ---------------------------------------------------------------------------
// S2: Google auto-link requires a verified email.
// ---------------------------------------------------------------------------

func TestResolveGoogleLogin_UnverifiedEmailDoesNotLink(t *testing.T) {
	users := &MockUserRepository{}
	store := &MockAuthStore{}
	svc := newOAuthServiceForTest(users, store)

	existing := &domain.User{ID: "user-1", Email: "user@example.com"}
	users.On("GetByGoogleID", mock.Anything, "google-sub-1").Return(nil, nil)
	users.On("GetByEmail", mock.Anything, "user@example.com").Return(existing, nil)

	tokenInfo := &googleTokenInfo{Sub: "google-sub-1", Email: "user@example.com", EmailVerified: "false"}
	_, _, err := svc.resolveGoogleLogin(context.Background(), tokenInfo)

	require.ErrorIs(t, err, ErrOAuthEmailNotVerified)
	users.AssertNotCalled(t, "LinkGoogleAccount", mock.Anything, mock.Anything, mock.Anything, mock.Anything, mock.Anything, mock.Anything)
}

func TestResolveGoogleLogin_VerifiedEmailStillLinks(t *testing.T) {
	users := &MockUserRepository{}
	store := &MockAuthStore{}
	svc := newOAuthServiceForTest(users, store)

	existing := &domain.User{ID: "user-1", Email: "user@example.com"}
	users.On("GetByGoogleID", mock.Anything, "google-sub-1").Return(nil, nil)
	users.On("GetByEmail", mock.Anything, "user@example.com").Return(existing, nil)
	users.On("LinkGoogleAccount", mock.Anything, "user-1", "google-sub-1", "user@example.com", mock.Anything, mock.Anything).Return(nil)
	store.On("StoreRefreshToken", mock.Anything, "user-1", mock.Anything, mock.Anything).Return(nil)

	tokenInfo := &googleTokenInfo{Sub: "google-sub-1", Email: "user@example.com", EmailVerified: "true", Name: "U"}
	user, tokens, err := svc.resolveGoogleLogin(context.Background(), tokenInfo)

	require.NoError(t, err)
	require.Equal(t, "user-1", user.ID)
	require.NotNil(t, tokens)
}
