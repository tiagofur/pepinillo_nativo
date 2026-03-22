package handlers

import (
	"errors"
	"log"
	"net/http"

	"github.com/gofiber/fiber/v2"
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

	// Log error with request details
	if code >= http.StatusInternalServerError {
		log.Printf("ERROR %s %s - status: %d - error: %v", c.Method(), c.Path(), code, err)
	} else if code >= http.StatusBadRequest {
		log.Printf("WARN %s %s - status: %d - error: %v", c.Method(), c.Path(), code, err)
	}

	return c.Status(code).JSON(errorResponse{Error: message})
}
