package ports

import "context"

type Notifier interface {
	SendPasswordResetCode(ctx context.Context, email, code string) error
	SendEmailVerificationCode(ctx context.Context, email, code string) error
	SendEmailChangeVerification(ctx context.Context, oldEmail, newEmail, code string) error
}
