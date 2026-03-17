package handlers

import (
	"context"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/gofiber/fiber/v2"
	"github.com/stretchr/testify/require"

	"pepinillo/backend/internal/domain"
	"pepinillo/backend/internal/services"
)

func TestPushHandler_RegisterDevice(t *testing.T) {
	app := fiber.New()
	pushSvc := services.NewPushService(&fakePushRepo{}, &fakeProvider{})
	h := NewPushHandler(pushSvc)

	app.Post("/push/devices", func(c *fiber.Ctx) error {
		c.Locals("userID", "u1")
		return h.RegisterDevice(c)
	})

	req := httptest.NewRequest("POST", "/push/devices", strings.NewReader(`{"platform":"ios","token":"abc"}`))
	req.Header.Set("Content-Type", "application/json")
	resp, err := app.Test(req)
	require.NoError(t, err)
	require.Equal(t, fiber.StatusCreated, resp.StatusCode)
}

func TestPushHandler_RegisterDevice_BadRequest(t *testing.T) {
	app := fiber.New()
	pushSvc := services.NewPushService(&fakePushRepo{}, &fakeProvider{})
	h := NewPushHandler(pushSvc)

	app.Post("/push/devices", func(c *fiber.Ctx) error {
		c.Locals("userID", "u1")
		return h.RegisterDevice(c)
	})

	req := httptest.NewRequest("POST", "/push/devices", strings.NewReader(`{"platform":"web","token":"abc"}`))
	req.Header.Set("Content-Type", "application/json")
	resp, err := app.Test(req)
	require.NoError(t, err)
	require.Equal(t, fiber.StatusBadRequest, resp.StatusCode)
}

type fakePushRepo struct{}

func (f *fakePushRepo) Upsert(_ context.Context, _ *domain.DeviceToken) error { return nil }
func (f *fakePushRepo) ListByUser(_ context.Context, _ string) ([]domain.DeviceToken, error) {
	return []domain.DeviceToken{}, nil
}
func (f *fakePushRepo) DeleteByToken(_ context.Context, _, _ string) error { return nil }

type fakeProvider struct{}

func (f *fakeProvider) Send(_ context.Context, _, _, _, _ string, _ map[string]string) error {
	return nil
}
