package services

import (
	"context"
	"crypto/ecdsa"
	"crypto/sha256"
	"crypto/x509"
	"encoding/hex"
	"encoding/json"
	"encoding/pem"
	"errors"
	"fmt"
	"io"
	"log/slog"
	"net/http"
	"net/url"
	"strconv"
	"strings"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"
	"github.com/lestrrat-go/jwx/v2/jwk"
	jwxjwt "github.com/lestrrat-go/jwx/v2/jwt"

	"pepinillo/backend/internal/adapters/middleware"
	"pepinillo/backend/internal/domain"
	"pepinillo/backend/internal/ports"
)

type OAuthService struct {
	users           ports.UserRepository
	authStore       ports.AuthStore
	jwtSecret       string
	jwtIssuer       string
	accessTTL       int64
	refreshTTL      int64
	googleClient    *http.Client
	googleClientIDs []string
	appleBundleID   string
	// Apple Sign in with Apple server-to-server token revocation (#196).
	// All optional — when any is empty, RevokeAppleToken is a logged no-op so
	// account deletion still succeeds without Apple revocation configured.
	appleTeamID    string
	appleKeyID     string
	applePrivateKey string
	appleClient    *http.Client
}

const appleTokenMaxAge = 10 * time.Minute

type googleTokenInfo struct {
	Aud           string `json:"aud"`
	Sub           string `json:"sub"`
	Azp           string `json:"azp"`
	Email         string `json:"email"`
	EmailVerified string `json:"email_verified"`
	Name          string `json:"name"`
	Picture       string `json:"picture"`
	Exp           string `json:"exp"`
}

type appleTokenInfo struct {
	Sub           string          `json:"sub"`
	Email         string          `json:"email"`
	EmailVerified json.RawMessage `json:"email_verified"`
	Name          *appleName      `json:"name,omitempty"`
}

type appleName struct {
	FirstName string `json:"firstName,omitempty"`
	LastName  string `json:"lastName,omitempty"`
}

func NewOAuthService(
	users ports.UserRepository,
	authStore ports.AuthStore,
	jwtSecret, jwtIssuer string,
	accessTTL, refreshTTL int64,
	googleClientIDs []string,
	appleBundleID string,
	appleTeamID, appleKeyID, applePrivateKey string,
) *OAuthService {
	return &OAuthService{
		users:           users,
		authStore:       authStore,
		jwtSecret:       jwtSecret,
		jwtIssuer:       jwtIssuer,
		accessTTL:       accessTTL,
		refreshTTL:      refreshTTL,
		googleClient:    &http.Client{Timeout: 10 * time.Second},
		googleClientIDs: googleClientIDs,
		appleBundleID:   appleBundleID,
		appleTeamID:     appleTeamID,
		appleKeyID:      appleKeyID,
		applePrivateKey: applePrivateKey,
		appleClient:     &http.Client{Timeout: 10 * time.Second},
	}
}

func (s *OAuthService) LoginWithGoogle(ctx context.Context, idToken string) (*domain.User, *AuthTokens, error) {
	tokenInfo, err := s.verifyGoogleToken(ctx, idToken)
	if err != nil {
		return nil, nil, fmt.Errorf("%w: %v", ErrInvalidOAuthToken, err)
	}

	if strings.TrimSpace(tokenInfo.Email) == "" {
		return nil, nil, ErrOAuthEmailMissing
	}

	user, err := s.users.GetByGoogleID(ctx, tokenInfo.Sub)
	if err != nil {
		slog.Error("LoginWithGoogle: failed to get user by google id", "googleId", tokenInfo.Sub, "error", err)
		return nil, nil, err
	}

	if user != nil {
		tokens, err := s.generateTokens(user)
		if err != nil {
			slog.Error("LoginWithGoogle: failed to generate tokens", "userId", user.ID, "error", err)
			return nil, nil, err
		}
		if err := s.authStore.StoreRefreshToken(ctx, user.ID, tokens.RefreshToken, s.refreshTTL); err != nil {
			slog.Error("LoginWithGoogle: failed to store refresh token", "userId", user.ID, "error", err)
			return nil, nil, err
		}
		return user, tokens, nil
	}

	existing, err := s.users.GetByEmail(ctx, tokenInfo.Email)
	if err != nil {
		slog.Error("LoginWithGoogle: failed to get user by email", "email", tokenInfo.Email, "error", err)
		return nil, nil, err
	}

	if existing != nil {
		if existing.GoogleID != nil {
			return nil, nil, ErrAccountAlreadyLinked
		}
		if err := s.users.LinkGoogleAccount(ctx, existing.ID, tokenInfo.Sub, tokenInfo.Email, tokenInfo.Name, tokenInfo.Picture); err != nil {
			slog.Error("LoginWithGoogle: failed to link google account", "userId", existing.ID, "error", err)
			return nil, nil, err
		}
		tokens, err := s.generateTokens(existing)
		if err != nil {
			slog.Error("LoginWithGoogle: failed to generate tokens for existing user", "userId", existing.ID, "error", err)
			return nil, nil, err
		}
		if err := s.authStore.StoreRefreshToken(ctx, existing.ID, tokens.RefreshToken, s.refreshTTL); err != nil {
			slog.Error("LoginWithGoogle: failed to store refresh token for existing user", "userId", existing.ID, "error", err)
			return nil, nil, err
		}
		return existing, tokens, nil
	}

	emailVerified, _ := strconv.ParseBool(tokenInfo.EmailVerified)
	var emailVerifiedAt *time.Time
	if emailVerified {
		now := time.Now().UTC()
		emailVerifiedAt = &now
	}
	user = &domain.User{
		ID:               uuid.NewString(),
		Email:            tokenInfo.Email,
		Name:             tokenInfo.Name,
		ImageURL:         &tokenInfo.Picture,
		EmailVerified:    emailVerified,
		EmailVerifiedAt:  emailVerifiedAt,
		SubscriptionTier: "free",
		GoogleID:         &tokenInfo.Sub,
		GoogleEmail:      &tokenInfo.Email,
		GoogleName:       &tokenInfo.Name,
		GooglePicture:    &tokenInfo.Picture,
	}

	if err := s.users.Create(ctx, user); err != nil {
		slog.Error("LoginWithGoogle: failed to create new user", "email", tokenInfo.Email, "error", err)
		return nil, nil, err
	}

	tokens, err := s.generateTokens(user)
	if err != nil {
		slog.Error("LoginWithGoogle: failed to generate tokens for new user", "userId", user.ID, "error", err)
		return nil, nil, err
	}
	if err := s.authStore.StoreRefreshToken(ctx, user.ID, tokens.RefreshToken, s.refreshTTL); err != nil {
		slog.Error("LoginWithGoogle: failed to store refresh token for new user", "userId", user.ID, "error", err)
		return nil, nil, err
	}

	return user, tokens, nil
}

func (s *OAuthService) LoginWithApple(ctx context.Context, idToken, nonce string) (*domain.User, *AuthTokens, error) {
	tokenInfo, err := s.verifyAppleToken(ctx, idToken, nonce)
	if err != nil {
		return nil, nil, fmt.Errorf("%w: %v", ErrInvalidOAuthToken, err)
	}

	user, err := s.users.GetByAppleID(ctx, tokenInfo.Sub)
	if err != nil {
		return nil, nil, err
	}

	if user != nil {
		tokens, err := s.generateTokens(user)
		if err != nil {
			return nil, nil, err
		}
		if err := s.authStore.StoreRefreshToken(ctx, user.ID, tokens.RefreshToken, s.refreshTTL); err != nil {
			return nil, nil, err
		}
		return user, tokens, nil
	}

	if strings.TrimSpace(tokenInfo.Email) == "" {
		return nil, nil, ErrOAuthEmailMissing
	}

	existing, err := s.users.GetByEmail(ctx, tokenInfo.Email)
	if err != nil {
		return nil, nil, err
	}

	if existing != nil {
		if existing.AppleID != nil {
			return nil, nil, ErrAccountAlreadyLinked
		}
		var name string
		if tokenInfo.Name != nil {
			name = fmt.Sprintf("%s %s", tokenInfo.Name.FirstName, tokenInfo.Name.LastName)
		}
		if err := s.users.LinkAppleAccount(ctx, existing.ID, tokenInfo.Sub, tokenInfo.Email, name); err != nil {
			return nil, nil, err
		}
		tokens, err := s.generateTokens(existing)
		if err != nil {
			return nil, nil, err
		}
		if err := s.authStore.StoreRefreshToken(ctx, existing.ID, tokens.RefreshToken, s.refreshTTL); err != nil {
			return nil, nil, err
		}
		return existing, tokens, nil
	}

	var name string
	if tokenInfo.Name != nil {
		name = fmt.Sprintf("%s %s", tokenInfo.Name.FirstName, tokenInfo.Name.LastName)
	}
	emailVerified := parseAppleEmailVerified(tokenInfo.EmailVerified)
	var emailVerifiedAt *time.Time
	if emailVerified {
		now := time.Now().UTC()
		emailVerifiedAt = &now
	}

	user = &domain.User{
		ID:               uuid.NewString(),
		Email:            tokenInfo.Email,
		Name:             name,
		EmailVerified:    emailVerified,
		EmailVerifiedAt:  emailVerifiedAt,
		SubscriptionTier: "free",
		AppleID:          &tokenInfo.Sub,
		AppleEmail:       &tokenInfo.Email,
		AppleName:        &name,
	}

	if err := s.users.Create(ctx, user); err != nil {
		return nil, nil, err
	}

	tokens, err := s.generateTokens(user)
	if err != nil {
		return nil, nil, err
	}
	if err := s.authStore.StoreRefreshToken(ctx, user.ID, tokens.RefreshToken, s.refreshTTL); err != nil {
		return nil, nil, err
	}

	return user, tokens, nil
}

func (s *OAuthService) LinkGoogleAccount(ctx context.Context, userID, idToken string) (*domain.User, error) {
	tokenInfo, err := s.verifyGoogleToken(ctx, idToken)
	if err != nil {
		return nil, fmt.Errorf("%w: %v", ErrInvalidOAuthToken, err)
	}

	user, err := s.users.GetByID(ctx, userID)
	if err != nil {
		return nil, err
	}
	if user == nil {
		return nil, ErrUserNotFound
	}

	if user.GoogleID != nil {
		return nil, ErrOAuthProviderAlreadyLinked
	}

	existing, err := s.users.GetByGoogleID(ctx, tokenInfo.Sub)
	if err != nil {
		return nil, err
	}
	if existing != nil && existing.ID != userID {
		return nil, ErrAccountLinkedToOtherUser
	}

	if err := s.users.LinkGoogleAccount(ctx, userID, tokenInfo.Sub, tokenInfo.Email, tokenInfo.Name, tokenInfo.Picture); err != nil {
		return nil, err
	}

	return s.users.GetByID(ctx, userID)
}

func (s *OAuthService) UnlinkGoogleAccount(ctx context.Context, userID string) error {
	user, err := s.users.GetByID(ctx, userID)
	if err != nil {
		return err
	}
	if user == nil {
		return ErrUserNotFound
	}

	if user.GoogleID == nil {
		return nil
	}

	hasPassword := user.PasswordHash != nil && *user.PasswordHash != ""
	hasApple := user.AppleID != nil

	if !hasPassword && !hasApple {
		return ErrCannotUnlinkLastAuth
	}

	return s.users.UnlinkGoogleAccount(ctx, userID)
}

func (s *OAuthService) LinkAppleAccount(ctx context.Context, userID, idToken, nonce string) (*domain.User, error) {
	tokenInfo, err := s.verifyAppleToken(ctx, idToken, nonce)
	if err != nil {
		return nil, fmt.Errorf("%w: %v", ErrInvalidOAuthToken, err)
	}

	user, err := s.users.GetByID(ctx, userID)
	if err != nil {
		return nil, err
	}
	if user == nil {
		return nil, ErrUserNotFound
	}

	if user.AppleID != nil {
		return nil, ErrOAuthProviderAlreadyLinked
	}

	existing, err := s.users.GetByAppleID(ctx, tokenInfo.Sub)
	if err != nil {
		return nil, err
	}
	if existing != nil && existing.ID != userID {
		return nil, ErrAccountLinkedToOtherUser
	}

	var name string
	if tokenInfo.Name != nil {
		name = fmt.Sprintf("%s %s", tokenInfo.Name.FirstName, tokenInfo.Name.LastName)
	}

	if err := s.users.LinkAppleAccount(ctx, userID, tokenInfo.Sub, tokenInfo.Email, name); err != nil {
		return nil, err
	}

	return s.users.GetByID(ctx, userID)
}

func (s *OAuthService) UnlinkAppleAccount(ctx context.Context, userID string) error {
	user, err := s.users.GetByID(ctx, userID)
	if err != nil {
		return err
	}
	if user == nil {
		return ErrUserNotFound
	}

	if user.AppleID == nil {
		return nil
	}

	hasPassword := user.PasswordHash != nil && *user.PasswordHash != ""
	hasGoogle := user.GoogleID != nil

	if !hasPassword && !hasGoogle {
		return ErrCannotUnlinkLastAuth
	}

	return s.users.UnlinkAppleAccount(ctx, userID)
}

func (s *OAuthService) GetLinkedProviders(ctx context.Context, userID string) (*domain.LinkedProviders, error) {
	user, err := s.users.GetByID(ctx, userID)
	if err != nil {
		return nil, err
	}
	if user == nil {
		return nil, ErrUserNotFound
	}

	providers := &domain.LinkedProviders{
		HasPassword: user.PasswordHash != nil && *user.PasswordHash != "",
	}

	if user.GoogleID != nil {
		providers.Google = &domain.OAuthProvider{
			ID:      *user.GoogleID,
			Email:   *user.GoogleEmail,
			Name:    *user.GoogleName,
			Picture: *user.GooglePicture,
		}
	}

	if user.AppleID != nil {
		providers.Apple = &domain.OAuthProvider{
			ID:    *user.AppleID,
			Email: *user.AppleEmail,
			Name:  *user.AppleName,
		}
	}

	return providers, nil
}

func (s *OAuthService) verifyGoogleToken(ctx context.Context, idToken string) (*googleTokenInfo, error) {
	if len(s.googleClientIDs) == 0 {
		return nil, ErrGoogleAudienceNotConfigured
	}

	resp, err := s.googleClient.Get("https://oauth2.googleapis.com/tokeninfo?id_token=" + idToken)
	if err != nil {
		slog.Error("verifyGoogleToken: failed to get token info from google", "error", err)
		return nil, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		slog.Warn("verifyGoogleToken: google returned non-200 status", "status", resp.Status)
		return nil, fmt.Errorf("google token verification failed: %s", resp.Status)
	}

	var tokenInfo googleTokenInfo
	if err := json.NewDecoder(resp.Body).Decode(&tokenInfo); err != nil {
		slog.Error("verifyGoogleToken: failed to decode token info response", "error", err)
		return nil, err
	}

	if !s.isValidGoogleAudience(tokenInfo.Aud) {
		slog.Warn("verifyGoogleToken: invalid audience", "aud", tokenInfo.Aud)
		return nil, errors.New("invalid google token audience")
	}

	expInt, err := strconv.ParseInt(tokenInfo.Exp, 10, 64)
	if err != nil {
		slog.Warn("verifyGoogleToken: failed to parse exp", "exp", tokenInfo.Exp, "error", err)
		return nil, fmt.Errorf("invalid token expiration: %w", err)
	}
	now := time.Now().Unix()
	if expInt < now {
		slog.Warn("verifyGoogleToken: token expired", "expiresAt", expInt, "now", now)
		return nil, errors.New("google token expired")
	}

	return &tokenInfo, nil
}

func (s *OAuthService) isValidGoogleAudience(aud string) bool {
	for _, id := range s.googleClientIDs {
		if id == aud {
			return true
		}
	}
	return false
}

func (s *OAuthService) verifyAppleToken(ctx context.Context, idToken, nonce string) (*appleTokenInfo, error) {
	appleKeysURL := "https://appleid.apple.com/auth/keys"

	appleKeys, err := s.fetchAppleKeysWithRetry(ctx, appleKeysURL)
	if err != nil {
		return nil, err
	}

	parsed, err := jwxjwt.ParseString(idToken, jwxjwt.WithKeySet(appleKeys))
	if err != nil {
		return nil, fmt.Errorf("failed to parse apple token: %w", err)
	}

	var tokenInfo appleTokenInfo
	tokenBytes, err := json.Marshal(parsed)
	if err != nil {
		return nil, fmt.Errorf("failed to marshal apple token: %w", err)
	}
	if err := json.Unmarshal(tokenBytes, &tokenInfo); err != nil {
		return nil, fmt.Errorf("failed to decode apple token: %w", err)
	}

	issuer := parsed.Issuer()
	if issuer != "https://appleid.apple.com" {
		return nil, errors.New("invalid apple token issuer")
	}

	aud := parsed.Audience()
	if len(aud) == 0 {
		return nil, errors.New("invalid apple token audience")
	}
	if s.appleBundleID != "" {
		validAud := false
		for _, a := range aud {
			if a == s.appleBundleID {
				validAud = true
				break
			}
		}
		if !validAud {
			return nil, errors.New("invalid apple token audience")
		}
	}

	exp := parsed.Expiration()
	now := time.Now()
	if exp.IsZero() || exp.Before(now) {
		return nil, errors.New("apple token expired")
	}

	iat := parsed.IssuedAt()
	if err := validateAppleIssuedAt(iat, now); err != nil {
		return nil, err
	}

	privateClaims := parsed.PrivateClaims()
	tokenNonce, ok := privateClaims["nonce"].(string)
	if !ok {
		tokenNonce = ""
	}
	if err := validateAppleNonce(tokenNonce, nonce); err != nil {
		return nil, err
	}

	return &tokenInfo, nil
}

func (s *OAuthService) fetchAppleKeysWithRetry(ctx context.Context, appleKeysURL string) (jwk.Set, error) {
	var lastErr error
	delays := []time.Duration{0, time.Second, 2 * time.Second}

	for _, delay := range delays {
		if delay > 0 {
			select {
			case <-ctx.Done():
				return nil, ctx.Err()
			case <-time.After(delay):
			}
		}

		fetch, err := http.NewRequestWithContext(ctx, http.MethodGet, appleKeysURL, nil)
		if err != nil {
			return nil, fmt.Errorf("failed to create request for apple keys: %w", err)
		}

		resp, err := s.googleClient.Do(fetch)
		if err != nil {
			lastErr = fmt.Errorf("failed to fetch apple keys: %w", err)
			continue
		}

		body, readErr := io.ReadAll(resp.Body)
		resp.Body.Close()
		if readErr != nil {
			lastErr = fmt.Errorf("failed to read apple keys response: %w", readErr)
			continue
		}

		if resp.StatusCode != http.StatusOK {
			lastErr = fmt.Errorf("failed to fetch apple keys: %s", resp.Status)
			continue
		}

		appleKeys, parseErr := jwk.Parse(body)
		if parseErr != nil {
			lastErr = fmt.Errorf("failed to parse apple keys: %w", parseErr)
			continue
		}

		return appleKeys, nil
	}

	if lastErr != nil {
		return nil, lastErr
	}
	return nil, errors.New("failed to fetch apple keys")
}

func validateAppleNonce(tokenNonce, providedNonce string) error {
	// Fail closed: a missing raw nonce means replay protection is OFF, which
	// is never acceptable. Both Apple login and link handlers reject an empty
	// nonce at the boundary with a 400; this guard protects any future caller
	// that forgets to enforce it.
	if providedNonce == "" {
		return fmt.Errorf("%w: nonce required", ErrInvalidOAuthToken)
	}
	if tokenNonce == "" {
		return errors.New("apple token missing nonce claim")
	}
	h := sha256.Sum256([]byte(providedNonce))
	expected := hex.EncodeToString(h[:])
	if tokenNonce != expected {
		return errors.New("apple token nonce mismatch")
	}
	return nil
}

func validateAppleIssuedAt(iat, now time.Time) error {
	if iat.IsZero() {
		return errors.New("apple token missing iat")
	}
	if iat.After(now.Add(30 * time.Second)) {
		return errors.New("apple token issued in the future")
	}
	if now.Sub(iat) > appleTokenMaxAge {
		return errors.New("apple token too old")
	}
	return nil
}

// parseAppleEmailVerified decodes the apple "email_verified" claim defensively.
// Apple has historically sent this as a STRING ("true"/"false") even though
// many JWT libraries expect a bool. Accept both (and missing) without failing.
func parseAppleEmailVerified(raw json.RawMessage) bool {
	s := strings.TrimSpace(string(raw))
	if s == "" {
		return false
	}
	var b bool
	if err := json.Unmarshal(raw, &b); err == nil {
		return b
	}
	var str string
	if err := json.Unmarshal(raw, &str); err == nil {
		return strings.EqualFold(str, "true")
	}
	return false
}

func (s *OAuthService) generateTokens(user *domain.User) (*AuthTokens, error) {
	now := time.Now().UTC()
	accessExpiry := now.Add(time.Duration(s.accessTTL) * time.Second)
	refreshExpiry := now.Add(time.Duration(s.refreshTTL) * time.Second)

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
		ExpiresIn:    s.accessTTL,
	}, nil
}

// MARK: - Sign in with Apple token revocation (#196)
//
// Apple requires apps that offer Sign in with Apple to revoke Apple user tokens
// when the user deletes their account. This method:
//  1. Builds a client-secret JWT signed with the Apple Music/Sign-in private key (ES256).
//  2. Exchanges the authorization_code (captured client-side at SIWA time) for a
//     refresh_token via the Apple auth/token endpoint.
//  3. POSTs the refresh_token to the Apple auth/revoke endpoint.
//
// Best-effort: when the Apple key material is not configured, or any step fails,
// the error is logged but NOT returned — account deletion must still succeed.
// Apple may have already invalidated the token, the code may be expired, etc.

const (
	appleTokenURL  = "https://appleid.apple.com/auth/token"
	appleRevokeURL = "https://appleid.apple.com/auth/revoke"
	appleAudience  = "https://appleid.apple.com"
)

// RevokeAppleToken revokes the Apple user token bound to the given authorization
// code. It never returns a terminal error — callers should proceed with account
// deletion regardless. Returns nil on success or when not configured.
func (s *OAuthService) RevokeAppleToken(ctx context.Context, authorizationCode string) error {
	if s.appleTeamID == "" || s.appleKeyID == "" || s.applePrivateKey == "" {
		slog.Info("RevokeAppleToken: skipping — Apple revocation not configured (APPLE_TEAM_ID/KEY_ID/PRIVATE_KEY unset)")
		return nil
	}
	if strings.TrimSpace(authorizationCode) == "" {
		slog.Info("RevokeAppleToken: skipping — no authorization_code provided")
		return nil
	}

	clientSecret, err := s.generateAppleClientSecret()
	if err != nil {
		slog.Warn("RevokeAppleToken: failed to generate client secret", "error", err)
		return nil
	}

	// Step 1: exchange the authorization_code for a refresh_token.
	refreshToken, err := s.exchangeAppleAuthCode(ctx, authorizationCode, clientSecret)
	if err != nil {
		slog.Warn("RevokeAppleToken: auth/token exchange failed", "error", err)
		return nil
	}

	// Step 2: revoke the refresh_token.
	if err := s.postAppleRevoke(ctx, refreshToken, clientSecret); err != nil {
		slog.Warn("RevokeAppleToken: auth/revoke failed", "error", err)
		return nil
	}

	slog.Info("RevokeAppleToken: Apple user token revoked successfully")
	return nil
}

// generateAppleClientSecret builds the ES256-signed client-secret JWT per Apple's
// documentation. Valid for up to 6 months; we mint a fresh one each call for
// simplicity (account deletion is rare).
func (s *OAuthService) generateAppleClientSecret() (string, error) {
	block, _ := pem.Decode([]byte(s.applePrivateKey))
	if block == nil {
		return "", fmt.Errorf("apple private key is not valid PEM")
	}
	key, err := x509.ParsePKCS8PrivateKey(block.Bytes)
	if err != nil {
		return "", fmt.Errorf("parse apple private key: %w", err)
	}
	ecdsaKey, ok := key.(*ecdsa.PrivateKey)
	if !ok {
		return "", fmt.Errorf("apple private key is not ECDSA P-256")
	}

	now := time.Now()
	claims := jwt.RegisteredClaims{
		Issuer:    s.appleTeamID,
		IssuedAt:  jwt.NewNumericDate(now),
		ExpiresAt: jwt.NewNumericDate(now.Add(30 * time.Minute)),
		Audience:  []string{appleAudience},
		Subject:   s.appleBundleID,
	}
	token := jwt.NewWithClaims(jwt.SigningMethodES256, claims)
	token.Header["kid"] = s.appleKeyID
	return token.SignedString(ecdsaKey)
}

// exchangeAppleAuthCode exchanges the SIWA authorization_code for a refresh_token.
func (s *OAuthService) exchangeAppleAuthCode(ctx context.Context, code, clientSecret string) (string, error) {
	form := url.Values{
		"grant_type":    {"authorization_code"},
		"code":          {code},
		"client_id":     {s.appleBundleID},
		"client_secret": {clientSecret},
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, appleTokenURL, strings.NewReader(form.Encode()))
	if err != nil {
		return "", err
	}
	req.Header.Set("Content-Type", "application/x-www-form-urlencoded")

	resp, err := s.appleClient.Do(req)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()

	body, _ := io.ReadAll(io.LimitReader(resp.Body, 1<<14))
	if resp.StatusCode != http.StatusOK {
		return "", fmt.Errorf("apple auth/token returned %d: %s", resp.StatusCode, string(body))
	}

	var parsed struct {
		RefreshToken string `json:"refresh_token"`
	}
	if err := json.Unmarshal(body, &parsed); err != nil {
		return "", fmt.Errorf("decode apple token response: %w", err)
	}
	if parsed.RefreshToken == "" {
		return "", fmt.Errorf("apple auth/token response missing refresh_token")
	}
	return parsed.RefreshToken, nil
}

// postAppleRevoke revokes a refresh_token via Apple's auth/revoke endpoint.
func (s *OAuthService) postAppleRevoke(ctx context.Context, refreshToken, clientSecret string) error {
	form := url.Values{
		"token":           {refreshToken},
		"token_type_hint": {"refresh_token"},
		"client_id":       {s.appleBundleID},
		"client_secret":   {clientSecret},
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, appleRevokeURL, strings.NewReader(form.Encode()))
	if err != nil {
		return err
	}
	req.Header.Set("Content-Type", "application/x-www-form-urlencoded")

	resp, err := s.appleClient.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(io.LimitReader(resp.Body, 1<<14))
		return fmt.Errorf("apple auth/revoke returned %d: %s", resp.StatusCode, string(body))
	}
	return nil
}
