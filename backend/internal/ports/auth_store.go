package ports

import "context"

type AuthStore interface {
	StoreRefreshToken(ctx context.Context, userID, token string, ttlSeconds int64) error
	ValidateRefreshToken(ctx context.Context, userID, token string) (bool, error)
	RevokeRefreshToken(ctx context.Context, userID, token string) error
	RevokeAllRefreshTokens(ctx context.Context, userID string) error
	StorePasswordResetCode(ctx context.Context, email, code string, ttlSeconds int64) error
	ValidatePasswordResetCode(ctx context.Context, email, code string) (bool, error)
	RevokePasswordResetCode(ctx context.Context, email string) error
	StoreEmailVerificationCode(ctx context.Context, email, code string, ttlSeconds int64) error
	ValidateEmailVerificationCode(ctx context.Context, email, code string) (bool, error)
	RevokeEmailVerificationCode(ctx context.Context, email string) error
}
