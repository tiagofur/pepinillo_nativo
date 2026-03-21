package services

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
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
	users          ports.UserRepository
	authStore      ports.AuthStore
	jwtSecret      string
	jwtIssuer      string
	accessTTL      int64
	refreshTTL     int64
	googleClient   *http.Client
	googleClientIDs []string
	appleBundleID  string
}

type googleTokenInfo struct {
	Aud           string `json:"aud"`
	Sub           string `json:"sub"`
	Azp           string `json:"azp"`
	Email         string `json:"email"`
	EmailVerified bool   `json:"email_verified"`
	Name          string `json:"name"`
	Picture       string `json:"picture"`
	Exp           int64  `json:"exp"`
}

type appleTokenInfo struct {
	Sub           string     `json:"sub"`
	Email         string     `json:"email"`
	EmailVerified bool       `json:"email_verified"`
	Name          *appleName `json:"name,omitempty"`
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
	}
}

func (s *OAuthService) LoginWithGoogle(ctx context.Context, idToken string) (*domain.User, *AuthTokens, error) {
	tokenInfo, err := s.verifyGoogleToken(ctx, idToken)
	if err != nil {
		return nil, nil, fmt.Errorf("invalid google token: %w", err)
	}

	user, err := s.users.GetByGoogleID(ctx, tokenInfo.Sub)
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

	existing, err := s.users.GetByEmail(ctx, tokenInfo.Email)
	if err != nil {
		return nil, nil, err
	}

	if existing != nil {
		if existing.GoogleID != nil {
			return nil, nil, ErrAccountAlreadyLinked
		}
		if err := s.users.LinkGoogleAccount(ctx, existing.ID, tokenInfo.Sub, tokenInfo.Email, tokenInfo.Name, tokenInfo.Picture); err != nil {
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

	user = &domain.User{
		ID:               uuid.NewString(),
		Email:            tokenInfo.Email,
		Name:             tokenInfo.Name,
		ImageURL:         &tokenInfo.Picture,
		EmailVerified:    tokenInfo.EmailVerified,
		EmailVerifiedAt:  &[]time.Time{time.Now().UTC()}[0],
		SubscriptionTier: "free",
		GoogleID:         &tokenInfo.Sub,
		GoogleEmail:      &tokenInfo.Email,
		GoogleName:       &tokenInfo.Name,
		GooglePicture:    &tokenInfo.Picture,
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

func (s *OAuthService) LoginWithApple(ctx context.Context, idToken string) (*domain.User, *AuthTokens, error) {
	tokenInfo, err := s.verifyAppleToken(ctx, idToken)
	if err != nil {
		return nil, nil, fmt.Errorf("invalid apple token: %w", err)
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

	user = &domain.User{
		ID:               uuid.NewString(),
		Email:            tokenInfo.Email,
		Name:             name,
		EmailVerified:    tokenInfo.EmailVerified,
		EmailVerifiedAt:  &[]time.Time{time.Now().UTC()}[0],
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
		return nil, fmt.Errorf("invalid google token: %w", err)
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

func (s *OAuthService) LinkAppleAccount(ctx context.Context, userID, idToken string) (*domain.User, error) {
	tokenInfo, err := s.verifyAppleToken(ctx, idToken)
	if err != nil {
		return nil, fmt.Errorf("invalid apple token: %w", err)
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
	resp, err := s.googleClient.Get("https://oauth2.googleapis.com/tokeninfo?id_token=" + idToken)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("google token verification failed: %s", resp.Status)
	}

	var tokenInfo googleTokenInfo
	if err := json.NewDecoder(resp.Body).Decode(&tokenInfo); err != nil {
		return nil, err
	}

	if !s.isValidGoogleAudience(tokenInfo.Aud) {
		return nil, errors.New("invalid google token audience")
	}

	now := time.Now().Unix()
	if tokenInfo.Exp < now {
		return nil, errors.New("google token expired")
	}

	return &tokenInfo, nil
}

func (s *OAuthService) isValidGoogleAudience(aud string) bool {
	if len(s.googleClientIDs) == 0 {
		return true // skip validation if not configured
	}
	for _, id := range s.googleClientIDs {
		if id == aud {
			return true
		}
	}
	return false
}

func (s *OAuthService) verifyAppleToken(ctx context.Context, idToken string) (*appleTokenInfo, error) {
	appleKeysURL := "https://appleid.apple.com/auth/keys"

	fetch, err := http.NewRequestWithContext(ctx, "GET", appleKeysURL, nil)
	if err != nil {
		return nil, fmt.Errorf("failed to create request for apple keys: %w", err)
	}

	resp, err := s.googleClient.Do(fetch)
	if err != nil {
		return nil, fmt.Errorf("failed to fetch apple keys: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("failed to fetch apple keys: %s", resp.Status)
	}

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("failed to read apple keys response: %w", err)
	}

	appleKeys, err := jwk.Parse(body)
	if err != nil {
		return nil, fmt.Errorf("failed to parse apple keys: %w", err)
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
	if !strings.Contains(issuer, "appleid.apple.com") {
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
	if exp.IsZero() || exp.Before(time.Now()) {
		return nil, errors.New("apple token expired")
	}

	return &tokenInfo, nil
}

func (s *OAuthService) generateTokens(user *domain.User) (*AuthTokens, error) {
	now := time.Now().UTC()
	accessExpiry := now.Add(time.Duration(s.accessTTL) * time.Second)
	refreshExpiry := now.Add(time.Duration(s.refreshTTL) * time.Second)

	accessClaims := middleware.UserClaims{
		UserID:    user.ID,
		Email:     user.Email,
		Tier:      user.SubscriptionTier,
		TokenType: "access",
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
		UserID:    user.ID,
		Email:     user.Email,
		Tier:      user.SubscriptionTier,
		TokenType: "refresh",
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
