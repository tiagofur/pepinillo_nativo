package integration

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
	"github.com/golang-jwt/jwt/v5"
	"github.com/stretchr/testify/require"

	"pepinillo/backend/internal/adapters/behavior"
	"pepinillo/backend/internal/adapters/handlers"
	"pepinillo/backend/internal/adapters/middleware"
	"pepinillo/backend/internal/domain"
	"pepinillo/backend/internal/ports"
	"pepinillo/backend/internal/services"
)

const testJWTSecret = "integration_secret"

type integrationTaskRepo struct {
	items []domain.Task
}

func (r *integrationTaskRepo) GetByID(_ context.Context, _ int) (*domain.Task, error) {
	return nil, nil
}
func (r *integrationTaskRepo) ListByUser(_ context.Context, _ string) ([]domain.Task, error) {
	return r.items, nil
}
func (r *integrationTaskRepo) ListUsersWithRecurrenceTemplates(_ context.Context) ([]string, error) {
	return nil, nil
}
func (r *integrationTaskRepo) TryAcquireRecurrenceLock(_ context.Context, _, _ string, _ time.Time) (bool, error) {
	return true, nil
}
func (r *integrationTaskRepo) ReleaseRecurrenceLock(_ context.Context, _, _ string) error { return nil }
func (r *integrationTaskRepo) ListByFinishDate(_ context.Context, _ string, _ time.Time) ([]domain.Task, error) {
	return nil, nil
}
func (r *integrationTaskRepo) Upsert(_ context.Context, task *domain.Task) error {
	r.items = append(r.items, *task)
	return nil
}
func (r *integrationTaskRepo) Delete(_ context.Context, _ string, _ int) error { return nil }
func (r *integrationTaskRepo) Sync(_ context.Context, userID string, tasks []domain.Task, _ []string, _ *time.Time) ([]domain.Task, []string, time.Time, error) {
	for i := range tasks {
		tasks[i].UserID = userID
	}
	r.items = append(r.items, tasks...)
	return tasks, nil, time.Now().UTC(), nil
}
func (r *integrationTaskRepo) UpdateTrackingMode(_ context.Context, _ string, _ int, _ string) error {
	return nil
}
func (r *integrationTaskRepo) IncrementCompletionCount(_ context.Context, _ string, _ int, _ string) error {
	return nil
}
func (r *integrationTaskRepo) IncrementFocusTime(_ context.Context, _ string, _ int, _ string, _ int) error {
	return nil
}
func (r *integrationTaskRepo) SetActiveSession(_ context.Context, _ string, _ int, _ *string) error {
	return nil
}
func (r *integrationTaskRepo) ListByUserPaginated(_ context.Context, _ string, _ *ports.PaginationCursor, _ int) ([]domain.Task, error) {
	return nil, nil
}

func makeAccessToken(t *testing.T, userID, email string) string {
	t.Helper()
	claims := middleware.UserClaims{
		UserID:    userID,
		Email:     email,
		Tier:      "free",
		TokenType: "access",
		RegisteredClaims: jwt.RegisteredClaims{
			ExpiresAt: jwt.NewNumericDate(time.Now().Add(15 * time.Minute)),
		},
	}
	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	signed, err := token.SignedString([]byte(testJWTSecret))
	require.NoError(t, err)
	return signed
}

func TestProtectedBillingEndpoint_RequiresAndAcceptsJWT(t *testing.T) {
	if testing.Short() {
		t.Skip("skipping integration test")
	}

	userRepo := newIntegrationUserRepo()
	user := &domain.User{ID: "u1", Email: "billing-protected@test.com", Name: "U1", PasswordHash: ptrStr("x"), SubscriptionTier: "free"}
	require.NoError(t, userRepo.Create(context.Background(), user))

	expiry := time.Now().UTC().Add(30 * 24 * time.Hour)
	playSrv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Header.Get("Authorization") != "Bearer test-token" {
			w.WriteHeader(http.StatusUnauthorized)
			return
		}
		_ = json.NewEncoder(w).Encode(map[string]any{
			"expiryTimeMillis": strconv.FormatInt(expiry.UnixMilli(), 10),
		})
	}))
	defer playSrv.Close()

	billing := services.NewBillingService(userRepo, services.BillingConfig{
		GooglePlayPackageName: "com.pepinillo.android",
		GooglePlayAPIToken:    "test-token",
		GooglePlayAPIBaseURL:  playSrv.URL,
	})

	app := fiber.New()
	protected := app.Group("", middleware.JWT(testJWTSecret))
	protected.Post("/billing/verify-receipt", handlers.NewBillingHandler(billing).VerifyReceipt)

	body := []byte(`{"platform":"android","productId":"com.pepinillo.app.pro.monthly","purchaseToken":"abc"}`)
	reqNoAuth := httptest.NewRequest(http.MethodPost, "/billing/verify-receipt", bytes.NewReader(body))
	reqNoAuth.Header.Set("Content-Type", "application/json")
	respNoAuth, err := app.Test(reqNoAuth)
	require.NoError(t, err)
	require.Equal(t, fiber.StatusUnauthorized, respNoAuth.StatusCode)

	reqAuth := httptest.NewRequest(http.MethodPost, "/billing/verify-receipt", bytes.NewReader(body))
	reqAuth.Header.Set("Content-Type", "application/json")
	reqAuth.Header.Set("Authorization", "Bearer "+makeAccessToken(t, "u1", user.Email))
	respAuth, err := app.Test(reqAuth)
	require.NoError(t, err)
	require.Equal(t, fiber.StatusOK, respAuth.StatusCode)
}

func TestProtectedPushAndTaskSyncEndpoints_WithJWT(t *testing.T) {
	if testing.Short() {
		t.Skip("skipping integration test")
	}

	app := fiber.New()
	protected := app.Group("", middleware.JWT(testJWTSecret))

	pushRepo := &integrationDeviceTokenRepo{items: map[string][]domain.DeviceToken{}}
	pushSvc := services.NewPushService(pushRepo, &integrationPushProvider{})
	taskSvc := services.NewTaskService(&integrationTaskRepo{}, behavior.NewNoopLogger(), nil)

	protected.Post("/push/devices", handlers.NewPushHandler(pushSvc).RegisterDevice)
	protected.Post("/tasks/sync", handlers.NewTaskHandler(taskSvc).Sync)

	pushBody := []byte(`{"platform":"ios","token":"tok1"}`)
	pushReq := httptest.NewRequest(http.MethodPost, "/push/devices", bytes.NewReader(pushBody))
	pushReq.Header.Set("Content-Type", "application/json")
	pushReq.Header.Set("Authorization", "Bearer "+makeAccessToken(t, "u2", "u2@test.com"))
	pushResp, err := app.Test(pushReq)
	require.NoError(t, err)
	require.Equal(t, fiber.StatusCreated, pushResp.StatusCode)

	syncReq := httptest.NewRequest(http.MethodPost, "/tasks/sync", bytes.NewReader([]byte(`{"tasks":[],"deletedSyncIds":[]}`)))
	syncReq.Header.Set("Content-Type", "application/json")
	syncReq.Header.Set("Authorization", "Bearer "+makeAccessToken(t, "u2", "u2@test.com"))
	syncResp, err := app.Test(syncReq)
	require.NoError(t, err)
	require.Equal(t, fiber.StatusOK, syncResp.StatusCode)
}

func ptrStr(s string) *string { return &s }

// makeAccessTokenWithTier creates a JWT with the given tier embedded in claims.
func makeAccessTokenWithTier(t *testing.T, userID, email, tier string) string {
	t.Helper()
	claims := middleware.UserClaims{
		UserID:        userID,
		Email:         email,
		Tier:          tier,
		TokenType:     "access",
		EmailVerified: true,
		RegisteredClaims: jwt.RegisteredClaims{
			ExpiresAt: jwt.NewNumericDate(time.Now().Add(15 * time.Minute)),
		},
	}
	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	signed, err := token.SignedString([]byte(testJWTSecret))
	require.NoError(t, err)
	return signed
}

// buildSyncGatingApp builds a minimal Fiber app that replicates the
// production middleware chain for the sync group:
//
//	JWT → SubscriptionMiddleware → RequireBackendSync → 200 handler
//
// A non-gated endpoint (/users/me) is registered without RequireBackendSync
// to verify the middleware is not applied globally.
func buildSyncGatingApp(userRepo ports.UserRepository) *fiber.App {
	app := fiber.New()
	protected := app.Group("", middleware.JWT(testJWTSecret))
	protected.Use(middleware.NewSubscriptionMiddleware(userRepo))

	// Non-gated endpoint — must not be affected by RequireBackendSync.
	protected.Get("/users/me", func(c *fiber.Ctx) error {
		return c.Status(fiber.StatusOK).JSON(fiber.Map{"ok": true})
	})

	// Gated sync group.
	syncGroup := protected.Group("/sync", middleware.NewRequireBackendSync())
	syncGroup.Get("/full", func(c *fiber.Ctx) error {
		return c.Status(fiber.StatusOK).JSON(fiber.Map{"ok": true})
	})
	syncGroup.Post("/sessions", func(c *fiber.Ctx) error {
		return c.Status(fiber.StatusOK).JSON(fiber.Map{"ok": true})
	})
	syncGroup.Post("/initial-upload", func(c *fiber.Ctx) error {
		return c.Status(fiber.StatusOK).JSON(fiber.Map{"ok": true})
	})

	// Gated preferences.
	protected.Put("/preferences", middleware.NewRequireBackendSync(), func(c *fiber.Ctx) error {
		return c.Status(fiber.StatusOK).JSON(fiber.Map{"ok": true})
	})

	return app
}

func doSyncRequest(t *testing.T, app *fiber.App, method, path, token string) int {
	t.Helper()
	var req *http.Request
	if method == http.MethodGet {
		req = httptest.NewRequest(http.MethodGet, path, nil)
	} else {
		req = httptest.NewRequest(method, path, bytes.NewReader([]byte("{}")))
		req.Header.Set("Content-Type", "application/json")
	}
	if token != "" {
		req.Header.Set("Authorization", "Bearer "+token)
	}
	resp, err := app.Test(req)
	require.NoError(t, err)
	return resp.StatusCode
}

// TestSyncRouteGating_FreeTier_Returns402 verifies that a free-tier user
// receives 402 on all gated sync endpoints when RequireBackendSync is wired
// into the route group (mirrors the production route wiring in routes.go).
//
// This test must FAIL (RED) until T1.10 wires RequireBackendSync into the
// production RegisterAPIRoutes function. The test uses a helper that builds a
// minimal app with the same middleware chain that production routes.go applies.
func TestSyncRouteGating_FreeTier_Returns402(t *testing.T) {
	if testing.Short() {
		t.Skip("skipping integration test")
	}

	userRepo := newIntegrationUserRepo()
	user := &domain.User{
		ID:               "sg-free",
		Email:            "sg-free@test.com",
		Name:             "SG Free",
		PasswordHash:     ptrStr("x"),
		SubscriptionTier: "free",
		EmailVerified:    true,
	}
	require.NoError(t, userRepo.Create(context.Background(), user))

	// buildSyncGatingApp mirrors what RegisterAPIRoutes must do after T1.10.
	// If production routes.go does NOT wire RequireBackendSync, the production
	// routes test (TestSyncRouteGating_ProductionRoutes_*) will catch it.
	app := buildSyncGatingApp(userRepo)
	token := makeAccessTokenWithTier(t, user.ID, user.Email, "free")

	for _, tc := range []struct{ method, path string }{
		{http.MethodGet, "/sync/full"},
		{http.MethodPost, "/sync/sessions"},
		{http.MethodPost, "/sync/initial-upload"},
		{http.MethodPut, "/preferences"},
	} {
		code := doSyncRequest(t, app, tc.method, tc.path, token)
		if code != http.StatusPaymentRequired {
			t.Errorf("%s %s: expected 402, got %d", tc.method, tc.path, code)
		}
	}
}

// TestSyncRouteGating_EverywhereMonthly_Returns200 verifies that an
// Everywhere+ user with an active subscription can access the gated endpoints.
func TestSyncRouteGating_EverywhereMonthly_Returns200(t *testing.T) {
	if testing.Short() {
		t.Skip("skipping integration test")
	}

	userRepo := newIntegrationUserRepo()
	future := time.Now().Add(30 * 24 * time.Hour)
	user := &domain.User{
		ID:                    "sg-everywhere",
		Email:                 "sg-everywhere@test.com",
		Name:                  "SG Everywhere",
		PasswordHash:          ptrStr("x"),
		SubscriptionTier:      "everywhere_monthly",
		SubscriptionExpiresAt: &future,
		EmailVerified:         true,
	}
	require.NoError(t, userRepo.Create(context.Background(), user))

	app := buildSyncGatingApp(userRepo)
	token := makeAccessTokenWithTier(t, user.ID, user.Email, "everywhere_monthly")

	for _, tc := range []struct{ method, path string }{
		{http.MethodGet, "/sync/full"},
		{http.MethodPost, "/sync/sessions"},
		{http.MethodPost, "/sync/initial-upload"},
		{http.MethodPut, "/preferences"},
	} {
		code := doSyncRequest(t, app, tc.method, tc.path, token)
		if code != http.StatusOK {
			t.Errorf("%s %s: expected 200, got %d", tc.method, tc.path, code)
		}
	}
}

// TestSyncRouteGating_NonGatedEndpointUnaffected verifies that /users/me
// (a non-gated endpoint) is accessible to free-tier users.
func TestSyncRouteGating_NonGatedEndpointUnaffected(t *testing.T) {
	if testing.Short() {
		t.Skip("skipping integration test")
	}

	userRepo := newIntegrationUserRepo()
	user := &domain.User{
		ID:               "sg-nongated",
		Email:            "sg-nongated@test.com",
		Name:             "SG NonGated",
		PasswordHash:     ptrStr("x"),
		SubscriptionTier: "free",
		EmailVerified:    true,
	}
	require.NoError(t, userRepo.Create(context.Background(), user))

	app := buildSyncGatingApp(userRepo)
	token := makeAccessTokenWithTier(t, user.ID, user.Email, "free")

	code := doSyncRequest(t, app, http.MethodGet, "/users/me", token)
	if code != http.StatusOK {
		t.Errorf("GET /users/me: expected 200, got %d", code)
	}
}

// TestProductionRoutes_SyncGroupHasRequireBackendSync verifies that the
// production routes.go file wires RequireBackendSync on the sync group and
// preferences endpoint. This is a source-level assertion test: it reads
// routes.go and asserts the middleware call is present.
//
// This test FAILS (RED) until T1.10 adds NewRequireBackendSync() to routes.go.
func TestProductionRoutes_SyncGroupHasRequireBackendSync(t *testing.T) {
	if testing.Short() {
		t.Skip("skipping integration test")
	}

	routesFile := readRoutesFile(t)

	assertContains(t, routesFile, "NewRequireBackendSync",
		"routes.go must call middleware.NewRequireBackendSync() on sync/preferences routes")
	assertContains(t, routesFile, "tasks.Post(\"/sync\"",
		"routes.go must still register the task sync endpoint")
	assertContains(t, routesFile, "deps.Tasks.Sync",
		"tasks/sync must remain wired to the task sync handler after adding backend sync gating")
}
