package handlers

import (
	"bytes"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/gofiber/fiber/v2"
)

func TestOAuthHandler_LoginWithApple_RequiresNonce(t *testing.T) {
	app := fiber.New()
	handler := NewOAuthHandler(nil)
	app.Post("/auth/apple", handler.LoginWithApple)

	req := httptest.NewRequest(http.MethodPost, "/auth/apple", bytes.NewBufferString(`{"idToken":"some-token"}`))
	req.Header.Set("Content-Type", "application/json")

	resp, err := app.Test(req)
	if err != nil {
		t.Fatalf("expected request to be handled, got error: %v", err)
	}
	if resp.StatusCode != http.StatusBadRequest {
		t.Fatalf("expected %d, got %d", http.StatusBadRequest, resp.StatusCode)
	}
}
