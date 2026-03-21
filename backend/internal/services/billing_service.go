package services

import (
	"bytes"
	"context"
	"crypto"
	"crypto/ecdsa"
	"crypto/rand"
	"crypto/rsa"
	"crypto/sha256"
	"crypto/x509"
	"encoding/base64"
	"encoding/json"
	"encoding/pem"
	"errors"
	"fmt"
	"math/big"
	"net/http"
	"net/url"
	"strconv"
	"strings"
	"sync"
	"time"

	"pepinillo/backend/internal/ports"
)

var (
	ErrInvalidBillingPlatform       = errors.New("invalid_billing_platform")
	ErrInvalidBillingPayload        = errors.New("invalid_billing_payload")
	ErrUnsupportedProductID         = errors.New("unsupported_product_id")
	ErrBillingProviderNotConfigured = errors.New("billing_provider_not_configured")
	ErrInvalidReceipt               = errors.New("invalid_receipt")
)

type VerifyReceiptInput struct {
	Platform      string `json:"platform"`
	ProductID     string `json:"productId"`
	PurchaseToken string `json:"purchaseToken"`
	TransactionID string `json:"transactionId"`
	ReceiptData   string `json:"receiptData"`
}

type VerifyReceiptResult struct {
	Valid                 bool       `json:"valid"`
	SubscriptionTier      string     `json:"subscriptionTier"`
	SubscriptionExpiresAt *time.Time `json:"subscriptionExpiresAt"`
	Source                string     `json:"source"`
}

type BillingConfig struct {
	GooglePlayPackageName              string
	GooglePlayAPIToken                 string
	GooglePlayAPIBaseURL               string
	GooglePlayServiceAccountEmail      string
	GooglePlayServiceAccountPrivateKey string
	GooglePlayOAuthTokenURL            string
	GooglePlayOAuthScope               string
	AppStoreSharedSecret               string
	AppStoreVerifyReceiptURL           string
	AppStoreSandboxVerifyReceiptURL    string
	AppStoreServerAPIIssuerID          string
	AppStoreServerAPIKeyID             string
	AppStoreServerAPIPrivateKey        string
	AppStoreServerAPIBundleID          string
	AppStoreServerAPIBaseURL           string
}

type BillingService struct {
	users      ports.UserRepository
	behavior   ports.BehaviorLogger
	httpClient *http.Client
	cfg        BillingConfig
	revenuecat *RevenueCatService

	googleTokenMu        sync.Mutex
	googleAccessToken    string
	googleAccessTokenExp time.Time
}

func NewBillingService(users ports.UserRepository, cfg BillingConfig, behavior ...ports.BehaviorLogger) *BillingService {
	cfg.GooglePlayAPIBaseURL = strings.TrimSuffix(cfg.GooglePlayAPIBaseURL, "/")
	cfg.GooglePlayOAuthTokenURL = strings.TrimSuffix(cfg.GooglePlayOAuthTokenURL, "/")
	cfg.AppStoreVerifyReceiptURL = strings.TrimSuffix(cfg.AppStoreVerifyReceiptURL, "/")
	cfg.AppStoreSandboxVerifyReceiptURL = strings.TrimSuffix(cfg.AppStoreSandboxVerifyReceiptURL, "/")
	cfg.AppStoreServerAPIBaseURL = strings.TrimSuffix(cfg.AppStoreServerAPIBaseURL, "/")

	var behaviorLogger ports.BehaviorLogger
	if len(behavior) > 0 {
		behaviorLogger = behavior[0]
	}

	return &BillingService{
		users:      users,
		behavior:   behaviorLogger,
		httpClient: &http.Client{Timeout: 10 * time.Second},
		cfg:        cfg,
	}
}

func (s *BillingService) VerifyReceipt(ctx context.Context, userID string, input VerifyReceiptInput) (*VerifyReceiptResult, error) {
	startedAt := time.Now().UTC()
	platform := strings.ToLower(strings.TrimSpace(input.Platform))
	if platform != "android" && platform != "ios" {
		s.logBillingEvent(ctx, userID, "billing_verify_failed", map[string]any{"reason": ErrInvalidBillingPlatform.Error(), "platform": platform})
		return nil, ErrInvalidBillingPlatform
	}
	if strings.TrimSpace(input.ProductID) == "" {
		s.logBillingEvent(ctx, userID, "billing_verify_failed", map[string]any{"reason": ErrInvalidBillingPayload.Error(), "platform": platform})
		return nil, ErrInvalidBillingPayload
	}

	var (
		validProductID string
		expiresAt      *time.Time
		source         string
		err            error
	)

	switch platform {
	case "android":
		validProductID, expiresAt, err = s.verifyGooglePlayReceipt(ctx, input)
		source = "google_play"
	case "ios":
		validProductID, expiresAt, source, err = s.verifyIOSReceipt(ctx, input)
	}
	if err != nil {
		s.logBillingEvent(ctx, userID, "billing_verify_failed", map[string]any{
			"reason":     err.Error(),
			"platform":   platform,
			"source":     source,
			"durationMs": time.Since(startedAt).Milliseconds(),
		})
		return nil, err
	}

	tier, mappedExpiresAt, err := mapProductToTier(validProductID, expiresAt)
	if err != nil {
		s.logBillingEvent(ctx, userID, "billing_verify_failed", map[string]any{
			"reason":     err.Error(),
			"platform":   platform,
			"source":     source,
			"durationMs": time.Since(startedAt).Milliseconds(),
		})
		return nil, err
	}

	user, err := s.users.GetByID(ctx, userID)
	if err != nil {
		s.logBillingEvent(ctx, userID, "billing_verify_failed", map[string]any{
			"reason":     err.Error(),
			"platform":   platform,
			"source":     source,
			"durationMs": time.Since(startedAt).Milliseconds(),
		})
		return nil, err
	}
	if user == nil {
		s.logBillingEvent(ctx, userID, "billing_verify_failed", map[string]any{
			"reason":     ErrUserNotFound.Error(),
			"platform":   platform,
			"source":     source,
			"durationMs": time.Since(startedAt).Milliseconds(),
		})
		return nil, ErrUserNotFound
	}

	user.SubscriptionTier = tier
	user.SubscriptionExpiresAt = mappedExpiresAt
	if err := s.users.Update(ctx, user); err != nil {
		s.logBillingEvent(ctx, userID, "billing_verify_failed", map[string]any{
			"reason":     err.Error(),
			"platform":   platform,
			"source":     source,
			"durationMs": time.Since(startedAt).Milliseconds(),
		})
		return nil, err
	}

	s.logBillingEvent(ctx, userID, "billing_verify_succeeded", map[string]any{
		"platform":   platform,
		"source":     source,
		"tier":       tier,
		"durationMs": time.Since(startedAt).Milliseconds(),
	})

	return &VerifyReceiptResult{
		Valid:                 true,
		SubscriptionTier:      tier,
		SubscriptionExpiresAt: mappedExpiresAt,
		Source:                source,
	}, nil
}

func (s *BillingService) logBillingEvent(ctx context.Context, userID, eventType string, eventData map[string]any) {
	if s.behavior == nil {
		return
	}
	_ = s.behavior.LogEvent(ctx, userID, eventType, eventData)
}

func (s *BillingService) verifyIOSReceipt(ctx context.Context, input VerifyReceiptInput) (string, *time.Time, string, error) {
	if strings.TrimSpace(input.TransactionID) != "" && s.isAppStoreServerAPIConfigured() {
		productID, expiresAt, err := s.verifyAppStoreServerAPI(ctx, input)
		if err == nil {
			return productID, expiresAt, "app_store_server_api", nil
		}
		if !errors.Is(err, ErrBillingProviderNotConfigured) && !errors.Is(err, ErrInvalidBillingPayload) {
			return "", nil, "", err
		}
	}

	productID, expiresAt, err := s.verifyAppStoreReceipt(ctx, input)
	if err != nil {
		return "", nil, "", err
	}
	return productID, expiresAt, "app_store", nil
}

type googleSubscriptionResponse struct {
	ExpiryTimeMillis string `json:"expiryTimeMillis"`
	CancelReason     *int   `json:"cancelReason"`
}

func (s *BillingService) verifyGooglePlayReceipt(ctx context.Context, input VerifyReceiptInput) (string, *time.Time, error) {
	if strings.TrimSpace(input.PurchaseToken) == "" {
		return "", nil, ErrInvalidBillingPayload
	}
	if s.cfg.GooglePlayPackageName == "" || s.cfg.GooglePlayAPIBaseURL == "" {
		return "", nil, ErrBillingProviderNotConfigured
	}

	accessToken, err := s.googlePlayAccessToken(ctx)
	if err != nil {
		return "", nil, err
	}

	endpoint := fmt.Sprintf(
		"%s/androidpublisher/v3/applications/%s/purchases/subscriptions/%s/tokens/%s",
		s.cfg.GooglePlayAPIBaseURL,
		url.PathEscape(s.cfg.GooglePlayPackageName),
		url.PathEscape(input.ProductID),
		url.PathEscape(input.PurchaseToken),
	)

	req, err := http.NewRequestWithContext(ctx, http.MethodGet, endpoint, nil)
	if err != nil {
		return "", nil, err
	}
	req.Header.Set("Authorization", "Bearer "+accessToken)

	resp, err := s.httpClient.Do(req)
	if err != nil {
		return "", nil, err
	}
	defer resp.Body.Close()

	if resp.StatusCode == http.StatusUnauthorized || resp.StatusCode == http.StatusForbidden {
		return "", nil, ErrBillingProviderNotConfigured
	}
	if resp.StatusCode == http.StatusNotFound || resp.StatusCode == http.StatusBadRequest {
		return "", nil, ErrInvalidReceipt
	}
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return "", nil, fmt.Errorf("google_play_verification_failed: status_%d", resp.StatusCode)
	}

	var payload googleSubscriptionResponse
	if err := json.NewDecoder(resp.Body).Decode(&payload); err != nil {
		return "", nil, err
	}
	if payload.CancelReason != nil {
		return "", nil, ErrInvalidReceipt
	}
	if payload.ExpiryTimeMillis == "" {
		return "", nil, ErrInvalidReceipt
	}
	ms, err := strconv.ParseInt(payload.ExpiryTimeMillis, 10, 64)
	if err != nil {
		return "", nil, ErrInvalidReceipt
	}
	expiresAt := time.UnixMilli(ms).UTC()
	if !expiresAt.After(time.Now().UTC()) {
		return "", nil, ErrInvalidReceipt
	}

	return input.ProductID, &expiresAt, nil
}

func (s *BillingService) googlePlayAccessToken(ctx context.Context) (string, error) {
	if strings.TrimSpace(s.cfg.GooglePlayAPIToken) != "" {
		return s.cfg.GooglePlayAPIToken, nil
	}
	if strings.TrimSpace(s.cfg.GooglePlayServiceAccountEmail) == "" || strings.TrimSpace(s.cfg.GooglePlayServiceAccountPrivateKey) == "" || strings.TrimSpace(s.cfg.GooglePlayOAuthTokenURL) == "" || strings.TrimSpace(s.cfg.GooglePlayOAuthScope) == "" {
		return "", ErrBillingProviderNotConfigured
	}

	s.googleTokenMu.Lock()
	defer s.googleTokenMu.Unlock()

	if s.googleAccessToken != "" && time.Now().UTC().Before(s.googleAccessTokenExp.Add(-time.Minute)) {
		return s.googleAccessToken, nil
	}

	assertion, err := s.buildGoogleServiceAccountJWT()
	if err != nil {
		return "", ErrBillingProviderNotConfigured
	}

	form := url.Values{}
	form.Set("grant_type", "urn:ietf:params:oauth:grant-type:jwt-bearer")
	form.Set("assertion", assertion)

	req, err := http.NewRequestWithContext(ctx, http.MethodPost, s.cfg.GooglePlayOAuthTokenURL, strings.NewReader(form.Encode()))
	if err != nil {
		return "", err
	}
	req.Header.Set("Content-Type", "application/x-www-form-urlencoded")

	resp, err := s.httpClient.Do(req)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()

	if resp.StatusCode == http.StatusUnauthorized || resp.StatusCode == http.StatusForbidden || resp.StatusCode == http.StatusBadRequest {
		return "", ErrBillingProviderNotConfigured
	}
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return "", fmt.Errorf("google_oauth_failed: status_%d", resp.StatusCode)
	}

	var payload struct {
		AccessToken string `json:"access_token"`
		ExpiresIn   int    `json:"expires_in"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&payload); err != nil {
		return "", err
	}
	if payload.AccessToken == "" {
		return "", ErrBillingProviderNotConfigured
	}

	expiresIn := payload.ExpiresIn
	if expiresIn <= 0 {
		expiresIn = 3600
	}
	s.googleAccessToken = payload.AccessToken
	s.googleAccessTokenExp = time.Now().UTC().Add(time.Duration(expiresIn) * time.Second)

	return s.googleAccessToken, nil
}

func (s *BillingService) buildGoogleServiceAccountJWT() (string, error) {
	privateKey, err := parseRSAPrivateKey(s.cfg.GooglePlayServiceAccountPrivateKey)
	if err != nil {
		return "", err
	}

	now := time.Now().UTC()
	header := map[string]any{"alg": "RS256", "typ": "JWT"}
	claims := map[string]any{
		"iss":   s.cfg.GooglePlayServiceAccountEmail,
		"scope": s.cfg.GooglePlayOAuthScope,
		"aud":   s.cfg.GooglePlayOAuthTokenURL,
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

func (s *BillingService) isAppStoreServerAPIConfigured() bool {
	return strings.TrimSpace(s.cfg.AppStoreServerAPIIssuerID) != "" &&
		strings.TrimSpace(s.cfg.AppStoreServerAPIKeyID) != "" &&
		strings.TrimSpace(s.cfg.AppStoreServerAPIPrivateKey) != "" &&
		strings.TrimSpace(s.cfg.AppStoreServerAPIBundleID) != "" &&
		strings.TrimSpace(s.cfg.AppStoreServerAPIBaseURL) != ""
}

type appStoreServerSubscriptionResponse struct {
	Data []struct {
		LastTransactions []struct {
			SignedTransactionInfo string `json:"signedTransactionInfo"`
		} `json:"lastTransactions"`
	} `json:"data"`
}

func (s *BillingService) verifyAppStoreServerAPI(ctx context.Context, input VerifyReceiptInput) (string, *time.Time, error) {
	if strings.TrimSpace(input.TransactionID) == "" {
		return "", nil, ErrInvalidBillingPayload
	}
	if !s.isAppStoreServerAPIConfigured() {
		return "", nil, ErrBillingProviderNotConfigured
	}

	token, err := s.buildAppStoreServerAPIJWT()
	if err != nil {
		return "", nil, ErrBillingProviderNotConfigured
	}

	endpoint := fmt.Sprintf("%s/inApps/v1/subscriptions/%s", s.cfg.AppStoreServerAPIBaseURL, url.PathEscape(strings.TrimSpace(input.TransactionID)))
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, endpoint, nil)
	if err != nil {
		return "", nil, err
	}
	req.Header.Set("Authorization", "Bearer "+token)

	resp, err := s.httpClient.Do(req)
	if err != nil {
		return "", nil, err
	}
	defer resp.Body.Close()

	if resp.StatusCode == http.StatusUnauthorized || resp.StatusCode == http.StatusForbidden {
		return "", nil, ErrBillingProviderNotConfigured
	}
	if resp.StatusCode == http.StatusNotFound || resp.StatusCode == http.StatusBadRequest {
		return "", nil, ErrInvalidReceipt
	}
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return "", nil, fmt.Errorf("app_store_server_api_failed: status_%d", resp.StatusCode)
	}

	var payload appStoreServerSubscriptionResponse
	if err := json.NewDecoder(resp.Body).Decode(&payload); err != nil {
		return "", nil, err
	}

	productID, expiresAt, ok := extractLatestSignedTransaction(payload)
	if !ok {
		return "", nil, ErrInvalidReceipt
	}
	if expiresAt != nil && !expiresAt.After(time.Now().UTC()) {
		return "", nil, ErrInvalidReceipt
	}
	return productID, expiresAt, nil
}

func (s *BillingService) buildAppStoreServerAPIJWT() (string, error) {
	privateKey, err := parseECDSAPrivateKey(s.cfg.AppStoreServerAPIPrivateKey)
	if err != nil {
		return "", err
	}
	now := time.Now().UTC()

	header := map[string]any{
		"alg": "ES256",
		"kid": s.cfg.AppStoreServerAPIKeyID,
		"typ": "JWT",
	}
	claims := map[string]any{
		"iss": s.cfg.AppStoreServerAPIIssuerID,
		"iat": now.Unix(),
		"exp": now.Add(5 * time.Minute).Unix(),
		"aud": "appstoreconnect-v1",
		"bid": s.cfg.AppStoreServerAPIBundleID,
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
	r, sigS, err := ecdsa.Sign(rand.Reader, privateKey, hash[:])
	if err != nil {
		return "", err
	}
	signature := joseConcatSignature(r, sigS, 32)
	return signingInput + "." + enc.EncodeToString(signature), nil
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

func joseConcatSignature(r, sigS *big.Int, size int) []byte {
	out := make([]byte, size*2)
	rb := r.Bytes()
	sb := sigS.Bytes()
	copy(out[size-len(rb):size], rb)
	copy(out[(size*2)-len(sb):], sb)
	return out
}

func extractLatestSignedTransaction(payload appStoreServerSubscriptionResponse) (string, *time.Time, bool) {
	var (
		bestProduct string
		bestExpires *time.Time
	)

	for _, item := range payload.Data {
		for _, tx := range item.LastTransactions {
			productID, expiresAt, ok := parseSignedTransactionInfo(tx.SignedTransactionInfo)
			if !ok || productID == "" {
				continue
			}
			if bestExpires == nil || (expiresAt != nil && expiresAt.After(*bestExpires)) {
				bestProduct = productID
				bestExpires = expiresAt
			}
		}
	}
	if bestProduct == "" {
		return "", nil, false
	}
	return bestProduct, bestExpires, true
}

func parseSignedTransactionInfo(signedInfo string) (string, *time.Time, bool) {
	payloadRaw, err := verifyAndDecodeAppStoreSignedTransactionJWS(signedInfo)
	if err != nil {
		return "", nil, false
	}

	var payload struct {
		ProductID   string `json:"productId"`
		ExpiresDate int64  `json:"expiresDate"`
	}
	if err := json.Unmarshal(payloadRaw, &payload); err != nil {
		return "", nil, false
	}
	if payload.ProductID == "" {
		return "", nil, false
	}
	if payload.ExpiresDate <= 0 {
		return payload.ProductID, nil, true
	}
	expiresAt := time.UnixMilli(payload.ExpiresDate).UTC()
	return payload.ProductID, &expiresAt, true
}

func verifyAndDecodeAppStoreSignedTransactionJWS(signedInfo string) ([]byte, error) {
	parts := strings.Split(signedInfo, ".")
	if len(parts) != 3 {
		return nil, errors.New("invalid_jws_parts")
	}

	headerRaw, err := base64.RawURLEncoding.DecodeString(parts[0])
	if err != nil {
		return nil, err
	}
	var header struct {
		Alg string   `json:"alg"`
		X5C []string `json:"x5c"`
	}
	if err := json.Unmarshal(headerRaw, &header); err != nil {
		return nil, err
	}
	if strings.ToUpper(strings.TrimSpace(header.Alg)) != "ES256" {
		return nil, errors.New("invalid_jws_alg")
	}
	if len(header.X5C) == 0 || strings.TrimSpace(header.X5C[0]) == "" {
		return nil, errors.New("missing_jws_x5c")
	}

	certDER, err := base64.StdEncoding.DecodeString(header.X5C[0])
	if err != nil {
		certDER, err = base64.RawStdEncoding.DecodeString(header.X5C[0])
		if err != nil {
			return nil, err
		}
	}
	cert, err := x509.ParseCertificate(certDER)
	if err != nil {
		return nil, err
	}
	if time.Now().UTC().Before(cert.NotBefore.UTC()) || time.Now().UTC().After(cert.NotAfter.UTC()) {
		return nil, errors.New("jws_certificate_not_valid_now")
	}
	publicKey, ok := cert.PublicKey.(*ecdsa.PublicKey)
	if !ok {
		return nil, errors.New("jws_certificate_public_key_not_ecdsa")
	}

	signatureRaw, err := base64.RawURLEncoding.DecodeString(parts[2])
	if err != nil {
		return nil, err
	}
	if len(signatureRaw) != 64 {
		return nil, errors.New("invalid_jws_signature_length")
	}

	signingInput := parts[0] + "." + parts[1]
	hash := sha256.Sum256([]byte(signingInput))
	r := new(big.Int).SetBytes(signatureRaw[:32])
	sigS := new(big.Int).SetBytes(signatureRaw[32:])
	if !ecdsa.Verify(publicKey, hash[:], r, sigS) {
		return nil, errors.New("invalid_jws_signature")
	}

	payloadRaw, err := base64.RawURLEncoding.DecodeString(parts[1])
	if err != nil {
		return nil, err
	}
	return payloadRaw, nil
}

type appStoreVerifyResponse struct {
	Status            int `json:"status"`
	LatestReceiptInfo []struct {
		ProductID     string `json:"product_id"`
		ExpiresDateMS string `json:"expires_date_ms"`
	} `json:"latest_receipt_info"`
	Receipt struct {
		InApp []struct {
			ProductID     string `json:"product_id"`
			ExpiresDateMS string `json:"expires_date_ms"`
		} `json:"in_app"`
	} `json:"receipt"`
}

func (s *BillingService) verifyAppStoreReceipt(ctx context.Context, input VerifyReceiptInput) (string, *time.Time, error) {
	if strings.TrimSpace(input.ReceiptData) == "" {
		return "", nil, ErrInvalidBillingPayload
	}
	if s.cfg.AppStoreSharedSecret == "" || s.cfg.AppStoreVerifyReceiptURL == "" || s.cfg.AppStoreSandboxVerifyReceiptURL == "" {
		return "", nil, ErrBillingProviderNotConfigured
	}

	payload := map[string]any{
		"receipt-data":             input.ReceiptData,
		"password":                 s.cfg.AppStoreSharedSecret,
		"exclude-old-transactions": true,
	}

	response, err := s.callAppStoreVerify(ctx, s.cfg.AppStoreVerifyReceiptURL, payload)
	if err != nil {
		return "", nil, err
	}
	if response.Status == 21007 {
		response, err = s.callAppStoreVerify(ctx, s.cfg.AppStoreSandboxVerifyReceiptURL, payload)
		if err != nil {
			return "", nil, err
		}
	}

	if response.Status != 0 {
		return "", nil, ErrInvalidReceipt
	}

	productID, expiresAt, ok := extractLatestAppStoreSubscription(response)
	if !ok {
		return input.ProductID, nil, nil
	}
	return productID, expiresAt, nil
}

func (s *BillingService) callAppStoreVerify(ctx context.Context, endpoint string, payload map[string]any) (*appStoreVerifyResponse, error) {
	body, err := json.Marshal(payload)
	if err != nil {
		return nil, err
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodPost, endpoint, bytes.NewReader(body))
	if err != nil {
		return nil, err
	}
	req.Header.Set("Content-Type", "application/json")

	resp, err := s.httpClient.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return nil, fmt.Errorf("app_store_verification_failed: status_%d", resp.StatusCode)
	}

	var parsed appStoreVerifyResponse
	if err := json.NewDecoder(resp.Body).Decode(&parsed); err != nil {
		return nil, err
	}
	return &parsed, nil
}

func extractLatestAppStoreSubscription(response *appStoreVerifyResponse) (string, *time.Time, bool) {
	type row struct {
		ProductID string
		ExpiresMS string
	}
	records := make([]row, 0, len(response.LatestReceiptInfo)+len(response.Receipt.InApp))
	for _, item := range response.LatestReceiptInfo {
		records = append(records, row{ProductID: item.ProductID, ExpiresMS: item.ExpiresDateMS})
	}
	for _, item := range response.Receipt.InApp {
		records = append(records, row{ProductID: item.ProductID, ExpiresMS: item.ExpiresDateMS})
	}
	if len(records) == 0 {
		return "", nil, false
	}

	var (
		bestProduct string
		bestExpires *time.Time
	)
	for _, rec := range records {
		if rec.ProductID == "" || rec.ExpiresMS == "" {
			continue
		}
		ms, err := strconv.ParseInt(rec.ExpiresMS, 10, 64)
		if err != nil {
			continue
		}
		expires := time.UnixMilli(ms).UTC()
		if bestExpires == nil || expires.After(*bestExpires) {
			best := expires
			bestProduct = rec.ProductID
			bestExpires = &best
		}
	}
	if bestProduct == "" {
		return "", nil, false
	}
	return bestProduct, bestExpires, true
}

func mapProductToTier(productID string, expiresAt *time.Time) (string, *time.Time, error) {
	product := strings.ToLower(strings.TrimSpace(productID))
	if product == "" {
		return "", nil, ErrUnsupportedProductID
	}

	switch {
	case strings.Contains(product, "lifetime"):
		return "lifetime", nil, nil
	case strings.Contains(product, "annual"), strings.Contains(product, "yearly"):
		if expiresAt == nil {
			return "", nil, ErrInvalidReceipt
		}
		return "pro_yearly", expiresAt, nil
	case strings.Contains(product, "monthly"), strings.Contains(product, "month"):
		if expiresAt == nil {
			return "", nil, ErrInvalidReceipt
		}
		return "pro_monthly", expiresAt, nil
	default:
		return "", nil, ErrUnsupportedProductID
	}
}
