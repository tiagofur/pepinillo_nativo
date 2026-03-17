package redis

import (
	"context"
	"crypto/sha256"
	"crypto/subtle"
	"encoding/hex"
	"fmt"
	"time"

	goredis "github.com/redis/go-redis/v9"
)

type AuthStore struct {
	client *goredis.Client
}

func (s *AuthStore) Ping(ctx context.Context) error {
	return s.client.Ping(ctx).Err()
}

func NewAuthStore(redisURL string) (*AuthStore, error) {
	opt, err := goredis.ParseURL(redisURL)
	if err != nil {
		return nil, err
	}
	client := goredis.NewClient(opt)
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()
	if err := client.Ping(ctx).Err(); err != nil {
		return nil, err
	}
	return &AuthStore{client: client}, nil
}

func (s *AuthStore) StoreRefreshToken(ctx context.Context, userID, token string, ttlSeconds int64) error {
	hash := hashToken(token)
	tokenKey := fmt.Sprintf("refresh:%s:%s", userID, hash)
	indexKey := fmt.Sprintf("refresh_index:%s", userID)
	ttl := time.Duration(ttlSeconds) * time.Second
	pipe := s.client.TxPipeline()
	pipe.Set(ctx, tokenKey, "1", ttl)
	pipe.SAdd(ctx, indexKey, hash)
	pipe.Expire(ctx, indexKey, ttl)
	_, err := pipe.Exec(ctx)
	return err
}

func (s *AuthStore) ValidateRefreshToken(ctx context.Context, userID, token string) (bool, error) {
	hash := hashToken(token)
	tokenKey := fmt.Sprintf("refresh:%s:%s", userID, hash)
	count, err := s.client.Exists(ctx, tokenKey).Result()
	if err != nil {
		return false, err
	}
	return count > 0, nil
}

func (s *AuthStore) RevokeRefreshToken(ctx context.Context, userID, token string) error {
	hash := hashToken(token)
	tokenKey := fmt.Sprintf("refresh:%s:%s", userID, hash)
	indexKey := fmt.Sprintf("refresh_index:%s", userID)
	pipe := s.client.TxPipeline()
	pipe.Del(ctx, tokenKey)
	pipe.SRem(ctx, indexKey, hash)
	_, err := pipe.Exec(ctx)
	return err
}

func (s *AuthStore) RevokeAllRefreshTokens(ctx context.Context, userID string) error {
	indexKey := fmt.Sprintf("refresh_index:%s", userID)
	hashes, err := s.client.SMembers(ctx, indexKey).Result()
	if err != nil {
		return err
	}
	if len(hashes) == 0 {
		return s.client.Del(ctx, indexKey).Err()
	}
	keys := make([]string, 0, len(hashes)+1)
	for _, hash := range hashes {
		keys = append(keys, fmt.Sprintf("refresh:%s:%s", userID, hash))
	}
	keys = append(keys, indexKey)
	return s.client.Del(ctx, keys...).Err()
}

func (s *AuthStore) StorePasswordResetCode(ctx context.Context, email, code string, ttlSeconds int64) error {
	key := fmt.Sprintf("pwd_reset:%s", email)
	return s.client.Set(ctx, key, code, time.Duration(ttlSeconds)*time.Second).Err()
}

func (s *AuthStore) ValidatePasswordResetCode(ctx context.Context, email, code string) (bool, error) {
	key := fmt.Sprintf("pwd_reset:%s", email)
	stored, err := s.client.Get(ctx, key).Result()
	if err == goredis.Nil {
		return false, nil
	}
	if err != nil {
		return false, err
	}
	return subtle.ConstantTimeCompare([]byte(stored), []byte(code)) == 1, nil
}

func (s *AuthStore) RevokePasswordResetCode(ctx context.Context, email string) error {
	key := fmt.Sprintf("pwd_reset:%s", email)
	return s.client.Del(ctx, key).Err()
}

func (s *AuthStore) StoreEmailVerificationCode(ctx context.Context, email, code string, ttlSeconds int64) error {
	key := fmt.Sprintf("email_verify:%s", email)
	return s.client.Set(ctx, key, code, time.Duration(ttlSeconds)*time.Second).Err()
}

func (s *AuthStore) ValidateEmailVerificationCode(ctx context.Context, email, code string) (bool, error) {
	key := fmt.Sprintf("email_verify:%s", email)
	stored, err := s.client.Get(ctx, key).Result()
	if err == goredis.Nil {
		return false, nil
	}
	if err != nil {
		return false, err
	}
	return subtle.ConstantTimeCompare([]byte(stored), []byte(code)) == 1, nil
}

func (s *AuthStore) RevokeEmailVerificationCode(ctx context.Context, email string) error {
	key := fmt.Sprintf("email_verify:%s", email)
	return s.client.Del(ctx, key).Err()
}

func hashToken(token string) string {
	sum := sha256.Sum256([]byte(token))
	return hex.EncodeToString(sum[:])
}
