package services

import (
	"context"
	"testing"

	"github.com/google/uuid"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/mock"
	"golang.org/x/crypto/bcrypt"

	"pepinillo/backend/internal/domain"
)

// MockUserRepository, MockAuthStore, MockNotifier, MockBehaviorLogger are defined here.
// They implement the full ports interfaces.

func createTestUser() *domain.User {
	hash, _ := bcrypt.GenerateFromPassword([]byte("password123"), 12)
	return &domain.User{
		ID:            uuid.NewString(),
		Email:         "test@example.com",
		Name:          "Test User",
		PasswordHash:  strPtr(string(hash)),
		EmailVerified: false,
	}
}

func createAuthService(mockUserRepo *MockUserRepository, mockAuthStore *MockAuthStore, mockNotifier *MockNotifier, mockLogger *MockBehaviorLogger) *AuthService {
	return NewAuthService(
		mockUserRepo,
		mockAuthStore,
		mockNotifier,
		mockLogger,
		nil, // wsManager not needed for these tests
		"test_secret",
		"pepinillo-test",
		900,
		2592000,
	)
}

func TestAuthService_VerifyEmail_Success(t *testing.T) {
	mockUserRepo := new(MockUserRepository)
	mockAuthStore := new(MockAuthStore)
	mockNotifier := new(MockNotifier)
	mockLogger := new(MockBehaviorLogger)

	user := createTestUser()

	mockAuthStore.On("ValidateEmailVerificationCode", mock.Anything, "test@example.com", "123456").Return(true, nil)
	mockUserRepo.On("GetByEmail", mock.Anything, "test@example.com").Return(user, nil)
	mockUserRepo.On("MarkEmailVerified", mock.Anything, user.ID).Return(nil)
	mockAuthStore.On("RevokeEmailVerificationCode", mock.Anything, "test@example.com").Return(nil)
	mockLogger.On("LogEvent", mock.Anything, user.ID, "email_verified", mock.Anything).Return(nil)

	service := createAuthService(mockUserRepo, mockAuthStore, mockNotifier, mockLogger)

	updatedUser, _, err := service.VerifyEmail(context.Background(), "test@example.com", "123456")

	assert.NoError(t, err)
	assert.NotNil(t, updatedUser)
	assert.True(t, updatedUser.EmailVerified)

	mockUserRepo.AssertExpectations(t)
	mockAuthStore.AssertExpectations(t)
	mockLogger.AssertExpectations(t)
}

func TestAuthService_VerifyEmail_InvalidCode(t *testing.T) {
	mockUserRepo := new(MockUserRepository)
	mockAuthStore := new(MockAuthStore)
	mockNotifier := new(MockNotifier)
	mockLogger := new(MockBehaviorLogger)

	mockAuthStore.On("ValidateEmailVerificationCode", mock.Anything, "test@example.com", "000000").Return(false, nil)

	service := createAuthService(mockUserRepo, mockAuthStore, mockNotifier, mockLogger)

	_, _, err := service.VerifyEmail(context.Background(), "test@example.com", "000000")

	assert.Error(t, err)
	assert.ErrorIs(t, err, ErrInvalidVerificationCode)

	mockAuthStore.AssertExpectations(t)
}

func TestAuthService_VerifyEmail_AlreadyVerified(t *testing.T) {
	mockUserRepo := new(MockUserRepository)
	mockAuthStore := new(MockAuthStore)
	mockNotifier := new(MockNotifier)
	mockLogger := new(MockBehaviorLogger)

	user := createTestUser()
	user.EmailVerified = true

	mockAuthStore.On("ValidateEmailVerificationCode", mock.Anything, "test@example.com", "123456").Return(true, nil)
	mockUserRepo.On("GetByEmail", mock.Anything, "test@example.com").Return(user, nil)

	service := createAuthService(mockUserRepo, mockAuthStore, mockNotifier, mockLogger)

	_, _, err := service.VerifyEmail(context.Background(), "test@example.com", "123456")

	assert.Error(t, err)
	assert.ErrorIs(t, err, ErrEmailAlreadyVerified)

	mockUserRepo.AssertExpectations(t)
	mockAuthStore.AssertExpectations(t)
}

func TestAuthService_VerifyEmail_UserNotFound(t *testing.T) {
	mockUserRepo := new(MockUserRepository)
	mockAuthStore := new(MockAuthStore)
	mockNotifier := new(MockNotifier)
	mockLogger := new(MockBehaviorLogger)

	mockAuthStore.On("ValidateEmailVerificationCode", mock.Anything, "test@example.com", "123456").Return(true, nil)
	mockUserRepo.On("GetByEmail", mock.Anything, "test@example.com").Return(nil, nil)

	service := createAuthService(mockUserRepo, mockAuthStore, mockNotifier, mockLogger)

	_, _, err := service.VerifyEmail(context.Background(), "test@example.com", "123456")

	assert.Error(t, err)
	assert.ErrorIs(t, err, ErrUserNotFound)

	mockUserRepo.AssertExpectations(t)
	mockAuthStore.AssertExpectations(t)
}

func TestAuthService_ResendVerificationCode_Success(t *testing.T) {
	mockUserRepo := new(MockUserRepository)
	mockAuthStore := new(MockAuthStore)
	mockNotifier := new(MockNotifier)
	mockLogger := new(MockBehaviorLogger)

	user := createTestUser()

	mockUserRepo.On("GetByEmail", mock.Anything, "test@example.com").Return(user, nil)
	mockAuthStore.On("RevokeEmailVerificationCode", mock.Anything, "test@example.com").Return(nil)
	mockAuthStore.On("StoreEmailVerificationCode", mock.Anything, "test@example.com", mock.Anything, int64(15*60)).Return(nil)
	mockNotifier.On("SendEmailVerificationCode", mock.Anything, "test@example.com", mock.Anything).Return(nil)

	service := createAuthService(mockUserRepo, mockAuthStore, mockNotifier, mockLogger)

	err := service.ResendVerificationCode(context.Background(), "test@example.com")

	assert.NoError(t, err)

	mockUserRepo.AssertExpectations(t)
	mockAuthStore.AssertExpectations(t)
	mockNotifier.AssertExpectations(t)
}

func TestAuthService_ResendVerificationCode_AlreadyVerified(t *testing.T) {
	mockUserRepo := new(MockUserRepository)
	mockAuthStore := new(MockAuthStore)
	mockNotifier := new(MockNotifier)
	mockLogger := new(MockBehaviorLogger)

	user := createTestUser()
	user.EmailVerified = true

	mockUserRepo.On("GetByEmail", mock.Anything, "test@example.com").Return(user, nil)

	service := createAuthService(mockUserRepo, mockAuthStore, mockNotifier, mockLogger)

	err := service.ResendVerificationCode(context.Background(), "test@example.com")

	assert.Error(t, err)
	assert.ErrorIs(t, err, ErrEmailAlreadyVerified)

	mockUserRepo.AssertExpectations(t)
}

func TestAuthService_ResendVerificationCode_UserNotFound(t *testing.T) {
	mockUserRepo := new(MockUserRepository)
	mockAuthStore := new(MockAuthStore)
	mockNotifier := new(MockNotifier)
	mockLogger := new(MockBehaviorLogger)

	mockUserRepo.On("GetByEmail", mock.Anything, "test@example.com").Return(nil, nil)

	service := createAuthService(mockUserRepo, mockAuthStore, mockNotifier, mockLogger)

	err := service.ResendVerificationCode(context.Background(), "test@example.com")

	assert.Error(t, err)
	assert.ErrorIs(t, err, ErrUserNotFound)

	mockUserRepo.AssertExpectations(t)
}

// --- DeleteAccount tests (#193, #196) ---

func TestAuthService_DeleteAccount_Success_NoAppleCode(t *testing.T) {
	mockUserRepo := new(MockUserRepository)
	mockAuthStore := new(MockAuthStore)
	mockNotifier := new(MockNotifier)
	mockLogger := new(MockBehaviorLogger)

	user := createTestUser()

	mockLogger.On("LogEvent", mock.Anything, user.ID, "account_deleted", mock.Anything).Return(nil)
	mockAuthStore.On("RevokeAllRefreshTokens", mock.Anything, user.ID).Return(nil)
	mockUserRepo.On("Delete", mock.Anything, user.ID).Return(nil)

	service := createAuthService(mockUserRepo, mockAuthStore, mockNotifier, mockLogger)

	err := service.DeleteAccount(context.Background(), user.ID, nil)

	assert.NoError(t, err)
	mockUserRepo.AssertExpectations(t)
	mockAuthStore.AssertExpectations(t)
	mockLogger.AssertExpectations(t)
}

func TestAuthService_DeleteAccount_RevokesAppleToken_BestEffort(t *testing.T) {
	mockUserRepo := new(MockUserRepository)
	mockAuthStore := new(MockAuthStore)
	mockNotifier := new(MockNotifier)
	mockLogger := new(MockBehaviorLogger)

	user := createTestUser()
	user.AppleID = strPtr("apple-123")

	appleCode := "auth-code-from-apple"
	mockLogger.On("LogEvent", mock.Anything, user.ID, "account_deleted", mock.Anything).Return(nil)
	mockAuthStore.On("RevokeAllRefreshTokens", mock.Anything, user.ID).Return(nil)
	mockUserRepo.On("Delete", mock.Anything, user.ID).Return(nil)

	service := createAuthService(mockUserRepo, mockAuthStore, mockNotifier, mockLogger)

	// OAuthService is NOT wired here — DeleteAccount must not panic even when
	// oauthService is nil and an appleAuthorizationCode is provided. The Apple
	// revocation path is skipped entirely when oauthService is unset, so GetByID
	// is not called. This verifies the no-oauthService branch is safe (#196).
	err := service.DeleteAccount(context.Background(), user.ID, &appleCode)

	assert.NoError(t, err)
	mockUserRepo.AssertExpectations(t)
	mockAuthStore.AssertExpectations(t)
	mockLogger.AssertExpectations(t)
}

func TestAuthService_DeleteAccount_UserDeleteFailure(t *testing.T) {
	mockUserRepo := new(MockUserRepository)
	mockAuthStore := new(MockAuthStore)
	mockNotifier := new(MockNotifier)
	mockLogger := new(MockBehaviorLogger)

	user := createTestUser()
	deleteErr := assert.AnError

	mockLogger.On("LogEvent", mock.Anything, user.ID, "account_deleted", mock.Anything).Return(nil)
	mockAuthStore.On("RevokeAllRefreshTokens", mock.Anything, user.ID).Return(nil)
	mockUserRepo.On("Delete", mock.Anything, user.ID).Return(deleteErr)

	service := createAuthService(mockUserRepo, mockAuthStore, mockNotifier, mockLogger)

	err := service.DeleteAccount(context.Background(), user.ID, nil)

	assert.ErrorIs(t, err, deleteErr)
	mockUserRepo.AssertExpectations(t)
	mockAuthStore.AssertExpectations(t)
}
