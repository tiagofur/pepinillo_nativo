package memory

import (
	"context"
	"crypto/hmac"
	"crypto/rand"
	"crypto/sha256"
	"crypto/subtle"
	"encoding/hex"
	"sync"
	"time"
)

type tokenEntry struct {
	ExpiresAt time.Time
}

type resetEntry struct {
	Code      string
	ExpiresAt time.Time
}

// AuthStore is an in-memory implementation used for tests and as a Redis
// fallback. Refresh tokens are hashed with HMAC-SHA-256 before storage so
// the same invariant holds as in the Redis store: plaintext refresh tokens
// never live at rest.
//
// The hashKey is optional: if empty, a random 32-byte key is generated on
// construction. This keeps test code ergonomic (NewAuthStore()) while still
// exercising the hashing path.
type AuthStore struct {
	mu                 sync.RWMutex
	hashKey            []byte
	refreshByUID       map[string]map[string]tokenEntry
	resetByEmail       map[string]resetEntry
	emailVerifyByEmail map[string]resetEntry
}

// NewAuthStore creates an in-memory auth store with a random per-instance
// hash key. Suitable for tests and non-production fallback.
func NewAuthStore() *AuthStore {
	return NewAuthStoreWithKey(randomKey())
}

// NewAuthStoreWithKey creates an in-memory auth store with a caller-provided
// hash key. Useful when tests want deterministic hashes or when the fallback
// must agree with the Redis store's key.
func NewAuthStoreWithKey(hashKey []byte) *AuthStore {
	if len(hashKey) == 0 {
		hashKey = randomKey()
	}
	return &AuthStore{
		hashKey:            hashKey,
		refreshByUID:       make(map[string]map[string]tokenEntry),
		resetByEmail:       make(map[string]resetEntry),
		emailVerifyByEmail: make(map[string]resetEntry),
	}
}

func (s *AuthStore) StoreRefreshToken(_ context.Context, userID, token string, ttlSeconds int64) error {
	hash := s.hashToken(token)
	s.mu.Lock()
	defer s.mu.Unlock()
	if _, ok := s.refreshByUID[userID]; !ok {
		s.refreshByUID[userID] = make(map[string]tokenEntry)
	}
	s.refreshByUID[userID][hash] = tokenEntry{ExpiresAt: time.Now().UTC().Add(time.Duration(ttlSeconds) * time.Second)}
	return nil
}

func (s *AuthStore) ValidateRefreshToken(_ context.Context, userID, token string) (bool, error) {
	hash := s.hashToken(token)
	s.mu.RLock()
	defer s.mu.RUnlock()
	userTokens, ok := s.refreshByUID[userID]
	if !ok {
		return false, nil
	}
	entry, ok := userTokens[hash]
	if !ok {
		return false, nil
	}
	if time.Now().UTC().After(entry.ExpiresAt) {
		return false, nil
	}
	return true, nil
}

func (s *AuthStore) RevokeRefreshToken(_ context.Context, userID, token string) error {
	hash := s.hashToken(token)
	s.mu.Lock()
	defer s.mu.Unlock()
	if userTokens, ok := s.refreshByUID[userID]; ok {
		delete(userTokens, hash)
	}
	return nil
}

func (s *AuthStore) RevokeAllRefreshTokens(_ context.Context, userID string) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	delete(s.refreshByUID, userID)
	return nil
}

func (s *AuthStore) StorePasswordResetCode(_ context.Context, email, code string, ttlSeconds int64) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.resetByEmail[email] = resetEntry{Code: code, ExpiresAt: time.Now().UTC().Add(time.Duration(ttlSeconds) * time.Second)}
	return nil
}

func (s *AuthStore) ValidatePasswordResetCode(_ context.Context, email, code string) (bool, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	entry, ok := s.resetByEmail[email]
	if !ok {
		return false, nil
	}
	if time.Now().UTC().After(entry.ExpiresAt) {
		return false, nil
	}
	return subtle.ConstantTimeCompare([]byte(entry.Code), []byte(code)) == 1, nil
}

func (s *AuthStore) RevokePasswordResetCode(_ context.Context, email string) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	delete(s.resetByEmail, email)
	return nil
}

func (s *AuthStore) StoreEmailVerificationCode(_ context.Context, email, code string, ttlSeconds int64) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.emailVerifyByEmail[email] = resetEntry{Code: code, ExpiresAt: time.Now().UTC().Add(time.Duration(ttlSeconds) * time.Second)}
	return nil
}

func (s *AuthStore) ValidateEmailVerificationCode(_ context.Context, email, code string) (bool, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	entry, ok := s.emailVerifyByEmail[email]
	if !ok {
		return false, nil
	}
	if time.Now().UTC().After(entry.ExpiresAt) {
		return false, nil
	}
	return subtle.ConstantTimeCompare([]byte(entry.Code), []byte(code)) == 1, nil
}

func (s *AuthStore) RevokeEmailVerificationCode(_ context.Context, email string) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	delete(s.emailVerifyByEmail, email)
	return nil
}

func (s *AuthStore) hashToken(token string) string {
	mac := hmac.New(sha256.New, s.hashKey)
	mac.Write([]byte(token))
	return hex.EncodeToString(mac.Sum(nil))
}

func randomKey() []byte {
	// Process-local random key so that hashes are deterministic within the
	// lifetime of the process but not reusable elsewhere. Callers that need
	// cross-process stability must provide their own via NewAuthStoreWithKey.
	b := make([]byte, 32)
	if _, err := rand.Read(b); err != nil {
		// crypto/rand read failure is unrecoverable; panic is appropriate
		// here because this path only runs at process start.
		panic("memory auth store: failed to generate random hash key: " + err.Error())
	}
	return b
}
