package notifier

import (
	"context"
	"log"
)

type LogNotifier struct{}

func NewLogNotifier() *LogNotifier {
	return &LogNotifier{}
}

func (n *LogNotifier) SendPasswordResetCode(_ context.Context, email, code string) error {
	log.Printf("[LOG NOTIFIER] password reset code generated for %s: %s", email, code)
	return nil
}

func (n *LogNotifier) SendEmailVerificationCode(_ context.Context, email, code string) error {
	log.Printf("[LOG NOTIFIER] email verification code generated for %s: %s", email, code)
	return nil
}

func (n *LogNotifier) SendEmailChangeVerification(_ context.Context, oldEmail, newEmail, code string) error {
	log.Printf("[LOG NOTIFIER] email change verification code generated (from %s to %s): %s", oldEmail, newEmail, code)
	return nil
}
