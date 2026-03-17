package apns

import (
	"context"
	"crypto/ecdsa"
	"crypto/elliptic"
	"crypto/rand"
	"crypto/x509"
	"encoding/pem"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

func TestProviderSendSuccess(t *testing.T) {
	key, err := ecdsa.GenerateKey(elliptic.P256(), rand.Reader)
	if err != nil {
		t.Fatalf("generate key: %v", err)
	}
	keyDER, err := x509.MarshalPKCS8PrivateKey(key)
	if err != nil {
		t.Fatalf("marshal key: %v", err)
	}
	keyPEM := pem.EncodeToMemory(&pem.Block{Type: "PRIVATE KEY", Bytes: keyDER})
	escapedPEM := strings.ReplaceAll(string(keyPEM), "\n", "\\n")

	reqHits := 0
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		reqHits++
		if got := r.Header.Get("apns-topic"); got != "app.pepinillo.ios" {
			w.WriteHeader(http.StatusBadRequest)
			return
		}
		if !strings.HasPrefix(r.Header.Get("authorization"), "bearer ") {
			w.WriteHeader(http.StatusUnauthorized)
			return
		}
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte(`{}`))
	}))
	defer srv.Close()

	p := NewProvider(Config{
		TeamID:     "TEAM123",
		KeyID:      "KEY123",
		PrivateKey: escapedPEM,
		Topic:      "app.pepinillo.ios",
		BaseURL:    srv.URL,
	})
	if err := p.Send(context.Background(), "ios", "device-token-1", "Hola", "Mundo", map[string]string{"type": "test"}); err != nil {
		t.Fatalf("send failed: %v", err)
	}
	if reqHits != 1 {
		t.Fatalf("expected 1 request, got %d", reqHits)
	}
}

func TestProviderSendValidation(t *testing.T) {
	p := NewProvider(Config{})
	if err := p.Send(context.Background(), "android", "abc", "t", "b", nil); err != ErrAPNSInvalidPlatform {
		t.Fatalf("expected ErrAPNSInvalidPlatform, got %v", err)
	}
	if err := p.Send(context.Background(), "ios", "", "t", "b", nil); err != ErrAPNSInvalidDeviceToken {
		t.Fatalf("expected ErrAPNSInvalidDeviceToken, got %v", err)
	}
	if err := p.Send(context.Background(), "ios", "abc", "t", "b", nil); err != ErrAPNSNotConfigured {
		t.Fatalf("expected ErrAPNSNotConfigured, got %v", err)
	}
}
