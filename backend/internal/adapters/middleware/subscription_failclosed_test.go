package middleware

import (
	"context"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/gofiber/fiber/v2"

	"pepinillo/backend/internal/domain"
	"pepinillo/backend/internal/ports"
)

// stubUserRepo embeds the interface so tests only implement GetByID.
type stubUserRepo struct {
	ports.UserRepository
	user *domain.User
	err  error
}

func (s *stubUserRepo) GetByID(_ context.Context, _ string) (*domain.User, error) {
	return s.user, s.err
}

func testAppWithSubscriptionMiddleware(t *testing.T, repo ports.UserRepository, feature string) *fiber.App {
	t.Helper()
	app := fiber.New()
	app.Use(func(c *fiber.Ctx) error {
		c.Locals("userID", "user-1")
		return c.Next()
	})
	app.Use(NewSubscriptionMiddleware(repo))
	if feature != "" {
		app.Use(NewRequireProFeatureMiddleware(feature))
	}
	app.Get("/probe", func(c *fiber.Ctx) error {
		tier, _ := c.Locals("tier").(string)
		return c.SendString("tier=" + tier)
	})
	return app
}

// B5: an expired subscription with a stale tier string must resolve to free
// (or lifetime), never keep premium features.
func TestSubscriptionMiddleware_ExpiredSubscriptionResolvesFree(t *testing.T) {
	past := time.Now().UTC().Add(-time.Hour)
	repo := &stubUserRepo{user: &domain.User{
		ID: "user-1", Email: "u@x.com",
		SubscriptionTier: "everywhere_monthly", SubscriptionExpiresAt: &past,
	}}
	app := testAppWithSubscriptionMiddleware(t, repo, "advanced_analytics")

	resp, err := app.Test(httptest.NewRequest(http.MethodGet, "/probe", nil))
	if err != nil {
		t.Fatalf("request failed: %v", err)
	}
	if resp.StatusCode != http.StatusForbidden {
		t.Fatalf("expected 403 for expired subscription, got %d", resp.StatusCode)
	}
}

// B5: store errors must fail closed, not inherit ambient context.
func TestSubscriptionMiddleware_RepoErrorFailsClosed(t *testing.T) {
	repo := &stubUserRepo{err: context.DeadlineExceeded}
	app := testAppWithSubscriptionMiddleware(t, repo, "advanced_analytics")

	resp, err := app.Test(httptest.NewRequest(http.MethodGet, "/probe", nil))
	if err != nil {
		t.Fatalf("request failed: %v", err)
	}
	if resp.StatusCode != http.StatusUnauthorized {
		t.Fatalf("expected 401 on repo error, got %d", resp.StatusCode)
	}
}

// B5: a missing tier (misordered middleware) must not default to open.
func TestRequireProFeature_MissingTierFailsClosed(t *testing.T) {
	app := fiber.New()
	app.Use(func(c *fiber.Ctx) error {
		c.Locals("userID", "user-1")
		return c.Next()
	})
	app.Use(NewRequireProFeatureMiddleware("advanced_analytics"))
	app.Get("/probe", func(c *fiber.Ctx) error { return c.SendString("open") })

	resp, err := app.Test(httptest.NewRequest(http.MethodGet, "/probe", nil))
	if err != nil {
		t.Fatalf("request failed: %v", err)
	}
	if resp.StatusCode != http.StatusForbidden {
		t.Fatalf("expected 403 for missing tier, got %d", resp.StatusCode)
	}
}

// Expired subscription with a lifetime entitlement keeps pepinillo_plus.
func TestSubscriptionMiddleware_ExpiredWithLifetimeKeepsPlus(t *testing.T) {
	past := time.Now().UTC().Add(-time.Hour)
	now := time.Now().UTC()
	repo := &stubUserRepo{user: &domain.User{
		ID: "user-1", Email: "u@x.com",
		SubscriptionTier: "everywhere_annual", SubscriptionExpiresAt: &past,
		PepinilloPlusEntitlementAt: &now,
	}}
	app := fiber.New()
	app.Use(func(c *fiber.Ctx) error {
		c.Locals("userID", "user-1")
		return c.Next()
	})
	app.Use(NewSubscriptionMiddleware(repo))
	app.Get("/probe", func(c *fiber.Ctx) error {
		tier, _ := c.Locals("tier").(string)
		return c.SendString("tier=" + tier)
	})

	resp, err := app.Test(httptest.NewRequest(http.MethodGet, "/probe", nil))
	if err != nil {
		t.Fatalf("request failed: %v", err)
	}
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("expected 200, got %d", resp.StatusCode)
	}
}
