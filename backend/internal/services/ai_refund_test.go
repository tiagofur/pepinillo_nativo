package services

import (
	"context"
	"errors"
	"testing"

	"github.com/stretchr/testify/mock"
	"github.com/stretchr/testify/require"
)

type stubLLMProvider struct {
	content string
	err     error
}

func (f *stubLLMProvider) Generate(_ context.Context, _, _ string) (string, error) {
	return f.content, f.err
}

// A5: a failed generation refunds the consumed credit.
func TestGenerateWithRefund_FailureRefunds(t *testing.T) {
	users := &MockUserRepository{}
	svc := &AIService{users: users, llm: &stubLLMProvider{err: errors.New("provider down")}}
	users.On("RefundAiCredit", mock.Anything, "user-1").Return(nil)

	_, err := svc.generateWithRefund(context.Background(), "user-1", "sys", "prompt")

	require.Error(t, err)
	users.AssertCalled(t, "RefundAiCredit", mock.Anything, "user-1")
}

// A5: empty generation output also refunds.
func TestGenerateWithRefund_EmptyRefunds(t *testing.T) {
	users := &MockUserRepository{}
	svc := &AIService{users: users, llm: &stubLLMProvider{content: "   "}}
	users.On("RefundAiCredit", mock.Anything, "user-1").Return(nil)

	_, err := svc.generateWithRefund(context.Background(), "user-1", "sys", "prompt")

	require.ErrorIs(t, err, ErrAIGenerationFailed)
	users.AssertCalled(t, "RefundAiCredit", mock.Anything, "user-1")
}

// A5: successful generation keeps the charge.
func TestGenerateWithRefund_SuccessKeepsCharge(t *testing.T) {
	users := &MockUserRepository{}
	svc := &AIService{users: users, llm: &stubLLMProvider{content: "tip content"}}
	users.On("RefundAiCredit", mock.Anything, mock.Anything).Return(nil)

	content, err := svc.generateWithRefund(context.Background(), "user-1", "sys", "prompt")

	require.NoError(t, err)
	require.Equal(t, "tip content", content)
	users.AssertNotCalled(t, "RefundAiCredit", mock.Anything, mock.Anything)
}
