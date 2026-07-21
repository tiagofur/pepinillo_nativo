package handlers

import (
	"io"
	"mime/multipart"
	"net/http"
	"time"

	"github.com/gofiber/fiber/v2"

	"pepinillo/backend/internal/ports"
)

type UserHandler struct {
	users   ports.UserRepository
	storage ports.FileStorage
}

type updateProfileRequest struct {
	Name      string `json:"name"`
	Email     string `json:"email"`
	ImageURL  string `json:"imageUrl"`
	BirthDate string `json:"birthDate"`
}

func NewUserHandler(users ports.UserRepository, storage ports.FileStorage) *UserHandler {
	return &UserHandler{users: users, storage: storage}
}

func (h *UserHandler) Me(c *fiber.Ctx) error {
	userID, ok := c.Locals("userID").(string)
	if !ok || userID == "" {
		return fiber.NewError(fiber.StatusUnauthorized, "invalid_claims")
	}
	user, err := h.users.GetByID(c.Context(), userID)
	if err != nil {
		return err
	}
	if user == nil {
		return fiber.NewError(fiber.StatusNotFound, "user_not_found")
	}
	return c.JSON(user)
}

func (h *UserHandler) UpdateMe(c *fiber.Ctx) error {
	userID, ok := c.Locals("userID").(string)
	if !ok || userID == "" {
		return fiber.NewError(fiber.StatusUnauthorized, "invalid_claims")
	}
	user, err := h.users.GetByID(c.Context(), userID)
	if err != nil {
		return err
	}
	if user == nil {
		return fiber.NewError(fiber.StatusNotFound, "user_not_found")
	}

	var req updateProfileRequest
	if err := c.BodyParser(&req); err != nil {
		return fiber.NewError(fiber.StatusBadRequest, "invalid_request_body")
	}

	if req.Name != "" {
		user.Name = req.Name
	}
	if req.Email != "" {
		user.Email = req.Email
	}
	if req.ImageURL != "" {
		user.ImageURL = &req.ImageURL
	}
	if req.BirthDate != "" {
		parsed, err := time.Parse(time.RFC3339, req.BirthDate)
		if err != nil {
			return fiber.NewError(fiber.StatusBadRequest, "invalid_birth_date")
		}
		user.BirthDate = &parsed
	}

	if err := h.users.Update(c.Context(), user); err != nil {
		return err
	}

	return c.JSON(user)
}

func (h *UserHandler) UploadImage(c *fiber.Ctx) error {
	userID, ok := c.Locals("userID").(string)
	if !ok || userID == "" {
		return fiber.NewError(fiber.StatusUnauthorized, "invalid_claims")
	}

	user, err := h.users.GetByID(c.Context(), userID)
	if err != nil {
		return err
	}
	if user == nil {
		return fiber.NewError(fiber.StatusNotFound, "user_not_found")
	}

	fileHeader, err := c.FormFile("image")
	if err != nil {
		return fiber.NewError(fiber.StatusBadRequest, "missing_required_fields")
	}
	if fileHeader.Size > 5*1024*1024 {
		return fiber.NewError(fiber.StatusBadRequest, "file_too_large")
	}

	data, err := readFile(fileHeader)
	if err != nil {
		return err
	}

	// Detect real MIME type from file content (not client-supplied header).
	detectedType := http.DetectContentType(data)
	if detectedType != "image/jpeg" && detectedType != "image/png" && detectedType != "image/webp" {
		return fiber.NewError(fiber.StatusBadRequest, "invalid_image_type")
	}

	url, err := h.storage.UploadProfileImage(c.Context(), userID, fileHeader.Filename, detectedType, data)
	if err != nil {
		return err
	}
	user.ImageURL = &url
	if err := h.users.Update(c.Context(), user); err != nil {
		return err
	}

	return c.JSON(fiber.Map{"imageUrl": url})
}

func readFile(fileHeader *multipart.FileHeader) ([]byte, error) {
	file, err := fileHeader.Open()
	if err != nil {
		return nil, err
	}
	defer file.Close()
	data, err := io.ReadAll(file)
	if err != nil {
		return nil, err
	}
	return data, nil
}
