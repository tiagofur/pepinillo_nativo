package services

import "errors"

var (
	ErrEmailAlreadyExists          = errors.New("email_already_exists")
	ErrInvalidCredentials          = errors.New("invalid_credentials")
	ErrUserNotFound                = errors.New("user_not_found")
	ErrTaskNotFound                = errors.New("task_not_found")
	ErrInvalidEmail                = errors.New("invalid_email")
	ErrWeakPassword                = errors.New("weak_password")
	ErrInvalidRefreshToken         = errors.New("invalid_refresh_token")
	ErrInvalidResetCode            = errors.New("invalid_reset_code")
	ErrInvalidVerificationCode     = errors.New("verification_code_invalid")
	ErrEmailAlreadyVerified        = errors.New("email_already_verified")
	ErrEmailChangeNotPending       = errors.New("email_change_not_pending")
	ErrSameEmail                   = errors.New("same_email")
	ErrAccountAlreadyLinked        = errors.New("account_already_linked")
	ErrCannotUnlinkLastAuth        = errors.New("cannot_unlink_last_auth")
	ErrAccountLinkedToOtherUser    = errors.New("account_linked_to_other_user")
	ErrOAuthProviderAlreadyLinked  = errors.New("oauth_provider_already_linked")
	ErrOAuthEmailMissing           = errors.New("oauth_email_missing")
	ErrGoogleAudienceNotConfigured = errors.New("google_oauth_audience_not_configured")
	ErrInvalidOAuthToken           = errors.New("invalid_oauth_token")
	ErrInvalidPreferenceKey        = errors.New("invalid_preference_key")
	ErrTierInsufficientForCloudAI  = errors.New("tier_insufficient_for_cloud_ai")
	ErrInsufficientAICredits       = errors.New("insufficient_ai_credits")
)
