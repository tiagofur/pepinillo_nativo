package handlers

import (
	"errors"
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

	return c.Status(code).JSON(errorResponse{Error: message})
}
