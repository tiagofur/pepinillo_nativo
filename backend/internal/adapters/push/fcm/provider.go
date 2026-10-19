package fcm

import (
	"bytes"
	"context"
	"crypto"
	"crypto/rand"
	"crypto/rsa"
	"crypto/sha256"
	"crypto/x509"
	"encoding/base64"
	"encoding/json"
	"encoding/pem"
	"errors"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"strings"
	"sync"
	"time"

	"pepinillo/backend/internal/ports"
)

var ErrFCMNotConfigured = errors.New("fcm_not_configured")

// responseIndicatesUnregistered reports whether an FCM error body carries the
// UNREGISTERED error code (dead token). The body is bounded: error payloads
// are small JSON documents.
func responseIndicatesUnregistered(resp *http.Response) bool {
	body, err := io.ReadAll(io.LimitReader(resp.Body, 4096))
	if err != nil {
		return false
	}
	return strings.Contains(string(body), "UNREGISTERED")
}

type Config struct {
	ProjectID                string
	ServiceAccountEmail      string
	ServiceAccountPrivateKey string
	OAuthTokenURL            string
	OAuthScope               string
	APIBaseURL               string
}

type Provider struct {
	cfg        Config
	httpClient *http.Client

	tokenMu        sync.Mutex
	accessToken    string
	accessTokenExp time.Time
}

func NewProvider(cfg Config) *Provider {
	cfg.OAuthTokenURL = strings.TrimSuffix(cfg.OAuthTokenURL, "/")
	cfg.APIBaseURL = strings.TrimSuffix(cfg.APIBaseURL, "/")
	return &Provider{
		cfg:        cfg,
		httpClient: &http.Client{Timeout: 10 * time.Second},
	}
}

func (p *Provider) Send(ctx context.Context, platform, token, title, body string, data map[string]string) error {
	if strings.TrimSpace(token) == "" {
		return errors.New("invalid_push_token")
	}
	if strings.TrimSpace(p.cfg.ProjectID) == "" ||
		strings.TrimSpace(p.cfg.ServiceAccountEmail) == "" ||
		strings.TrimSpace(p.cfg.ServiceAccountPrivateKey) == "" ||
		strings.TrimSpace(p.cfg.OAuthTokenURL) == "" ||
		strings.TrimSpace(p.cfg.OAuthScope) == "" ||
		strings.TrimSpace(p.cfg.APIBaseURL) == "" {
		return ErrFCMNotConfigured
	}

	accessToken, err := p.oauthAccessToken(ctx)
	if err != nil {
		return err
	}

	msgData := map[string]string{}
	for k, v := range data {
		msgData[k] = v
	}
	msgData["platform"] = strings.ToLower(strings.TrimSpace(platform))

	payload := map[string]any{
		"message": map[string]any{
			"token": token,
			"notification": map[string]string{
				"title": title,
				"body":  body,
			},
			"data": msgData,
		},
	}
	bodyJSON, err := json.Marshal(payload)
	if err != nil {
		return err
	}

	endpoint := fmt.Sprintf("%s/v1/projects/%s/messages:send", p.cfg.APIBaseURL, p.cfg.ProjectID)
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, endpoint, bytes.NewReader(bodyJSON))
	if err != nil {
		return err
	}
	req.Header.Set("Authorization", "Bearer "+accessToken)
	req.Header.Set("Content-Type", "application/json")

	resp, err := p.httpClient.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode == http.StatusUnauthorized || resp.StatusCode == http.StatusForbidden {
		return ErrFCMNotConfigured
	}
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		// A3: dead tokens must be pruned, not retried forever. FCM v1
		// reports them as 404 + UNREGISTERED in the error details.
		if resp.StatusCode == http.StatusNotFound && responseIndicatesUnregistered(resp) {
			return ports.ErrPushTokenUnregistered
		}
		return fmt.Errorf("fcm_send_failed: status_%d", resp.StatusCode)
	}
	return nil
}

func (p *Provider) oauthAccessToken(ctx context.Context) (string, error) {
	p.tokenMu.Lock()
	defer p.tokenMu.Unlock()

	if p.accessToken != "" && time.Now().UTC().Before(p.accessTokenExp.Add(-time.Minute)) {
		return p.accessToken, nil
	}

	assertion, err := p.serviceAccountJWT()
	if err != nil {
		return "", ErrFCMNotConfigured
	}

	form := url.Values{}
	form.Set("grant_type", "urn:ietf:params:oauth:grant-type:jwt-bearer")
	form.Set("assertion", assertion)

	req, err := http.NewRequestWithContext(ctx, http.MethodPost, p.cfg.OAuthTokenURL, strings.NewReader(form.Encode()))
	if err != nil {
		return "", err
	}
	req.Header.Set("Content-Type", "application/x-www-form-urlencoded")

	resp, err := p.httpClient.Do(req)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()

	if resp.StatusCode == http.StatusUnauthorized || resp.StatusCode == http.StatusForbidden || resp.StatusCode == http.StatusBadRequest {
		return "", ErrFCMNotConfigured
	}
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return "", fmt.Errorf("fcm_oauth_failed: status_%d", resp.StatusCode)
	}

	var tokenResp struct {
		AccessToken string `json:"access_token"`
		ExpiresIn   int    `json:"expires_in"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&tokenResp); err != nil {
		return "", err
	}
	if tokenResp.AccessToken == "" {
		return "", ErrFCMNotConfigured
	}
	expiresIn := tokenResp.ExpiresIn
	if expiresIn <= 0 {
		expiresIn = 3600
	}
	p.accessToken = tokenResp.AccessToken
	p.accessTokenExp = time.Now().UTC().Add(time.Duration(expiresIn) * time.Second)

	return p.accessToken, nil
}

func (p *Provider) serviceAccountJWT() (string, error) {
	privateKey, err := parseRSAPrivateKey(p.cfg.ServiceAccountPrivateKey)
	if err != nil {
		return "", err
	}

	now := time.Now().UTC()
	header := map[string]any{"alg": "RS256", "typ": "JWT"}
	claims := map[string]any{
		"iss":   p.cfg.ServiceAccountEmail,
		"scope": p.cfg.OAuthScope,
		"aud":   p.cfg.OAuthTokenURL,
		"iat":   now.Unix(),
		"exp":   now.Add(time.Hour).Unix(),
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
	signature, err := rsa.SignPKCS1v15(rand.Reader, privateKey, crypto.SHA256, hash[:])
	if err != nil {
		return "", err
	}
	return signingInput + "." + enc.EncodeToString(signature), nil
}

func parseRSAPrivateKey(raw string) (*rsa.PrivateKey, error) {
	normalized := strings.ReplaceAll(strings.TrimSpace(raw), "\\n", "\n")
	block, _ := pem.Decode([]byte(normalized))
	if block == nil {
		return nil, errors.New("invalid_private_key_pem")
	}

	if key, err := x509.ParsePKCS8PrivateKey(block.Bytes); err == nil {
		rsaKey, ok := key.(*rsa.PrivateKey)
		if !ok {
			return nil, errors.New("private_key_not_rsa")
		}
		return rsaKey, nil
	}
	if key, err := x509.ParsePKCS1PrivateKey(block.Bytes); err == nil {
		return key, nil
	}
	return nil, errors.New("invalid_rsa_private_key")
}
