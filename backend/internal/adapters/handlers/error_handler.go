package handlers

import (
	"errors"
	"log/slog"
	"net/http"

	"github.com/gofiber/fiber/v2"

	"pepinillo/backend/internal/observability"
)

type errorResponse struct {
	Error string `json:"error"`
}

func ErrorHandler(c *fiber.Ctx, err error) error {
	var e *fiber.Error
	code := http.StatusInternalServerError
	message := "internal_server_error"

	if errors.As(err, &e) {
		code = e.Code
		message = e.Message
	}

	// Log error with request details. 5xx goes to Error level and also
	// gets reported to Sentry for alerting; 4xx is Warn because it is
	// expected client misuse.
	if code >= http.StatusInternalServerError {
		slog.Error("http request failed",
			"method", c.Method(),
			"path", c.Path(),
			"status", code,
			"error", err,
		)
		observability.CaptureError(err, map[string]string{
			"http.method": c.Method(),
			"http.path":   c.Path(),
			"http.status": http.StatusText(code),
		})
	} else if code >= http.StatusBadRequest {
		slog.Warn("http request rejected",
			"method", c.Method(),
			"path", c.Path(),
			"status", code,
			"error", err,
		)
	}

	return c.Status(code).JSON(errorResponse{Error: message})
}
