package services

import (
	"context"
	"time"

	"github.com/stretchr/testify/mock"

	"pepinillo/backend/internal/domain"
)

// MockUserRepository is a testify mock for ports.UserRepository.
type MockUserRepository struct {
	mock.Mock
}

func (m *MockUserRepository) Create(ctx context.Context, user *domain.User) error {
	args := m.Called(ctx, user)
	return args.Error(0)
}

func (m *MockUserRepository) GetByID(ctx context.Context, userID string) (*domain.User, error) {
	args := m.Called(ctx, userID)
	if args.Get(0) == nil {
		return nil, args.Error(1)
	}
	return args.Get(0).(*domain.User), args.Error(1)
}

func (m *MockUserRepository) GetByEmail(ctx context.Context, email string) (*domain.User, error) {
	args := m.Called(ctx, email)
	if args.Get(0) == nil {
		return nil, args.Error(1)
	}
	return args.Get(0).(*domain.User), args.Error(1)
}

func (m *MockUserRepository) Update(ctx context.Context, user *domain.User) error {
	args := m.Called(ctx, user)
	return args.Error(0)
}

func (m *MockUserRepository) UpdateSubscription(ctx context.Context, userID, tier string, expiresAt *time.Time) error {
	args := m.Called(ctx, userID, tier, expiresAt)
	return args.Error(0)
}

func (m *MockUserRepository) Delete(ctx context.Context, userID string) error {
	args := m.Called(ctx, userID)
	return args.Error(0)
}

func (m *MockUserRepository) MarkEmailVerified(ctx context.Context, userID string) error {
	args := m.Called(ctx, userID)
	return args.Error(0)
}

func (m *MockUserRepository) UpdateEmailPending(ctx context.Context, userID, newEmail string) error {
	args := m.Called(ctx, userID, newEmail)
	return args.Error(0)
}

func (m *MockUserRepository) ConfirmEmailChange(ctx context.Context, userID, newEmail string) error {
	args := m.Called(ctx, userID, newEmail)
	return args.Error(0)
}

func (m *MockUserRepository) RollbackEmailChange(ctx context.Context, userID string) error {
	args := m.Called(ctx, userID)
	return args.Error(0)
}

func (m *MockUserRepository) GetByGoogleID(ctx context.Context, googleID string) (*domain.User, error) {
	args := m.Called(ctx, googleID)
	if args.Get(0) == nil {
		return nil, args.Error(1)
	}
	return args.Get(0).(*domain.User), args.Error(1)
}

func (m *MockUserRepository) GetByAppleID(ctx context.Context, appleID string) (*domain.User, error) {
	args := m.Called(ctx, appleID)
	if args.Get(0) == nil {
		return nil, args.Error(1)
	}
	return args.Get(0).(*domain.User), args.Error(1)
}

func (m *MockUserRepository) LinkGoogleAccount(ctx context.Context, userID, googleID, email, name, picture string) error {
	args := m.Called(ctx, userID, googleID, email, name, picture)
	return args.Error(0)
}

func (m *MockUserRepository) UnlinkGoogleAccount(ctx context.Context, userID string) error {
	args := m.Called(ctx, userID)
	return args.Error(0)
}

func (m *MockUserRepository) LinkAppleAccount(ctx context.Context, userID, appleID, email, name string) error {
	args := m.Called(ctx, userID, appleID, email, name)
	return args.Error(0)
}

func (m *MockUserRepository) UnlinkAppleAccount(ctx context.Context, userID string) error {
	args := m.Called(ctx, userID)
	return args.Error(0)
}

func (m *MockUserRepository) ConsumeAiCredit(ctx context.Context, userID string) (bool, error) {
	args := m.Called(ctx, userID)
	return args.Bool(0), args.Error(1)
}

func (m *MockUserRepository) RefreshAiCredits(ctx context.Context, userID string, amount int) error {
	args := m.Called(ctx, userID, amount)
	return args.Error(0)
}

func (m *MockUserRepository) ClaimPurchaseToken(ctx context.Context, platform, token, userID string) (string, error) {
	args := m.Called(ctx, platform, token, userID)
	return args.String(0), args.Error(1)
}

func (m *MockUserRepository) ClaimWebhookEvent(ctx context.Context, eventID, source string) (bool, error) {
	args := m.Called(ctx, eventID, source)
	return args.Bool(0), args.Error(1)
}

// MockAuthStore is a testify mock for ports.AuthStore.
type MockAuthStore struct {
	mock.Mock
}

func (m *MockAuthStore) StoreRefreshToken(ctx context.Context, userID, token string, ttlSeconds int64) error {
	args := m.Called(ctx, userID, token, ttlSeconds)
	return args.Error(0)
}

func (m *MockAuthStore) ValidateRefreshToken(ctx context.Context, userID, token string) (bool, error) {
	args := m.Called(ctx, userID, token)
	return args.Bool(0), args.Error(1)
}

func (m *MockAuthStore) RevokeRefreshToken(ctx context.Context, userID, token string) error {
	args := m.Called(ctx, userID, token)
	return args.Error(0)
}

func (m *MockAuthStore) RevokeAllRefreshTokens(ctx context.Context, userID string) error {
	args := m.Called(ctx, userID)
	return args.Error(0)
}

func (m *MockAuthStore) StorePasswordResetCode(ctx context.Context, email, code string, ttlSeconds int64) error {
	args := m.Called(ctx, email, code, ttlSeconds)
	return args.Error(0)
}

func (m *MockAuthStore) ValidatePasswordResetCode(ctx context.Context, email, code string) (bool, error) {
	args := m.Called(ctx, email, code)
	return args.Bool(0), args.Error(1)
}

func (m *MockAuthStore) RevokePasswordResetCode(ctx context.Context, email string) error {
	args := m.Called(ctx, email)
	return args.Error(0)
}

func (m *MockAuthStore) StoreEmailVerificationCode(ctx context.Context, email, code string, ttlSeconds int64) error {
	args := m.Called(ctx, email, code, ttlSeconds)
	return args.Error(0)
}

func (m *MockAuthStore) ValidateEmailVerificationCode(ctx context.Context, email, code string) (bool, error) {
	args := m.Called(ctx, email, code)
	return args.Bool(0), args.Error(1)
}

func (m *MockAuthStore) RevokeEmailVerificationCode(ctx context.Context, email string) error {
	args := m.Called(ctx, email)
	return args.Error(0)
}

// MockNotifier is a testify mock for ports.Notifier.
type MockNotifier struct {
	mock.Mock
}

func (m *MockNotifier) SendPasswordResetCode(ctx context.Context, email, code string) error {
	args := m.Called(ctx, email, code)
	return args.Error(0)
}

func (m *MockNotifier) SendEmailVerificationCode(ctx context.Context, email, code string) error {
	args := m.Called(ctx, email, code)
	return args.Error(0)
}

func (m *MockNotifier) SendEmailChangeVerification(ctx context.Context, oldEmail, newEmail, code string) error {
	args := m.Called(ctx, oldEmail, newEmail, code)
	return args.Error(0)
}

// MockBehaviorLogger is a testify mock for ports.BehaviorLogger.
type MockBehaviorLogger struct {
	mock.Mock
}

func (m *MockBehaviorLogger) LogEvent(ctx context.Context, userID, eventType string, eventData map[string]any) error {
	args := m.Called(ctx, userID, eventType, eventData)
	return args.Error(0)
}
