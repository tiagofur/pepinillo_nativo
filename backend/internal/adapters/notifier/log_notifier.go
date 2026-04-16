package notifier

import (
	"context"
	"log/slog"
)

type LogNotifier struct{}

func NewLogNotifier() *LogNotifier {
	return &LogNotifier{}
}

func (n *LogNotifier) SendPasswordResetCode(_ context.Context, email, code string) error {
	slog.Info("log notifier: password reset code generated",
		"notifier", "log",
		"kind", "password_reset",
		"email", email,
		"code", code,
	)
	return nil
}

func (n *LogNotifier) SendEmailVerificationCode(_ context.Context, email, code string) error {
	slog.Info("log notifier: email verification code generated",
		"notifier", "log",
		"kind", "email_verification",
		"email", email,
		"code", code,
	)
	return nil
}

func (n *LogNotifier) SendEmailChangeVerification(_ context.Context, oldEmail, newEmail, code string) error {
	slog.Info("log notifier: email change verification code generated",
		"notifier", "log",
		"kind", "email_change",
		"oldEmail", oldEmail,
		"newEmail", newEmail,
		"code", code,
	)
	return nil
}
