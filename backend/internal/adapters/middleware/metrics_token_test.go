package middleware

import (
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/gofiber/fiber/v2"
)

func metricsApp(token string) *fiber.App {
	app := fiber.New(fiber.Config{ErrorHandler: func(c *fiber.Ctx, err error) error {
		code := fiber.StatusInternalServerError
		if e, ok := err.(*fiber.Error); ok {
			code = e.Code
		}
		return c.Status(code).SendString(err.Error())
	}})
	app.Get("/internal/stats", RequireMetricsToken(token), func(c *fiber.Ctx) error { return c.SendString("ok") })
	return app
}

func TestRequireMetricsToken(t *testing.T) {
	cases := []struct {
		name, configured, header string
		want                     int
	}{
		{"valid token", "s3cret", "Bearer s3cret", 200},
		{"wrong token", "s3cret", "Bearer nope", 401},
		{"missing header", "s3cret", "", 401},
		{"wrong scheme", "s3cret", "Basic s3cret", 401},
		{"empty bearer", "s3cret", "Bearer ", 401},
		{"unconfigured token fails closed", "", "Bearer ", 401},
		{"unconfigured token ignores any bearer", "", "Bearer x", 401},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			req := httptest.NewRequest(http.MethodGet, "/internal/stats", nil)
			if tc.header != "" {
				req.Header.Set("Authorization", tc.header)
			}
			resp, err := metricsApp(tc.configured).Test(req)
			if err != nil {
				t.Fatal(err)
			}
			if resp.StatusCode != tc.want {
				t.Fatalf("status = %d, want %d", resp.StatusCode, tc.want)
			}
		})
	}
}
