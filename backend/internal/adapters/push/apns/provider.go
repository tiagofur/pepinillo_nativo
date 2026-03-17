package apns

import (
	"bytes"
	"context"
	"crypto/ecdsa"
	"crypto/rand"
	"crypto/sha256"
	"crypto/x509"
	"encoding/base64"
	"encoding/json"
	"encoding/pem"
	"errors"
	"fmt"
	"math/big"
	"net/http"
	"strings"
	"sync"
	"time"
)

var (
	ErrAPNSNotConfigured      = errors.New("apns_not_configured")
	ErrAPNSInvalidPlatform    = errors.New("apns_invalid_platform")
	ErrAPNSInvalidDeviceToken = errors.New("apns_invalid_device_token")
)

type Config struct {
	TeamID     string
	KeyID      string
	PrivateKey string
	Topic      string
	BaseURL    string
}

type Provider struct {
	cfg        Config
	httpClient *http.Client

	tokenMu     sync.Mutex
	jwtToken    string
	jwtIssuedAt time.Time
}

func NewProvider(cfg Config) *Provider {
	cfg.BaseURL = strings.TrimSuffix(cfg.BaseURL, "/")
	return &Provider{
		cfg:        cfg,
		httpClient: &http.Client{Timeout: 10 * time.Second},
	}
}

func (p *Provider) Send(ctx context.Context, platform, token, title, body string, data map[string]string) error {
	if strings.ToLower(strings.TrimSpace(platform)) != "ios" {
		return ErrAPNSInvalidPlatform
	}
	token = strings.TrimSpace(token)
	if token == "" {
		return ErrAPNSInvalidDeviceToken
	}

	if strings.TrimSpace(p.cfg.TeamID) == "" ||
		strings.TrimSpace(p.cfg.KeyID) == "" ||
		strings.TrimSpace(p.cfg.PrivateKey) == "" ||
		strings.TrimSpace(p.cfg.Topic) == "" ||
		strings.TrimSpace(p.cfg.BaseURL) == "" {
		return ErrAPNSNotConfigured
	}

	jwtToken, err := p.authToken()
	if err != nil {
		return err
	}

	payload := map[string]any{
		"aps": map[string]any{
			"alert": map[string]string{
				"title": title,
				"body":  body,
			},
			"sound": "default",
		},
		"data": data,
	}
	bodyJSON, err := json.Marshal(payload)
	if err != nil {
		return err
	}

	endpoint := fmt.Sprintf("%s/3/device/%s", p.cfg.BaseURL, token)
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, endpoint, bytes.NewReader(bodyJSON))
	if err != nil {
		return err
	}
	req.Header.Set("authorization", "bearer "+jwtToken)
	req.Header.Set("apns-topic", p.cfg.Topic)
	req.Header.Set("apns-push-type", "alert")
	req.Header.Set("content-type", "application/json")

	resp, err := p.httpClient.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode == http.StatusUnauthorized || resp.StatusCode == http.StatusForbidden {
		return ErrAPNSNotConfigured
	}
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return fmt.Errorf("apns_send_failed: status_%d", resp.StatusCode)
	}
	return nil
}

func (p *Provider) authToken() (string, error) {
	p.tokenMu.Lock()
	defer p.tokenMu.Unlock()

	// APNs auth tokens are valid for up to 60m. Reuse for 50m.
	if p.jwtToken != "" && time.Since(p.jwtIssuedAt) < 50*time.Minute {
		return p.jwtToken, nil
	}

	privateKey, err := parseECDSAPrivateKey(p.cfg.PrivateKey)
	if err != nil {
		return "", ErrAPNSNotConfigured
	}

	now := time.Now().UTC()
	header := map[string]any{
		"alg": "ES256",
		"kid": p.cfg.KeyID,
	}
	claims := map[string]any{
		"iss": p.cfg.TeamID,
		"iat": now.Unix(),
	}

	headerJSON, err := json.Marshal(header)
	if err != nil {
		return "", err
	}
	claimsJSON, err := json.Marshal(claims)
	if err != nil {
		return "", err
	}
	enc := base64.RawURLEncoding
	signingInput := enc.EncodeToString(headerJSON) + "." + enc.EncodeToString(claimsJSON)

	hash := sha256.Sum256([]byte(signingInput))
	r, s, err := ecdsa.Sign(rand.Reader, privateKey, hash[:])
	if err != nil {
		return "", err
	}
	signature := joseConcatSignature(r, s, 32)

	p.jwtToken = signingInput + "." + enc.EncodeToString(signature)
	p.jwtIssuedAt = now
	return p.jwtToken, nil
}

func parseECDSAPrivateKey(raw string) (*ecdsa.PrivateKey, error) {
	normalized := strings.ReplaceAll(strings.TrimSpace(raw), "\\n", "\n")
	block, _ := pem.Decode([]byte(normalized))
	if block == nil {
		return nil, errors.New("invalid_private_key_pem")
	}

	if key, err := x509.ParsePKCS8PrivateKey(block.Bytes); err == nil {
		ecdsaKey, ok := key.(*ecdsa.PrivateKey)
		if !ok {
			return nil, errors.New("private_key_not_ecdsa")
		}
		return ecdsaKey, nil
	}
	if key, err := x509.ParseECPrivateKey(block.Bytes); err == nil {
		return key, nil
	}
	return nil, errors.New("invalid_ecdsa_private_key")
}

func joseConcatSignature(r, s *big.Int, size int) []byte {
	out := make([]byte, size*2)
	rb := r.Bytes()
	sb := s.Bytes()
	copy(out[size-len(rb):size], rb)
	copy(out[(size*2)-len(sb):], sb)
	return out
}
