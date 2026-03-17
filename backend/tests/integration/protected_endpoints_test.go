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
	user := &domain.User{ID: "u1", Email: "billing-protected@test.com", Name: "U1", PasswordHash: "x", SubscriptionTier: "free"}
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

	body := []byte(`{"platform":"android","productId":"pepinillo_pro_monthly","purchaseToken":"abc"}`)
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
