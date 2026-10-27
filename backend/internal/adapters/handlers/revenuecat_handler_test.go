package handlers

import (
	"bytes"
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strconv"
	"testing"
	"time"

	"github.com/gofiber/fiber/v2"
	"github.com/stretchr/testify/require"

	"pepinillo/backend/internal/domain"
	"pepinillo/backend/internal/services"
)

func makeTestRevenueCatApp(authToken string, userRepo *fakeUserRepository) (*fiber.App, *services.RevenueCatService) {
	rcService := services.NewRevenueCatService(userRepo, services.RevenueCatConfig{
		APIKey:           "test-api-key",
		WebhookAuthToken: authToken,
		APIBaseURL:       "https://api.revenuecat.com/v1",
	})
	handler := NewRevenueCatHandler(rcService)

	app := fiber.New(fiber.Config{
		ErrorHandler: ErrorHandler,
	})
	webhooks := app.Group("/api/v1/webhooks")
	webhooks.Post("/revenuecat", handler.Webhook)
	return app, rcService
}

func TestRevenueCatWebhook_Authentication(t *testing.T) {
	authToken := "test-secret-webhook-token-12345"
	userRepo := newFakeUserRepository()
	app, _ := makeTestRevenueCatApp(authToken, userRepo)

	t.Run("missing authorization header", func(t *testing.T) {
		req := httptest.NewRequest(http.MethodPost, "/api/v1/webhooks/revenuecat", bytes.NewReader([]byte(`{"event":{}}`)))
		req.Header.Set("Content-Type", "application/json")
		resp, err := app.Test(req)
		require.NoError(t, err)
		require.Equal(t, fiber.StatusUnauthorized, resp.StatusCode)

		var body map[string]string
		require.NoError(t, json.NewDecoder(resp.Body).Decode(&body))
		require.Equal(t, "invalid_webhook_auth", body["error"])
	})

	t.Run("invalid authorization token", func(t *testing.T) {
		req := httptest.NewRequest(http.MethodPost, "/api/v1/webhooks/revenuecat", bytes.NewReader([]byte(`{"event":{}}`)))
		req.Header.Set("Content-Type", "application/json")
		req.Header.Set("Authorization", "Bearer wrong-token")
		resp, err := app.Test(req)
		require.NoError(t, err)
		require.Equal(t, fiber.StatusUnauthorized, resp.StatusCode)

		var body map[string]string
		require.NoError(t, json.NewDecoder(resp.Body).Decode(&body))
		require.Equal(t, "invalid_webhook_auth", body["error"])
	})

	t.Run("valid authorization token with Bearer prefix", func(t *testing.T) {
		user := &domain.User{
			ID:               "user-rc-1",
			Email:            "rc-user@example.com",
			Name:             "RC User",
			SubscriptionTier: domain.TierFree,
		}
		require.NoError(t, userRepo.Create(context.Background(), user))

		payload := `{
			"api_version": "1.0",
			"event": {
				"type": "INITIAL_PURCHASE",
				"id": "evt-123",
				"app_user_id": "user-rc-1",
				"product_id": "com.pepinillo.app.pro.monthly",
				"entitlement_ids": ["everywhere_plus"],
				"expiration_at_ms": ` + strconv.FormatInt(time.Now().Add(30*24*time.Hour).UnixMilli(), 10) + `
			}
		}`

		req := httptest.NewRequest(http.MethodPost, "/api/v1/webhooks/revenuecat", bytes.NewReader([]byte(payload)))
		req.Header.Set("Content-Type", "application/json")
		req.Header.Set("Authorization", "Bearer "+authToken)
		resp, err := app.Test(req)
		require.NoError(t, err)
		require.Equal(t, fiber.StatusOK, resp.StatusCode)
	})

	t.Run("valid authorization token raw without Bearer prefix", func(t *testing.T) {
		payload := `{
			"api_version": "1.0",
			"event": {
				"type": "INITIAL_PURCHASE",
				"id": "evt-raw-1",
				"app_user_id": "user-rc-1",
				"product_id": "com.pepinillo.app.pro.monthly",
				"entitlement_ids": ["everywhere_plus"],
				"expiration_at_ms": 1900000000000
			}
		}`

		req := httptest.NewRequest(http.MethodPost, "/api/v1/webhooks/revenuecat", bytes.NewReader([]byte(payload)))
		req.Header.Set("Content-Type", "application/json")
		req.Header.Set("Authorization", authToken)
		resp, err := app.Test(req)
		require.NoError(t, err)
		require.Equal(t, fiber.StatusOK, resp.StatusCode)
	})

	t.Run("user not found returns 200 OK to prevent infinite retries", func(t *testing.T) {
		payload := `{
			"api_version": "1.0",
			"event": {
				"type": "INITIAL_PURCHASE",
				"id": "evt-anon-1",
				"app_user_id": "$RCAnonymousID:unregistered-client",
				"product_id": "com.pepinillo.app.pro.monthly",
				"entitlement_ids": ["everywhere_plus"]
			}
		}`

		req := httptest.NewRequest(http.MethodPost, "/api/v1/webhooks/revenuecat", bytes.NewReader([]byte(payload)))
		req.Header.Set("Content-Type", "application/json")
		req.Header.Set("Authorization", "Bearer "+authToken)
		resp, err := app.Test(req)
		require.NoError(t, err)
		require.Equal(t, fiber.StatusOK, resp.StatusCode)
	})
}

func TestRevenueCatWebhook_NotConfigured(t *testing.T) {
	userRepo := newFakeUserRepository()
	app, _ := makeTestRevenueCatApp("", userRepo)

	req := httptest.NewRequest(http.MethodPost, "/api/v1/webhooks/revenuecat", bytes.NewReader([]byte(`{"event":{}}`)))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer any-token")
	resp, err := app.Test(req)
	require.NoError(t, err)
	require.Equal(t, fiber.StatusServiceUnavailable, resp.StatusCode)

	var body map[string]string
	require.NoError(t, json.NewDecoder(resp.Body).Decode(&body))
	require.Equal(t, "webhook_not_configured", body["error"])
}
