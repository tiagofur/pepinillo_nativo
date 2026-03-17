package notifier

import (
	"context"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/mock"
)

// MockNotifier is a mock for testing
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

func TestSendGridNotifier_SendPasswordResetCode(t *testing.T) {
	if testing.Short() {
		t.Skip("skipping test in short mode")
	}

	notifier := NewSendGridNotifier(
		"test_api_key",
		"noreply@test.com",
		"TestApp",
	)

	if notifier == nil {
		t.Skip("SendGrid not configured")
		return
	}

	ctx := context.Background()
	err := notifier.SendPasswordResetCode(ctx, "user@example.com", "123456")

	// Note: This will fail without a real API key, which is expected
	// In production, use a mock API key or test service
	assert.Error(t, err, "should return error with invalid API key")
}

func TestSendGridNotifier_SendEmailVerificationCode(t *testing.T) {
	if testing.Short() {
		t.Skip("skipping test in short mode")
	}

	notifier := NewSendGridNotifier(
		"test_api_key",
		"noreply@test.com",
		"TestApp",
	)

	if notifier == nil {
		t.Skip("SendGrid not configured")
		return
	}

	ctx := context.Background()
	err := notifier.SendEmailVerificationCode(ctx, "user@example.com", "123456")

	// Note: This will fail without a real API key, which is expected
	assert.Error(t, err, "should return error with invalid API key")
}

func TestSendGridNotifier_SendEmailChangeVerification(t *testing.T) {
	if testing.Short() {
		t.Skip("skipping test in short mode")
	}

	notifier := NewSendGridNotifier(
		"test_api_key",
		"noreply@test.com",
		"TestApp",
	)

	if notifier == nil {
		t.Skip("SendGrid not configured")
		return
	}

	ctx := context.Background()
	err := notifier.SendEmailChangeVerification(ctx, "old@example.com", "new@example.com", "123456")

	// Note: This will fail without a real API key, which is expected
	assert.Error(t, err, "should return error with invalid API key")
}

func TestSendGridNotifier_NilWithEmptyAPIKey(t *testing.T) {
	notifier := NewSendGridNotifier("", "noreply@test.com", "TestApp")
	assert.Nil(t, notifier, "should return nil with empty API key")
}

func TestFallbackNotifier_SendPasswordResetCode(t *testing.T) {
	ctx := context.Background()

	// Create FallbackNotifier with nil SendGrid (will use LogNotifier)
	fallback := NewFallbackNotifier("", "noreply@test.com", "TestApp")
	
	err := fallback.SendPasswordResetCode(ctx, "user@example.com", "123456")
	assert.NoError(t, err, "LogNotifier should not return error")
}

func TestFallbackNotifier_SendEmailVerificationCode(t *testing.T) {
	ctx := context.Background()

	// Create FallbackNotifier with nil SendGrid (will use LogNotifier)
	fallback := NewFallbackNotifier("", "noreply@test.com", "TestApp")
	
	err := fallback.SendEmailVerificationCode(ctx, "user@example.com", "123456")
	assert.NoError(t, err, "LogNotifier should not return error")
}

func TestFallbackNotifier_SendEmailChangeVerification(t *testing.T) {
	ctx := context.Background()

	// Create FallbackNotifier with nil SendGrid (will use LogNotifier)
	fallback := NewFallbackNotifier("", "noreply@test.com", "TestApp")
	
	err := fallback.SendEmailChangeVerification(ctx, "old@example.com", "new@example.com", "123456")
	assert.NoError(t, err, "LogNotifier should not return error")
}

func TestLogNotifier_SendPasswordResetCode(t *testing.T) {
	ctx := context.Background()
	notifier := NewLogNotifier()

	err := notifier.SendPasswordResetCode(ctx, "user@example.com", "123456")
	assert.NoError(t, err, "LogNotifier should not return error")
}

func TestLogNotifier_SendEmailVerificationCode(t *testing.T) {
	ctx := context.Background()
	notifier := NewLogNotifier()

	err := notifier.SendEmailVerificationCode(ctx, "user@example.com", "123456")
	assert.NoError(t, err, "LogNotifier should not return error")
}

func TestLogNotifier_SendEmailChangeVerification(t *testing.T) {
	ctx := context.Background()
	notifier := NewLogNotifier()

	err := notifier.SendEmailChangeVerification(ctx, "old@example.com", "new@example.com", "123456")
	assert.NoError(t, err, "LogNotifier should not return error")
}

func TestGenerateVerificationCode(t *testing.T) {
	code := GenerateVerificationCode()
	assert.Len(t, code, 6, "code should be 6 digits")

	// Check all characters are digits
	for _, char := range code {
		assert.True(t, char >= '0' && char <= '9', "all characters should be digits")
	}
}

func TestFormatEmail(t *testing.T) {
	tests := []struct {
		name     string
		input    string
		expected string
	}{
		{"simple", "test@example.com", "test@example.com"},
		{"uppercase", "TEST@EXAMPLE.COM", "test@example.com"},
		{"spaces", "  test@example.com  ", "test@example.com"},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := FormatEmail(tt.input)
			assert.Equal(t, tt.expected, result)
		})
	}
}

func TestIsValidEmail(t *testing.T) {
	tests := []struct {
		name     string
		email    string
		expected bool
	}{
		{"valid", "test@example.com", true},
		{"invalid", "invalid-email", false},
		{"empty", "", false},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := IsValidEmail(tt.email)
			assert.Equal(t, tt.expected, result)
		})
	}
}
