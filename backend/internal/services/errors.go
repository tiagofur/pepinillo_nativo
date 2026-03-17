package services

import "errors"

var (
	ErrEmailAlreadyExists = errors.New("email_already_exists")
	ErrInvalidCredentials = errors.New("invalid_credentials")
	ErrUserNotFound       = errors.New("user_not_found")
	ErrTaskNotFound       = errors.New("task_not_found")
	ErrInvalidEmail       = errors.New("invalid_email")
	ErrWeakPassword       = errors.New("weak_password")
	ErrInvalidRefreshToken = errors.New("invalid_refresh_token")
	ErrInvalidResetCode   = errors.New("invalid_reset_code")
	ErrInvalidVerificationCode = errors.New("verification_code_invalid")
	ErrEmailAlreadyVerified = errors.New("email_already_verified")
	ErrEmailChangeNotPending = errors.New("email_change_not_pending")
	ErrSameEmail = errors.New("same_email")
)
