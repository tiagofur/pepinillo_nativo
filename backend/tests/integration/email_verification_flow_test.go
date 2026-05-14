package integration

import (
	"context"
	"sync"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"pepinillo/backend/internal/adapters/behavior"
	"pepinillo/backend/internal/adapters/stores/memory"
	"pepinillo/backend/internal/domain"
	"pepinillo/backend/internal/services"
)

// capturingNotifier records all sent codes so tests can retrieve them.
type capturingNotifier struct {
	mu    sync.Mutex
	codes map[string]string // email -> last code sent
}

func newCapturingNotifier() *capturingNotifier {
	return &capturingNotifier{codes: make(map[string]string)}
}

func (n *capturingNotifier) SendPasswordResetCode(_ context.Context, email, code string) error {
	n.mu.Lock()
	defer n.mu.Unlock()
	n.codes[email] = code
	return nil
}

func (n *capturingNotifier) SendEmailVerificationCode(_ context.Context, email, code string) error {
	n.mu.Lock()
	defer n.mu.Unlock()
	n.codes[email] = code
	return nil
}

func (n *capturingNotifier) SendEmailChangeVerification(_ context.Context, _, newEmail, code string) error {
	n.mu.Lock()
	defer n.mu.Unlock()
	n.codes[newEmail] = code
	return nil
}

func (n *capturingNotifier) LastCode(email string) string {
	n.mu.Lock()
	defer n.mu.Unlock()
	return n.codes[email]
}

// integrationUserRepo is an in-memory UserRepository for integration tests.
type integrationUserRepo struct {
	mu      sync.Mutex
	byID    map[string]*domain.User
	byEmail map[string]*domain.User
}

func newIntegrationUserRepo() *integrationUserRepo {
	return &integrationUserRepo{
		byID:    make(map[string]*domain.User),
		byEmail: make(map[string]*domain.User),
	}
}

func (r *integrationUserRepo) Create(_ context.Context, user *domain.User) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	r.byID[user.ID] = user
	r.byEmail[user.Email] = user
	return nil
}

func (r *integrationUserRepo) GetByID(_ context.Context, userID string) (*domain.User, error) {
	r.mu.Lock()
	defer r.mu.Unlock()
	return r.byID[userID], nil
}

func (r *integrationUserRepo) GetByEmail(_ context.Context, email string) (*domain.User, error) {
	r.mu.Lock()
	defer r.mu.Unlock()
	return r.byEmail[email], nil
}

func (r *integrationUserRepo) Update(_ context.Context, user *domain.User) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	r.byID[user.ID] = user
	r.byEmail[user.Email] = user
	return nil
}

func (r *integrationUserRepo) Delete(_ context.Context, userID string) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	if u, ok := r.byID[userID]; ok {
		delete(r.byEmail, u.Email)
	}
	delete(r.byID, userID)
	return nil
}

func (r *integrationUserRepo) MarkEmailVerified(_ context.Context, userID string) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	if u, ok := r.byID[userID]; ok {
		u.EmailVerified = true
	}
	return nil
}

func (r *integrationUserRepo) UpdateEmailPending(_ context.Context, userID, newEmail string) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	if u, ok := r.byID[userID]; ok {
		u.PendingEmail = &newEmail
	}
	return nil
}

func (r *integrationUserRepo) ConfirmEmailChange(_ context.Context, userID, newEmail string) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	if u, ok := r.byID[userID]; ok {
		delete(r.byEmail, u.Email)
		u.Email = newEmail
		u.PendingEmail = nil
		u.EmailVerified = true
		r.byEmail[newEmail] = u
	}
	return nil
}

func (r *integrationUserRepo) RollbackEmailChange(_ context.Context, userID string) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	if u, ok := r.byID[userID]; ok {
		u.PendingEmail = nil
	}
	return nil
}

func (r *integrationUserRepo) GetByGoogleID(_ context.Context, googleID string) (*domain.User, error) {
	r.mu.Lock()
	defer r.mu.Unlock()
	for _, user := range r.byID {
		if user.GoogleID != nil && *user.GoogleID == googleID {
			return user, nil
		}
	}
	return nil, nil
}

func (r *integrationUserRepo) GetByAppleID(_ context.Context, appleID string) (*domain.User, error) {
	r.mu.Lock()
	defer r.mu.Unlock()
	for _, user := range r.byID {
		if user.AppleID != nil && *user.AppleID == appleID {
			return user, nil
		}
	}
	return nil, nil
}

func (r *integrationUserRepo) LinkGoogleAccount(_ context.Context, userID, googleID, email, name, picture string) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	if u, ok := r.byID[userID]; ok {
		u.GoogleID = &googleID
		u.GoogleEmail = &email
		u.GoogleName = &name
		u.GooglePicture = &picture
	}
	return nil
}

func (r *integrationUserRepo) UnlinkGoogleAccount(_ context.Context, userID string) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	if u, ok := r.byID[userID]; ok {
		u.GoogleID = nil
		u.GoogleEmail = nil
		u.GoogleName = nil
		u.GooglePicture = nil
	}
	return nil
}

func (r *integrationUserRepo) LinkAppleAccount(_ context.Context, userID, appleID, email, name string) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	if u, ok := r.byID[userID]; ok {
		u.AppleID = &appleID
		u.AppleEmail = &email
		u.AppleName = &name
	}
	return nil
}

func (r *integrationUserRepo) UnlinkAppleAccount(_ context.Context, userID string) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	if u, ok := r.byID[userID]; ok {
		u.AppleID = nil
		u.AppleEmail = nil
		u.AppleName = nil
	}
	return nil
}

func (r *integrationUserRepo) ConsumeAiCredit(_ context.Context, _ string) (bool, error) {
	return true, nil
}

func (r *integrationUserRepo) RefreshAiCredits(_ context.Context, _ string, _ int) error {
	return nil
}

func newTestAuthService(repo *integrationUserRepo, notifier *capturingNotifier) *services.AuthService {
	return services.NewAuthService(
		repo,
		memory.NewAuthStore(),
		notifier,
		behavior.NewNoopLogger(),
		nil,
		"test_secret",
		"pepinillo-test",
		900,
		2592000,
	)
}

func TestAuthService_EmailVerificationFlow_Integration(t *testing.T) {
	if testing.Short() {
		t.Skip("skipping integration test")
	}

	ctx := context.Background()
	repo := newIntegrationUserRepo()
	notifier := newCapturingNotifier()
	svc := newTestAuthService(repo, notifier)

	// Step 1: Register — sends email verification code
	registeredUser, _, err := svc.Register(ctx, "integration@example.com", "Integration User", "Password123")
	require.NoError(t, err)
	require.NotNil(t, registeredUser)
	assert.False(t, registeredUser.EmailVerified)

	// Step 2: Verify email using the captured code
	code := notifier.LastCode("integration@example.com")
	require.NotEmpty(t, code, "expected a verification code to be sent")

	verifiedUser, _, err := svc.VerifyEmail(ctx, "integration@example.com", code)
	require.NoError(t, err)
	require.NotNil(t, verifiedUser)
	assert.True(t, verifiedUser.EmailVerified)

	// Step 3: Re-verify (should fail — already verified)
	_, _, err = svc.VerifyEmail(ctx, "integration@example.com", code)
	assert.Error(t, err)
}

func TestAuthService_EmailChangeFlow_Integration(t *testing.T) {
	if testing.Short() {
		t.Skip("skipping integration test")
	}

	ctx := context.Background()
	repo := newIntegrationUserRepo()
	notifier := newCapturingNotifier()
	svc := newTestAuthService(repo, notifier)

	// Setup: register and mark email verified
	user, _, err := svc.Register(ctx, "old@example.com", "Change User", "Password123")
	require.NoError(t, err)
	require.NoError(t, repo.MarkEmailVerified(ctx, user.ID))

	// Step 1: Request email change
	updated, err := svc.RequestEmailChange(ctx, user.ID, "new@example.com")
	require.NoError(t, err)
	require.NotNil(t, updated.PendingEmail)
	assert.Equal(t, "new@example.com", *updated.PendingEmail)

	// Step 2: Confirm with captured code
	code := notifier.LastCode("new@example.com")
	require.NotEmpty(t, code)

	confirmed, err := svc.ConfirmEmailChange(ctx, user.ID, code)
	require.NoError(t, err)
	assert.Nil(t, confirmed.PendingEmail)

	// Step 3: Request another change then cancel it
	_, err = svc.RequestEmailChange(ctx, user.ID, "another@example.com")
	require.NoError(t, err)

	err = svc.CancelEmailChange(ctx, user.ID)
	require.NoError(t, err)
}

func TestAuthService_ResendVerificationRateLimit(t *testing.T) {
	if testing.Short() {
		t.Skip("skipping integration test")
	}

	ctx := context.Background()
	repo := newIntegrationUserRepo()
	notifier := newCapturingNotifier()
	svc := newTestAuthService(repo, notifier)

	// Register a user first
	user, _, err := svc.Register(ctx, "ratelimit@example.com", "Rate Limit User", "Password123")
	require.NoError(t, err)
	require.NotNil(t, user)

	// Request multiple resend codes — should all succeed (no rate limiting yet)
	for i := 0; i < 5; i++ {
		err := svc.ResendVerificationCode(ctx, "ratelimit@example.com")
		assert.NoError(t, err, "resend %d should succeed", i+1)
	}
}
