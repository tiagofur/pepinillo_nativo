package memory

import (
	"context"
	"crypto/subtle"
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

type AuthStore struct {
	mu                sync.RWMutex
	refreshByUID      map[string]map[string]tokenEntry
	resetByEmail      map[string]resetEntry
	emailVerifyByEmail map[string]resetEntry
}

func NewAuthStore() *AuthStore {
	return &AuthStore{
		refreshByUID:      make(map[string]map[string]tokenEntry),
		resetByEmail:      make(map[string]resetEntry),
		emailVerifyByEmail: make(map[string]resetEntry),
	}
}

func (s *AuthStore) StoreRefreshToken(_ context.Context, userID, token string, ttlSeconds int64) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	if _, ok := s.refreshByUID[userID]; !ok {
		s.refreshByUID[userID] = make(map[string]tokenEntry)
	}
	s.refreshByUID[userID][token] = tokenEntry{ExpiresAt: time.Now().UTC().Add(time.Duration(ttlSeconds) * time.Second)}
	return nil
}

func (s *AuthStore) ValidateRefreshToken(_ context.Context, userID, token string) (bool, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	userTokens, ok := s.refreshByUID[userID]
	if !ok {
		return false, nil
	}
	entry, ok := userTokens[token]
	if !ok {
		return false, nil
	}
	if time.Now().UTC().After(entry.ExpiresAt) {
		return false, nil
	}
	return true, nil
}

func (s *AuthStore) RevokeRefreshToken(_ context.Context, userID, token string) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	if userTokens, ok := s.refreshByUID[userID]; ok {
		delete(userTokens, token)
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
