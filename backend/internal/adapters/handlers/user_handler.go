package handlers

import (
	"io"
	"mime/multipart"
	"net/http"

	"github.com/gofiber/fiber/v2"

	"pepinillo/backend/internal/ports"
)

type UserHandler struct {
	users   ports.UserRepository
	storage ports.FileStorage
}

const (
	maxProfileNameLength     = 100
	maxProfileImageURLLength = 2048
)

type updateProfileRequest struct {
	Name     string `json:"name"`
	Email    string `json:"email"`
	ImageURL string `json:"imageUrl"`
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

	// S1: email changes never happen here — they go through the verified
	// RequestEmailChange/ConfirmEmailChange flow. Accepting an arbitrary address
	// would let an attacker claim someone else's email and merge their account
	// on a later OAuth sign-in, and would bypass the verified-email model.
	if req.Email != "" {
		return fiber.NewError(fiber.StatusBadRequest, "email_must_use_verification_flow")
	}
	if len(req.Name) > maxProfileNameLength {
		return fiber.NewError(fiber.StatusBadRequest, "name_too_long")
	}
	if len(req.ImageURL) > maxProfileImageURLLength {
		return fiber.NewError(fiber.StatusBadRequest, "image_url_too_long")
	}

	if req.Name != "" {
		user.Name = req.Name
	}
	if req.ImageURL != "" {
		user.ImageURL = &req.ImageURL
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
