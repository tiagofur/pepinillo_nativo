package services

import (
	"context"
	"crypto/ecdsa"
	"crypto/elliptic"
	"crypto/rand"
	"crypto/rsa"
	"crypto/sha256"
	"crypto/x509"
	"encoding/base64"
	"encoding/json"
	"encoding/pem"
	"math/big"
	"net/http"
	"net/http/httptest"
	"strconv"
	"strings"
	"testing"
	"time"

	"pepinillo/backend/internal/domain"
)

func TestBillingVerifyReceiptAndroidSuccess(t *testing.T) {
	repo := newFakeUserRepo()
	user := &domain.User{ID: "user-1", Email: "billing@test.com", Name: "Billing", PasswordHash: strPtr("x"), SubscriptionTier: "free"}
	if err := repo.Create(context.Background(), user); err != nil {
		t.Fatalf("create user: %v", err)
	}

	expiry := time.Now().UTC().Add(30 * 24 * time.Hour)
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Header.Get("Authorization") != "Bearer token-123" {
			w.WriteHeader(http.StatusUnauthorized)
			return
		}
		_ = json.NewEncoder(w).Encode(map[string]any{
			"expiryTimeMillis": strconv.FormatInt(expiry.UnixMilli(), 10),
		})
	}))
	defer srv.Close()

	service := NewBillingService(repo, BillingConfig{
		GooglePlayPackageName: "com.pepinillo.android",
		GooglePlayAPIToken:    "token-123",
		GooglePlayAPIBaseURL:  srv.URL,
	})

	result, err := service.VerifyReceipt(context.Background(), user.ID, VerifyReceiptInput{
		Platform:      "android",
		ProductID:     "com.pepinillo.app.pro.monthly",
		PurchaseToken: "purchase-token-abc",
	})
	if err != nil {
		t.Fatalf("verify receipt failed: %v", err)
	}
	if !result.Valid || result.Source != "google_play" || result.SubscriptionTier != "everywhere_monthly" {
		t.Fatalf("unexpected result: %+v", result)
	}
	updated, _ := repo.GetByID(context.Background(), user.ID)
	if updated.SubscriptionTier != "everywhere_monthly" || updated.SubscriptionExpiresAt == nil {
		t.Fatalf("user not updated: %+v", updated)
	}
}

func TestBillingVerifyReceiptIOSSandboxFallback(t *testing.T) {
	repo := newFakeUserRepo()
	user := &domain.User{ID: "user-2", Email: "ios@test.com", Name: "iOS", PasswordHash: strPtr("x"), SubscriptionTier: "free"}
	if err := repo.Create(context.Background(), user); err != nil {
		t.Fatalf("create user: %v", err)
	}

	expiry := time.Now().UTC().Add(365 * 24 * time.Hour)

	prod := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		_ = json.NewEncoder(w).Encode(map[string]any{
			"status": 21007,
		})
	}))
	defer prod.Close()

	sandbox := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		_ = json.NewEncoder(w).Encode(map[string]any{
			"status": 0,
			"latest_receipt_info": []map[string]any{
				{
					"product_id":      "com.pepinillo.app.pro.annual",
					"expires_date_ms": strconv.FormatInt(expiry.UnixMilli(), 10),
				},
			},
		})
	}))
	defer sandbox.Close()

	service := NewBillingService(repo, BillingConfig{
		AppStoreSharedSecret:            "secret-123",
		AppStoreVerifyReceiptURL:        prod.URL,
		AppStoreSandboxVerifyReceiptURL: sandbox.URL,
	})

	result, err := service.VerifyReceipt(context.Background(), user.ID, VerifyReceiptInput{
		Platform:    "ios",
		ProductID:   "com.pepinillo.app.pro.annual",
		ReceiptData: "base64-receipt-data",
	})
	if err != nil {
		t.Fatalf("verify receipt failed: %v", err)
	}
	if !result.Valid || result.Source != "app_store" || result.SubscriptionTier != "everywhere_annual" {
		t.Fatalf("unexpected result: %+v", result)
	}
	updated, _ := repo.GetByID(context.Background(), user.ID)
	if updated.SubscriptionTier != "everywhere_annual" || updated.SubscriptionExpiresAt == nil {
		t.Fatalf("user not updated: %+v", updated)
	}
}

func TestBillingVerifyReceiptProviderNotConfigured(t *testing.T) {
	repo := newFakeUserRepo()
	user := &domain.User{ID: "user-3", Email: "cfg@test.com", Name: "Cfg", PasswordHash: strPtr("x"), SubscriptionTier: "free"}
	_ = repo.Create(context.Background(), user)

	service := NewBillingService(repo, BillingConfig{})
	_, err := service.VerifyReceipt(context.Background(), user.ID, VerifyReceiptInput{
		Platform:      "android",
		ProductID:     "com.pepinillo.app.pro.monthly",
		PurchaseToken: "token",
	})
	if err == nil || err != ErrBillingProviderNotConfigured {
		t.Fatalf("expected ErrBillingProviderNotConfigured, got %v", err)
	}
}

func TestBillingVerifyReceiptAndroidServiceAccountOAuthSuccess(t *testing.T) {
	repo := newFakeUserRepo()
	user := &domain.User{ID: "user-4", Email: "oauth@test.com", Name: "OAuth", PasswordHash: strPtr("x"), SubscriptionTier: "free"}
	if err := repo.Create(context.Background(), user); err != nil {
		t.Fatalf("create user: %v", err)
	}

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

	tokenEndpointHits := 0
	oauthSrv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		tokenEndpointHits++
		if err := r.ParseForm(); err != nil {
			w.WriteHeader(http.StatusBadRequest)
			return
		}
		if r.Form.Get("grant_type") != "urn:ietf:params:oauth:grant-type:jwt-bearer" || r.Form.Get("assertion") == "" {
			w.WriteHeader(http.StatusBadRequest)
			return
		}
		_ = json.NewEncoder(w).Encode(map[string]any{
			"access_token": "oauth-token-xyz",
			"expires_in":   3600,
			"token_type":   "Bearer",
		})
	}))
	defer oauthSrv.Close()

	expiry := time.Now().UTC().Add(30 * 24 * time.Hour)
	playSrv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Header.Get("Authorization") != "Bearer oauth-token-xyz" {
			w.WriteHeader(http.StatusUnauthorized)
			return
		}
		_ = json.NewEncoder(w).Encode(map[string]any{
			"expiryTimeMillis": strconv.FormatInt(expiry.UnixMilli(), 10),
		})
	}))
	defer playSrv.Close()

	service := NewBillingService(repo, BillingConfig{
		GooglePlayPackageName:              "com.pepinillo.android",
		GooglePlayAPIBaseURL:               playSrv.URL,
		GooglePlayServiceAccountEmail:      "svc-account@project.iam.gserviceaccount.com",
		GooglePlayServiceAccountPrivateKey: escapedPEM,
		GooglePlayOAuthTokenURL:            oauthSrv.URL,
		GooglePlayOAuthScope:               "https://www.googleapis.com/auth/androidpublisher",
	})

	result, err := service.VerifyReceipt(context.Background(), user.ID, VerifyReceiptInput{
		Platform:      "android",
		ProductID:     "com.pepinillo.app.pro.monthly",
		PurchaseToken: "purchase-token-oauth",
	})
	if err != nil {
		t.Fatalf("verify receipt failed: %v", err)
	}
	if !result.Valid || result.Source != "google_play" || result.SubscriptionTier != "everywhere_monthly" {
		t.Fatalf("unexpected result: %+v", result)
	}
	if tokenEndpointHits != 1 {
		t.Fatalf("expected exactly 1 oauth token request, got %d", tokenEndpointHits)
	}
}

func TestBillingVerifyReceiptIOSAppStoreServerAPISuccess(t *testing.T) {
	repo := newFakeUserRepo()
	user := &domain.User{ID: "user-5", Email: "ios-jwt@test.com", Name: "iOS JWT", PasswordHash: strPtr("x"), SubscriptionTier: "free"}
	if err := repo.Create(context.Background(), user); err != nil {
		t.Fatalf("create user: %v", err)
	}

	appStoreKey, err := ecdsa.GenerateKey(elliptic.P256(), rand.Reader)
	if err != nil {
		t.Fatalf("generate ecdsa key: %v", err)
	}
	keyDER, err := x509.MarshalPKCS8PrivateKey(appStoreKey)
	if err != nil {
		t.Fatalf("marshal key: %v", err)
	}
	keyPEM := pem.EncodeToMemory(&pem.Block{Type: "PRIVATE KEY", Bytes: keyDER})
	escapedPEM := strings.ReplaceAll(string(keyPEM), "\n", "\\n")
	certB64 := buildSelfSignedCertBase64(t, appStoreKey)

	expiresAt := time.Now().UTC().Add(30 * 24 * time.Hour)
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if !strings.HasPrefix(r.Header.Get("Authorization"), "Bearer ") {
			w.WriteHeader(http.StatusUnauthorized)
			return
		}
		_ = json.NewEncoder(w).Encode(map[string]any{
			"data": []map[string]any{
				{
					"lastTransactions": []map[string]any{
						{
							"signedTransactionInfo": buildSignedTransactionInfo(t, appStoreKey, certB64, "com.pepinillo.app.pro.monthly", expiresAt.UnixMilli()),
						},
					},
				},
			},
		})
	}))
	defer server.Close()

	service := NewBillingService(repo, BillingConfig{
		AppStoreServerAPIIssuerID:   "issuer-123",
		AppStoreServerAPIKeyID:      "key-123",
		AppStoreServerAPIPrivateKey: escapedPEM,
		AppStoreServerAPIBundleID:   "app.pepinillo.ios",
		AppStoreServerAPIBaseURL:    server.URL,
	})

	result, err := service.VerifyReceipt(context.Background(), user.ID, VerifyReceiptInput{
		Platform:      "ios",
		ProductID:     "com.pepinillo.app.pro.monthly",
		TransactionID: "1000001234567890",
	})
	if err != nil {
		t.Fatalf("verify receipt failed: %v", err)
	}
	if !result.Valid || result.Source != "app_store_server_api" || result.SubscriptionTier != "everywhere_monthly" {
		t.Fatalf("unexpected result: %+v", result)
	}
}

func TestBillingVerifyReceiptIOSAppStoreServerAPIInvalidSignature(t *testing.T) {
	repo := newFakeUserRepo()
	user := &domain.User{ID: "user-6", Email: "ios-jws-invalid@test.com", Name: "iOS JWS Invalid", PasswordHash: strPtr("x"), SubscriptionTier: "free"}
	if err := repo.Create(context.Background(), user); err != nil {
		t.Fatalf("create user: %v", err)
	}

	appStoreKey, err := ecdsa.GenerateKey(elliptic.P256(), rand.Reader)
	if err != nil {
		t.Fatalf("generate ecdsa key: %v", err)
	}
	keyDER, err := x509.MarshalPKCS8PrivateKey(appStoreKey)
	if err != nil {
		t.Fatalf("marshal key: %v", err)
	}
	keyPEM := pem.EncodeToMemory(&pem.Block{Type: "PRIVATE KEY", Bytes: keyDER})
	escapedPEM := strings.ReplaceAll(string(keyPEM), "\n", "\\n")
	certB64 := buildSelfSignedCertBase64(t, appStoreKey)

	expiresAt := time.Now().UTC().Add(30 * 24 * time.Hour)
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		signed := buildSignedTransactionInfo(t, appStoreKey, certB64, "com.pepinillo.app.pro.monthly", expiresAt.UnixMilli())
		parts := strings.Split(signed, ".")
		parts[1] = "A" + parts[1][1:]
		tampered := strings.Join(parts, ".")
		_ = json.NewEncoder(w).Encode(map[string]any{
			"data": []map[string]any{
				{
					"lastTransactions": []map[string]any{
						{
							"signedTransactionInfo": tampered,
						},
					},
				},
			},
		})
	}))
	defer server.Close()

	service := NewBillingService(repo, BillingConfig{
		AppStoreServerAPIIssuerID:   "issuer-123",
		AppStoreServerAPIKeyID:      "key-123",
		AppStoreServerAPIPrivateKey: escapedPEM,
		AppStoreServerAPIBundleID:   "app.pepinillo.ios",
		AppStoreServerAPIBaseURL:    server.URL,
	})

	_, err = service.VerifyReceipt(context.Background(), user.ID, VerifyReceiptInput{
		Platform:      "ios",
		ProductID:     "com.pepinillo.app.pro.monthly",
		TransactionID: "1000001234567890",
	})
	if err != ErrInvalidReceipt {
		t.Fatalf("expected ErrInvalidReceipt, got %v", err)
	}
}

func buildSelfSignedCertBase64(t *testing.T, key *ecdsa.PrivateKey) string {
	t.Helper()
	template := &x509.Certificate{
		SerialNumber: big.NewInt(1),
		NotBefore:    time.Now().UTC().Add(-time.Hour),
		NotAfter:     time.Now().UTC().Add(24 * time.Hour),
		KeyUsage:     x509.KeyUsageDigitalSignature,
	}
	der, err := x509.CreateCertificate(rand.Reader, template, template, &key.PublicKey, key)
	if err != nil {
		t.Fatalf("create cert: %v", err)
	}
	return base64.StdEncoding.EncodeToString(der)
}

func buildSignedTransactionInfo(t *testing.T, key *ecdsa.PrivateKey, certB64, productID string, expiresMS int64) string {
	t.Helper()
	headerJSON, _ := json.Marshal(map[string]any{
		"alg": "ES256",
		"typ": "JWT",
		"x5c": []string{certB64},
	})
	payloadJSON, _ := json.Marshal(map[string]any{
		"productId":   productID,
		"expiresDate": expiresMS,
	})
	header := base64.RawURLEncoding.EncodeToString(headerJSON)
	payload := base64.RawURLEncoding.EncodeToString(payloadJSON)
	signingInput := header + "." + payload

	hash := sha256.Sum256([]byte(signingInput))
	r, sigS, err := ecdsa.Sign(rand.Reader, key, hash[:])
	if err != nil {
		t.Fatalf("sign payload: %v", err)
	}
	signature := base64.RawURLEncoding.EncodeToString(joseConcatSignature(r, sigS, 32))
	return signingInput + "." + signature
}

func joseConcatSignature(r, s *big.Int, size int) []byte {
	rBytes := r.Bytes()
	sBytes := s.Bytes()
	res := make([]byte, size*2)
	copy(res[size-len(rBytes):size], rBytes)
	copy(res[size*2-len(sBytes):], sBytes)
	return res
}

func strPtr(s string) *string { return &s }

type fakeUserRepo struct {
	users map[string]*domain.User
}

func newFakeUserRepo() *fakeUserRepo {
	return &fakeUserRepo{users: make(map[string]*domain.User)}
}

func (r *fakeUserRepo) GetByID(ctx context.Context, id string) (*domain.User, error) {
	u, ok := r.users[id]
	if !ok {
		return nil, nil
	}
	return u, nil
}

func (r *fakeUserRepo) Create(ctx context.Context, u *domain.User) error {
	r.users[u.ID] = u
	return nil
}

func (r *fakeUserRepo) Update(ctx context.Context, u *domain.User) error {
	r.users[u.ID] = u
	return nil
}

func (r *fakeUserRepo) GetByEmail(ctx context.Context, email string) (*domain.User, error)     { return nil, nil }
func (r *fakeUserRepo) GetByGoogleID(ctx context.Context, googleID string) (*domain.User, error) { return nil, nil }
func (r *fakeUserRepo) LinkGoogleAccount(ctx context.Context, userID, googleID string) error { return nil }
func (r *fakeUserRepo) UnlinkGoogleAccount(ctx context.Context, userID string) error         { return nil }
func (r *fakeUserRepo) GetByAppleID(ctx context.Context, appleID string) (*domain.User, error) { return nil, nil }
func (r *fakeUserRepo) LinkAppleAccount(ctx context.Context, userID, appleID, email, name string) error {
	return nil
}
func (r *fakeUserRepo) UnlinkAppleAccount(ctx context.Context, userID string) error { return nil }
func (r *fakeUserRepo) ConsumeAiCredit(ctx context.Context, userID string) (bool, error)     { return true, nil }
func (r *fakeUserRepo) RefreshAiCredits(ctx context.Context, userID string, amount int) error { return nil }
