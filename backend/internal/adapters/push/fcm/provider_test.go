package fcm

import (
	"context"
	"crypto/rand"
	"crypto/rsa"
	"crypto/x509"
	"encoding/json"
	"encoding/pem"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

func TestProviderSendSuccessWithOAuth(t *testing.T) {
	privateKey, err := rsa.GenerateKey(rand.Reader, 2048)
	if err != nil {
		t.Fatalf("generate key: %v", err)
	}
	keyDER, err := x509.MarshalPKCS8PrivateKey(privateKey)
	if err != nil {
		t.Fatalf("marshal key: %v", err)
	}
	keyPEM := pem.EncodeToMemory(&pem.Block{Type: "PRIVATE KEY", Bytes: keyDER})
	escapedPEM := strings.ReplaceAll(string(keyPEM), "\n", "\\n")

	tokenHits := 0
	oauthSrv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		tokenHits++
		if err := r.ParseForm(); err != nil {
			w.WriteHeader(http.StatusBadRequest)
			return
		}
		if r.Form.Get("grant_type") != "urn:ietf:params:oauth:grant-type:jwt-bearer" || r.Form.Get("assertion") == "" {
			w.WriteHeader(http.StatusBadRequest)
			return
		}
		_ = json.NewEncoder(w).Encode(map[string]any{
			"access_token": "fcm-oauth-token",
			"expires_in":   3600,
		})
	}))
	defer oauthSrv.Close()

	pushHits := 0
	pushSrv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		pushHits++
		if got := r.Header.Get("Authorization"); got != "Bearer fcm-oauth-token" {
			w.WriteHeader(http.StatusUnauthorized)
			return
		}
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte(`{"name":"projects/p/messages/123"}`))
	}))
	defer pushSrv.Close()

	p := NewProvider(Config{
		ProjectID:                "pepinillo-dev",
		ServiceAccountEmail:      "svc@project.iam.gserviceaccount.com",
		ServiceAccountPrivateKey: escapedPEM,
		OAuthTokenURL:            oauthSrv.URL,
		OAuthScope:               "https://www.googleapis.com/auth/firebase.messaging",
		APIBaseURL:               pushSrv.URL,
	})

	if err := p.Send(context.Background(), "android", "token-1", "Hi", "Body", map[string]string{"type": "test"}); err != nil {
		t.Fatalf("send 1 failed: %v", err)
	}
	if err := p.Send(context.Background(), "ios", "token-2", "Hi2", "Body2", map[string]string{"type": "test2"}); err != nil {
		t.Fatalf("send 2 failed: %v", err)
	}
	if tokenHits != 1 {
		t.Fatalf("expected cached oauth token (1 call), got %d", tokenHits)
	}
	if pushHits != 2 {
		t.Fatalf("expected 2 push calls, got %d", pushHits)
	}
}

func TestProviderSendNotConfigured(t *testing.T) {
	p := NewProvider(Config{})
	err := p.Send(context.Background(), "android", "token", "A", "B", nil)
	if err != ErrFCMNotConfigured {
		t.Fatalf("expected ErrFCMNotConfigured, got %v", err)
	}
}
