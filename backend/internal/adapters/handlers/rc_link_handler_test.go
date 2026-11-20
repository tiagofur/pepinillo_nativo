package handlers

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/gofiber/fiber/v2"
	"github.com/stretchr/testify/require"

	"pepinillo/backend/internal/adapters/stores/memory"
	"pepinillo/backend/internal/domain"
	"pepinillo/backend/internal/services"
)

// rcLinkRestServer fakes the RevenueCat REST /subscribers/{id} endpoint for
// handler-level tests (services-package tests have their own copy).
func rcLinkRestServer(subscribers map[string]string) *httptest.Server {
	return httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		body, ok := subscribers[r.URL.Path]
		if !ok {
			w.WriteHeader(http.StatusNotFound)
			return
		}
		w.Header().Set("Content-Type", "application/json")
		_, _ = w.Write([]byte(body))
	}))
}

// makeTestRcLinkApp wires the claim endpoint against an httptest RC REST
// server. CreateCode (web-side, JWT-guarded) is exercised through the
// returned service so the happy path covers the full claim flow.
func makeTestRcLinkApp(t *testing.T, subscribers map[string]string) (*fiber.App, *services.RcLinkService, *fakeUserRepository) {
	t.Helper()
	srv := rcLinkRestServer(subscribers)
	t.Cleanup(srv.Close)

	userRepo := newFakeUserRepository()
	rcService := services.NewRevenueCatService(userRepo, services.RevenueCatConfig{
		APIKey:     "test-api-key",
		APIBaseURL: srv.URL,
	})
	linkService := services.NewRcLinkService(userRepo, memory.NewAuthStore(), rcService)
	handler := NewRcLinkHandler(linkService)

	app := fiber.New(fiber.Config{ErrorHandler: ErrorHandler})
	rc := app.Group("/api/v1/rc")
	rc.Post("/link", handler.Claim)
	return app, linkService, userRepo
}

func TestRcLinkClaim_MapsServiceErrors(t *testing.T) {
	app, linkService, userRepo := makeTestRcLinkApp(t, map[string]string{
		"/subscribers/$RCAnonymousID:plus": `{"subscriber":{"entitlements":{"pepinillo_plus":{"expires_date":null}},"subscriptions":{}}}`,
		"/subscribers/$RCAnonymousID:free": `{"subscriber":{"entitlements":{},"subscriptions":{}}}`,
	})
	require.NoError(t, userRepo.Create(t.Context(), &domain.User{
		ID:               "user-link-1",
		Email:            "link@example.com",
		SubscriptionTier: domain.TierFree,
	}))

	t.Run("malformed body is 400", func(t *testing.T) {
		req := httptest.NewRequest(http.MethodPost, "/api/v1/rc/link", bytes.NewReader([]byte(`not-json`)))
		req.Header.Set("Content-Type", "application/json")
		resp, err := app.Test(req)
		require.NoError(t, err)
		require.Equal(t, fiber.StatusBadRequest, resp.StatusCode)
	})

	t.Run("bad code and absent entitlement share one 404", func(t *testing.T) {
		for _, body := range []string{
			`{"code":"000000","appUserId":"$RCAnonymousID:plus"}`,
			`{"code":"123456","appUserId":"$RCAnonymousID:free"}`,
		} {
			req := httptest.NewRequest(http.MethodPost, "/api/v1/rc/link", bytes.NewReader([]byte(body)))
			req.Header.Set("Content-Type", "application/json")
			resp, err := app.Test(req)
			require.NoError(t, err)
			require.Equal(t, fiber.StatusNotFound, resp.StatusCode)

			var errBody map[string]string
			require.NoError(t, json.NewDecoder(resp.Body).Decode(&errBody))
			require.Equal(t, "rc_link_not_claimable", errBody["error"])
		}
	})

	t.Run("valid claim binds and returns userId and tier", func(t *testing.T) {
		code, _, err := linkService.CreateLinkCode(t.Context(), "user-link-1")
		require.NoError(t, err)

		payload, _ := json.Marshal(map[string]string{"code": code, "appUserId": "$RCAnonymousID:plus"})
		req := httptest.NewRequest(http.MethodPost, "/api/v1/rc/link", bytes.NewReader(payload))
		req.Header.Set("Content-Type", "application/json")
		resp, err := app.Test(req)
		require.NoError(t, err)
		require.Equal(t, fiber.StatusOK, resp.StatusCode)

		var body map[string]any
		require.NoError(t, json.NewDecoder(resp.Body).Decode(&body))
		require.Equal(t, "user-link-1", body["userId"])
		require.Equal(t, "pepinillo_plus", body["tier"])
	})
}
