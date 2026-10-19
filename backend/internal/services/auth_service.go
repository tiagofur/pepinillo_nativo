package services

import (
	"context"
	"crypto/rand"
	"encoding/json"
	"fmt"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"
	"golang.org/x/crypto/bcrypt"

	"pepinillo/backend/internal/adapters/middleware"
	"pepinillo/backend/internal/domain"
	"pepinillo/backend/internal/ports"
)

type AuthService struct {
	users             ports.UserRepository
	authStore         ports.AuthStore
	notifier          ports.Notifier
	behaviorLogger    ports.BehaviorLogger
	wsManager         ports.WebSocketManager
	jwtSecret         string
	jwtIssuer         string
	accessTTLSeconds  int64
	refreshTTLSeconds int64
	// oauthService is used for best-effort Apple token revocation during account
	// deletion (#196). May be nil in tests.
	oauthService *OAuthService
}

type AuthTokens struct {
	AccessToken  string `json:"accessToken"`
	RefreshToken string `json:"refreshToken"`
	ExpiresIn    int64  `json:"expiresIn"`
}

func NewAuthService(users ports.UserRepository, authStore ports.AuthStore, notifier ports.Notifier, behaviorLogger ports.BehaviorLogger, wsManager ports.WebSocketManager, jwtSecret, jwtIssuer string, accessTTLSeconds, refreshTTLSeconds int64) *AuthService {
	return &AuthService{
		users:             users,
		authStore:         authStore,
		notifier:          notifier,
		behaviorLogger:    behaviorLogger,
		wsManager:         wsManager,
		jwtSecret:         jwtSecret,
		jwtIssuer:         jwtIssuer,
		accessTTLSeconds:  accessTTLSeconds,
		refreshTTLSeconds: refreshTTLSeconds,
	}
}

// SetOAuthService wires the OAuthService so DeleteAccount can perform best-effort
// Apple token revocation (#196). Called after both services are constructed.
func (s *AuthService) SetOAuthService(oauth *OAuthService) {
	s.oauthService = oauth
}

func (s *AuthService) Register(ctx context.Context, email, name, password string) (*domain.User, *AuthTokens, error) {
	if !isValidEmail(email) {
		return nil, nil, ErrInvalidEmail
	}
	if !isStrongPassword(password) {
		return nil, nil, ErrWeakPassword
	}

	existing, err := s.users.GetByEmail(ctx, email)
	if err != nil {
		return nil, nil, err
	}
	if existing != nil {
		return nil, nil, ErrEmailAlreadyExists
	}

	hash, err := bcrypt.GenerateFromPassword([]byte(password), 12)
	if err != nil {
		return nil, nil, err
	}

	user := &domain.User{
		ID:               uuid.NewString(),
		Email:            email,
		Name:             name,
		PasswordHash:     strPtr(string(hash)),
		SubscriptionTier: "free",
	}

	if err := s.users.Create(ctx, user); err != nil {
		return nil, nil, err
	}

	tokens, err := s.generateTokens(user)
	if err != nil {
		return nil, nil, err
	}
	if err := s.authStore.StoreRefreshToken(ctx, user.ID, tokens.RefreshToken, s.refreshTTLSeconds); err != nil {
		return nil, nil, err
	}
	_ = s.behaviorLogger.LogEvent(ctx, user.ID, "user_registered", map[string]any{"email": user.Email})

	code, err := generateResetCode()
	if err != nil {
		return nil, nil, err
	}
	if err := s.authStore.StoreEmailVerificationCode(ctx, user.Email, code, 15*60); err != nil {
		return nil, nil, err
	}
	_ = s.notifier.SendEmailVerificationCode(ctx, user.Email, code)

	return user, tokens, nil
}

func (s *AuthService) Login(ctx context.Context, email, password string) (*domain.User, *AuthTokens, error) {
	if !isValidEmail(email) {
		return nil, nil, ErrInvalidEmail
	}

	user, err := s.users.GetByEmail(ctx, email)
	if err != nil {
		return nil, nil, err
	}
	if user == nil {
		return nil, nil, ErrInvalidCredentials
	}

	if user.PasswordHash == nil {
		return nil, nil, ErrInvalidCredentials
	}
	if err := bcrypt.CompareHashAndPassword([]byte(*user.PasswordHash), []byte(password)); err != nil {
		return nil, nil, ErrInvalidCredentials
	}

	tokens, err := s.generateTokens(user)
	if err != nil {
		return nil, nil, err
	}
	if err := s.authStore.StoreRefreshToken(ctx, user.ID, tokens.RefreshToken, s.refreshTTLSeconds); err != nil {
		return nil, nil, err
	}
	_ = s.behaviorLogger.LogEvent(ctx, user.ID, "user_logged_in", map[string]any{})

	return user, tokens, nil
}

func (s *AuthService) Refresh(ctx context.Context, refreshToken string) (*AuthTokens, error) {
	token, err := jwt.ParseWithClaims(refreshToken, &middleware.UserClaims{}, func(token *jwt.Token) (any, error) {
		return []byte(s.jwtSecret), nil
	})
	if err != nil || !token.Valid {
		return nil, ErrInvalidRefreshToken
	}
	claims, ok := token.Claims.(*middleware.UserClaims)
	if !ok || claims.TokenType != "refresh" || claims.UserID == "" {
		return nil, ErrInvalidRefreshToken
	}

	valid, err := s.authStore.ValidateRefreshToken(ctx, claims.UserID, refreshToken)
	if err != nil {
		return nil, err
	}
	if !valid {
		// The JWT signature is valid but the store no longer knows this token:
		// it was rotated out (or revoked). Replaying a rotated token is the
		// classic session-theft signal, so revoke the whole family — the
		// legitimate client re-authenticates, the thief loses everything.
		// (A merely stale client holding a pre-rotation copy pays one extra
		// login; that is the intended tradeoff.)
		_ = s.authStore.RevokeAllRefreshTokens(ctx, claims.UserID)
		return nil, ErrInvalidRefreshToken
	}

	user, err := s.users.GetByID(ctx, claims.UserID)
	if err != nil {
		return nil, err
	}
	if user == nil {
		return nil, ErrUserNotFound
	}

	if err := s.authStore.RevokeRefreshToken(ctx, claims.UserID, refreshToken); err != nil {
		return nil, err
	}

	tokens, err := s.generateTokens(user)
	if err != nil {
		return nil, err
	}
	if err := s.authStore.StoreRefreshToken(ctx, user.ID, tokens.RefreshToken, s.refreshTTLSeconds); err != nil {
		return nil, err
	}
	_ = s.behaviorLogger.LogEvent(ctx, user.ID, "token_refreshed", map[string]any{})

	return tokens, nil
}

func (s *AuthService) Logout(ctx context.Context, userID, refreshToken string) error {
	_ = s.behaviorLogger.LogEvent(ctx, userID, "user_logged_out", map[string]any{})
	if refreshToken == "" {
		return s.authStore.RevokeAllRefreshTokens(ctx, userID)
	}
	return s.authStore.RevokeRefreshToken(ctx, userID, refreshToken)
}

func (s *AuthService) ForgotPassword(ctx context.Context, email string) error {
	if !isValidEmail(email) {
		return ErrInvalidEmail
	}
	user, err := s.users.GetByEmail(ctx, email)
	if err != nil {
		return err
	}
	if user == nil {
		return nil
	}
	code, err := generateResetCode()
	if err != nil {
		return err
	}
	if err := s.authStore.StorePasswordResetCode(ctx, email, code, 15*60); err != nil {
		return err
	}
	return s.notifier.SendPasswordResetCode(ctx, email, code)
}

func (s *AuthService) ResetPassword(ctx context.Context, email, code, newPassword string) error {
	if !isValidEmail(email) {
		return ErrInvalidEmail
	}
	if !isStrongPassword(newPassword) {
		return ErrWeakPassword
	}
	valid, err := s.authStore.ValidatePasswordResetCode(ctx, email, code)
	if err != nil {
		return err
	}
	if !valid {
		return ErrInvalidResetCode
	}
	user, err := s.users.GetByEmail(ctx, email)
	if err != nil {
		return err
	}
	if user == nil {
		return ErrUserNotFound
	}
	hash, err := bcrypt.GenerateFromPassword([]byte(newPassword), 12)
	if err != nil {
		return err
	}
	user.PasswordHash = strPtr(string(hash))
	if err := s.users.Update(ctx, user); err != nil {
		return err
	}
	if err := s.authStore.RevokePasswordResetCode(ctx, email); err != nil {
		return err
	}
	_ = s.behaviorLogger.LogEvent(ctx, user.ID, "password_reset_completed", map[string]any{})
	return s.authStore.RevokeAllRefreshTokens(ctx, user.ID)
}

func (s *AuthService) UpdatePassword(ctx context.Context, userID, newPassword string) error {
	if !isStrongPassword(newPassword) {
		return ErrWeakPassword
	}

	user, err := s.users.GetByID(ctx, userID)
	if err != nil {
		return err
	}
	if user == nil {
		return ErrUserNotFound
	}

	hash, err := bcrypt.GenerateFromPassword([]byte(newPassword), 12)
	if err != nil {
		return err
	}

	user.PasswordHash = strPtr(string(hash))
	if err := s.users.Update(ctx, user); err != nil {
		return err
	}
	return s.authStore.RevokeAllRefreshTokens(ctx, userID)
}

func (s *AuthService) ChangePassword(ctx context.Context, userID, currentPassword, newPassword string) error {
	if !isStrongPassword(newPassword) {
		return ErrWeakPassword
	}
	user, err := s.users.GetByID(ctx, userID)
	if err != nil {
		return err
	}
	if user == nil {
		return ErrUserNotFound
	}
	if user.PasswordHash == nil {
		return ErrInvalidCredentials
	}
	if err := bcrypt.CompareHashAndPassword([]byte(*user.PasswordHash), []byte(currentPassword)); err != nil {
		return ErrInvalidCredentials
	}
	hash, err := bcrypt.GenerateFromPassword([]byte(newPassword), 12)
	if err != nil {
		return err
	}
	user.PasswordHash = strPtr(string(hash))
	if err := s.users.Update(ctx, user); err != nil {
		return err
	}
	_ = s.behaviorLogger.LogEvent(ctx, userID, "password_changed", map[string]any{})
	return s.authStore.RevokeAllRefreshTokens(ctx, userID)
}

// DeleteAccount permanently removes the user, revokes all refresh tokens, and
// (for Sign in with Apple users) asks Apple to revoke its tokens best-effort.
//
// The appleAuthorizationCode is captured client-side at SIWA time and carries a
// short lifetime, so revocation may legitimately fail — that is logged and does
// NOT abort the deletion (#196).
func (s *AuthService) DeleteAccount(ctx context.Context, userID string, appleAuthorizationCode *string) error {
	_ = s.behaviorLogger.LogEvent(ctx, userID, "account_deleted", map[string]any{})

	// Best-effort Apple token revocation for SIWA users (#196). Never blocks
	// the deletion — see RevokeAppleToken for the rationale.
	if s.oauthService != nil && appleAuthorizationCode != nil && *appleAuthorizationCode != "" {
		// Only attempt revocation if the user actually has an Apple ID linked.
		if user, err := s.users.GetByID(ctx, userID); err == nil && user != nil && user.AppleID != nil && *user.AppleID != "" {
			_ = s.oauthService.RevokeAppleToken(ctx, *appleAuthorizationCode)
		}
	}

	if err := s.authStore.RevokeAllRefreshTokens(ctx, userID); err != nil {
		return err
	}
	return s.users.Delete(ctx, userID)
}

func (s *AuthService) generateTokens(user *domain.User) (*AuthTokens, error) {
	now := time.Now().UTC()
	accessExpiry := now.Add(time.Duration(s.accessTTLSeconds) * time.Second)
	refreshExpiry := now.Add(time.Duration(s.refreshTTLSeconds) * time.Second)

	accessClaims := middleware.UserClaims{
		UserID:        user.ID,
		Email:         user.Email,
		Tier:          user.SubscriptionTier,
		TokenType:     "access",
		EmailVerified: user.EmailVerified,
		RegisteredClaims: jwt.RegisteredClaims{
			ID:        uuid.NewString(),
			Issuer:    s.jwtIssuer,
			Subject:   user.ID,
			IssuedAt:  jwt.NewNumericDate(now),
			ExpiresAt: jwt.NewNumericDate(accessExpiry),
		},
	}
	accessToken := jwt.NewWithClaims(jwt.SigningMethodHS256, accessClaims)
	accessTokenString, err := accessToken.SignedString([]byte(s.jwtSecret))
	if err != nil {
		return nil, err
	}

	refreshClaims := middleware.UserClaims{
		UserID:        user.ID,
		Email:         user.Email,
		Tier:          user.SubscriptionTier,
		TokenType:     "refresh",
		EmailVerified: user.EmailVerified,
		RegisteredClaims: jwt.RegisteredClaims{
			ID:        uuid.NewString(),
			Issuer:    s.jwtIssuer,
			Subject:   user.ID,
			IssuedAt:  jwt.NewNumericDate(now),
			ExpiresAt: jwt.NewNumericDate(refreshExpiry),
		},
	}
	refreshToken := jwt.NewWithClaims(jwt.SigningMethodHS256, refreshClaims)
	refreshTokenString, err := refreshToken.SignedString([]byte(s.jwtSecret))
	if err != nil {
		return nil, err
	}

	return &AuthTokens{
		AccessToken:  accessTokenString,
		RefreshToken: refreshTokenString,
		ExpiresIn:    s.accessTTLSeconds,
	}, nil
}

func generateResetCode() (string, error) {
	const digits = "0123456789"
	result := make([]byte, 6)
	for i := range result {
		for {
			b := make([]byte, 1)
			if _, err := rand.Read(b); err != nil {
				return "", err
			}
			// Reject values >= 250 to avoid modulo bias (250 = 25*10, evenly divisible)
			if b[0] < 250 {
				result[i] = digits[b[0]%10]
				break
			}
		}
	}
	return string(result), nil
}

func (s *AuthService) VerifyEmail(ctx context.Context, email, code string) (*domain.User, *AuthTokens, error) {
	if !isValidEmail(email) {
		return nil, nil, ErrInvalidEmail
	}

	valid, err := s.authStore.ValidateEmailVerificationCode(ctx, email, code)
	if err != nil {
		return nil, nil, err
	}
	if !valid {
		return nil, nil, ErrInvalidVerificationCode
	}

	user, err := s.users.GetByEmail(ctx, email)
	if err != nil {
		return nil, nil, err
	}
	if user == nil {
		return nil, nil, ErrUserNotFound
	}

	if user.EmailVerified {
		return nil, nil, ErrEmailAlreadyVerified
	}

	if err := s.users.MarkEmailVerified(ctx, user.ID); err != nil {
		return nil, nil, err
	}
	if err := s.authStore.RevokeEmailVerificationCode(ctx, email); err != nil {
		return nil, nil, err
	}
	_ = s.behaviorLogger.LogEvent(ctx, user.ID, "email_verified", map[string]any{"email": user.Email})

	user.EmailVerified = true
	tokens, err := s.generateTokens(user)
	if err != nil {
		return nil, nil, err
	}
	return user, tokens, nil
}

func (s *AuthService) ResendVerificationCode(ctx context.Context, email string) error {
	if !isValidEmail(email) {
		return ErrInvalidEmail
	}

	user, err := s.users.GetByEmail(ctx, email)
	if err != nil {
		return err
	}
	if user == nil {
		return ErrUserNotFound
	}

	if user.EmailVerified {
		return ErrEmailAlreadyVerified
	}

	_ = s.authStore.RevokeEmailVerificationCode(ctx, email)

	code, err := generateResetCode()
	if err != nil {
		return err
	}
	if err := s.authStore.StoreEmailVerificationCode(ctx, email, code, 15*60); err != nil {
		return err
	}
	return s.notifier.SendEmailVerificationCode(ctx, email, code)
}

func (s *AuthService) RequestEmailChange(ctx context.Context, userID, newEmail string) (*domain.User, error) {
	if !isValidEmail(newEmail) {
		return nil, ErrInvalidEmail
	}

	user, err := s.users.GetByID(ctx, userID)
	if err != nil {
		return nil, err
	}
	if user == nil {
		return nil, ErrUserNotFound
	}

	if user.Email == newEmail {
		return nil, ErrSameEmail
	}

	existing, err := s.users.GetByEmail(ctx, newEmail)
	if err != nil {
		return nil, err
	}
	if existing != nil {
		return nil, ErrEmailAlreadyExists
	}

	code, err := generateResetCode()
	if err != nil {
		return nil, err
	}
	if err := s.authStore.StoreEmailVerificationCode(ctx, newEmail, code, 15*60); err != nil {
		return nil, err
	}

	if err := s.users.UpdateEmailPending(ctx, userID, newEmail); err != nil {
		return nil, err
	}

	if err := s.notifier.SendEmailChangeVerification(ctx, user.Email, newEmail, code); err != nil {
		return nil, err
	}

	updated, err := s.users.GetByID(ctx, userID)
	if err != nil {
		return nil, err
	}
	_ = s.behaviorLogger.LogEvent(ctx, userID, "email_change_requested", map[string]any{"old_email": user.Email, "new_email": newEmail})

	return updated, nil
}

func (s *AuthService) ConfirmEmailChange(ctx context.Context, userID, code string) (*domain.User, error) {
	user, err := s.users.GetByID(ctx, userID)
	if err != nil {
		return nil, err
	}
	if user == nil {
		return nil, ErrUserNotFound
	}

	if user.PendingEmail == nil {
		return nil, ErrEmailChangeNotPending
	}

	valid, err := s.authStore.ValidateEmailVerificationCode(ctx, *user.PendingEmail, code)
	if err != nil {
		return nil, err
	}
	if !valid {
		return nil, ErrInvalidVerificationCode
	}

	newEmail := *user.PendingEmail
	if err := s.users.ConfirmEmailChange(ctx, userID, newEmail); err != nil {
		return nil, err
	}
	if err := s.authStore.RevokeEmailVerificationCode(ctx, newEmail); err != nil {
		return nil, err
	}

	updated, err := s.users.GetByID(ctx, userID)
	if err != nil {
		return nil, err
	}
	_ = s.behaviorLogger.LogEvent(ctx, userID, "email_changed", map[string]any{"old_email": user.Email, "new_email": newEmail})

	s.sendUserUpdateNotification(userID, updated)

	return updated, nil
}

func (s *AuthService) CancelEmailChange(ctx context.Context, userID string) error {
	user, err := s.users.GetByID(ctx, userID)
	if err != nil {
		return err
	}
	if user == nil {
		return ErrUserNotFound
	}

	if user.PendingEmail == nil {
		return ErrEmailChangeNotPending
	}

	if err := s.authStore.RevokeEmailVerificationCode(ctx, *user.PendingEmail); err != nil {
		return err
	}

	if err := s.users.RollbackEmailChange(ctx, userID); err != nil {
		return err
	}
	_ = s.behaviorLogger.LogEvent(ctx, userID, "email_change_cancelled", map[string]any{"email": user.Email})

	return nil
}

func (s *AuthService) sendUserUpdateNotification(userID string, user *domain.User) {
	if s.wsManager == nil {
		return
	}

	message := map[string]any{
		"type": "user_updated",
		"data": user,
	}

	msgBytes, err := json.Marshal(message)
	if err != nil {
		fmt.Printf("failed to marshal websocket message: %v", err)
		return
	}

	_ = s.wsManager.SendToUser(userID, msgBytes)
}

func strPtr(s string) *string { return &s }
