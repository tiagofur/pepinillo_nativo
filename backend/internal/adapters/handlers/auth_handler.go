package handlers

import (
	"errors"

	"github.com/gofiber/fiber/v2"

	"pepinillo/backend/internal/services"
)

type AuthHandler struct {
	auth *services.AuthService
}

type authRequest struct {
	Email    string `json:"email"`
	Name     string `json:"name"`
	Password string `json:"password"`
}

type refreshRequest struct {
	RefreshToken string `json:"refreshToken"`
}

type forgotPasswordRequest struct {
	Email string `json:"email"`
}

type resetPasswordRequest struct {
	Email       string `json:"email"`
	Code        string `json:"code"`
	NewPassword string `json:"newPassword"`
}

type changePasswordRequest struct {
	CurrentPassword string `json:"currentPassword"`
	NewPassword     string `json:"newPassword"`
}

type verifyEmailRequest struct {
	Email string `json:"email"`
	Code  string `json:"code"`
}

type resendVerificationRequest struct {
	Email string `json:"email"`
}

type requestEmailChangeRequest struct {
	NewEmail string `json:"newEmail"`
}

type confirmEmailChangeRequest struct {
	Code string `json:"code"`
}

func NewAuthHandler(auth *services.AuthService) *AuthHandler {
	return &AuthHandler{auth: auth}
}

func (h *AuthHandler) Register(c *fiber.Ctx) error {
	var req authRequest
	if err := c.BodyParser(&req); err != nil {
		return fiber.NewError(fiber.StatusBadRequest, "invalid_request_body")
	}
	if req.Email == "" || req.Name == "" || req.Password == "" {
		return fiber.NewError(fiber.StatusBadRequest, "missing_required_fields")
	}

	user, tokens, err := h.auth.Register(c.Context(), req.Email, req.Name, req.Password)
	if err != nil {
		if errors.Is(err, services.ErrEmailAlreadyExists) {
			return fiber.NewError(fiber.StatusConflict, err.Error())
		}
		if errors.Is(err, services.ErrInvalidEmail) || errors.Is(err, services.ErrWeakPassword) {
			return fiber.NewError(fiber.StatusBadRequest, err.Error())
		}
		return err
	}

	return c.Status(fiber.StatusCreated).JSON(fiber.Map{
		"user":   user,
		"tokens": tokens,
	})
}

func (h *AuthHandler) Login(c *fiber.Ctx) error {
	var req authRequest
	if err := c.BodyParser(&req); err != nil {
		return fiber.NewError(fiber.StatusBadRequest, "invalid_request_body")
	}
	if req.Email == "" || req.Password == "" {
		return fiber.NewError(fiber.StatusBadRequest, "missing_required_fields")
	}

	user, tokens, err := h.auth.Login(c.Context(), req.Email, req.Password)
	if err != nil {
		if errors.Is(err, services.ErrInvalidCredentials) {
			return fiber.NewError(fiber.StatusUnauthorized, err.Error())
		}
		if errors.Is(err, services.ErrInvalidEmail) {
			return fiber.NewError(fiber.StatusBadRequest, err.Error())
		}
		return err
	}

	return c.JSON(fiber.Map{
		"user":   user,
		"tokens": tokens,
	})
}

func (h *AuthHandler) DeleteAccount(c *fiber.Ctx) error {
	userID := c.Locals("userID").(string)
	if err := h.auth.DeleteAccount(c.Context(), userID); err != nil {
		return err
	}
	return c.SendStatus(fiber.StatusNoContent)
}

func (h *AuthHandler) Refresh(c *fiber.Ctx) error {
	var req refreshRequest
	if err := c.BodyParser(&req); err != nil {
		return fiber.NewError(fiber.StatusBadRequest, "invalid_request_body")
	}
	if req.RefreshToken == "" {
		return fiber.NewError(fiber.StatusBadRequest, "missing_required_fields")
	}
	tokens, err := h.auth.Refresh(c.Context(), req.RefreshToken)
	if err != nil {
		if errors.Is(err, services.ErrInvalidRefreshToken) {
			return fiber.NewError(fiber.StatusUnauthorized, err.Error())
		}
		if errors.Is(err, services.ErrUserNotFound) {
			return fiber.NewError(fiber.StatusNotFound, err.Error())
		}
		return err
	}
	return c.JSON(fiber.Map{"tokens": tokens})
}

func (h *AuthHandler) Logout(c *fiber.Ctx) error {
	userID, ok := c.Locals("userID").(string)
	if !ok || userID == "" {
		return fiber.NewError(fiber.StatusUnauthorized, "invalid_claims")
	}
	var req refreshRequest
	_ = c.BodyParser(&req)
	if err := h.auth.Logout(c.Context(), userID, req.RefreshToken); err != nil {
		return err
	}
	return c.SendStatus(fiber.StatusNoContent)
}

func (h *AuthHandler) ForgotPassword(c *fiber.Ctx) error {
	var req forgotPasswordRequest
	if err := c.BodyParser(&req); err != nil {
		return fiber.NewError(fiber.StatusBadRequest, "invalid_request_body")
	}
	if req.Email == "" {
		return fiber.NewError(fiber.StatusBadRequest, "missing_required_fields")
	}
	if err := h.auth.ForgotPassword(c.Context(), req.Email); err != nil {
		if errors.Is(err, services.ErrInvalidEmail) {
			return fiber.NewError(fiber.StatusBadRequest, err.Error())
		}
		return err
	}
	return c.SendStatus(fiber.StatusNoContent)
}

func (h *AuthHandler) ResetPassword(c *fiber.Ctx) error {
	var req resetPasswordRequest
	if err := c.BodyParser(&req); err != nil {
		return fiber.NewError(fiber.StatusBadRequest, "invalid_request_body")
	}
	if req.Email == "" || req.Code == "" || req.NewPassword == "" {
		return fiber.NewError(fiber.StatusBadRequest, "missing_required_fields")
	}
	if err := h.auth.ResetPassword(c.Context(), req.Email, req.Code, req.NewPassword); err != nil {
		if errors.Is(err, services.ErrInvalidEmail) || errors.Is(err, services.ErrWeakPassword) || errors.Is(err, services.ErrInvalidResetCode) {
			return fiber.NewError(fiber.StatusBadRequest, err.Error())
		}
		if errors.Is(err, services.ErrUserNotFound) {
			return fiber.NewError(fiber.StatusNotFound, err.Error())
		}
		return err
	}
	return c.SendStatus(fiber.StatusNoContent)
}

func (h *AuthHandler) ChangePassword(c *fiber.Ctx) error {
	userID, ok := c.Locals("userID").(string)
	if !ok || userID == "" {
		return fiber.NewError(fiber.StatusUnauthorized, "invalid_claims")
	}
	var req changePasswordRequest
	if err := c.BodyParser(&req); err != nil {
		return fiber.NewError(fiber.StatusBadRequest, "invalid_request_body")
	}
	if req.CurrentPassword == "" || req.NewPassword == "" {
		return fiber.NewError(fiber.StatusBadRequest, "missing_required_fields")
	}
	if err := h.auth.ChangePassword(c.Context(), userID, req.CurrentPassword, req.NewPassword); err != nil {
		if errors.Is(err, services.ErrWeakPassword) {
			return fiber.NewError(fiber.StatusBadRequest, err.Error())
		}
		if errors.Is(err, services.ErrInvalidCredentials) {
			return fiber.NewError(fiber.StatusUnauthorized, err.Error())
		}
		if errors.Is(err, services.ErrUserNotFound) {
			return fiber.NewError(fiber.StatusNotFound, err.Error())
		}
		return err
	}
	return c.SendStatus(fiber.StatusNoContent)
}

func (h *AuthHandler) VerifyEmail(c *fiber.Ctx) error {
	var req verifyEmailRequest
	if err := c.BodyParser(&req); err != nil {
		return fiber.NewError(fiber.StatusBadRequest, "invalid_request_body")
	}
	if req.Email == "" || req.Code == "" {
		return fiber.NewError(fiber.StatusBadRequest, "missing_required_fields")
	}

	user, tokens, err := h.auth.VerifyEmail(c.Context(), req.Email, req.Code)
	if err != nil {
		if errors.Is(err, services.ErrInvalidEmail) || errors.Is(err, services.ErrInvalidVerificationCode) {
			return fiber.NewError(fiber.StatusBadRequest, err.Error())
		}
		if errors.Is(err, services.ErrUserNotFound) {
			return fiber.NewError(fiber.StatusNotFound, err.Error())
		}
		if errors.Is(err, services.ErrEmailAlreadyVerified) {
			return fiber.NewError(fiber.StatusBadRequest, err.Error())
		}
		return err
	}

	return c.JSON(fiber.Map{
		"message": "email_verified",
		"user":    user,
		"tokens":  tokens,
	})
}

func (h *AuthHandler) ResendVerification(c *fiber.Ctx) error {
	var req resendVerificationRequest
	if err := c.BodyParser(&req); err != nil {
		return fiber.NewError(fiber.StatusBadRequest, "invalid_request_body")
	}
	if req.Email == "" {
		return fiber.NewError(fiber.StatusBadRequest, "missing_required_fields")
	}

	if err := h.auth.ResendVerificationCode(c.Context(), req.Email); err != nil {
		if errors.Is(err, services.ErrInvalidEmail) {
			return fiber.NewError(fiber.StatusBadRequest, err.Error())
		}
		if errors.Is(err, services.ErrUserNotFound) {
			return fiber.NewError(fiber.StatusNotFound, err.Error())
		}
		if errors.Is(err, services.ErrEmailAlreadyVerified) {
			return fiber.NewError(fiber.StatusBadRequest, err.Error())
		}
		return err
	}

	return c.JSON(fiber.Map{
		"message": "verification_code_sent",
	})
}

func (h *AuthHandler) RequestEmailChange(c *fiber.Ctx) error {
	userID, ok := c.Locals("userID").(string)
	if !ok || userID == "" {
		return fiber.NewError(fiber.StatusUnauthorized, "invalid_claims")
	}

	var req requestEmailChangeRequest
	if err := c.BodyParser(&req); err != nil {
		return fiber.NewError(fiber.StatusBadRequest, "invalid_request_body")
	}
	if req.NewEmail == "" {
		return fiber.NewError(fiber.StatusBadRequest, "missing_required_fields")
	}

	user, err := h.auth.RequestEmailChange(c.Context(), userID, req.NewEmail)
	if err != nil {
		if errors.Is(err, services.ErrInvalidEmail) {
			return fiber.NewError(fiber.StatusBadRequest, err.Error())
		}
		if errors.Is(err, services.ErrUserNotFound) {
			return fiber.NewError(fiber.StatusNotFound, err.Error())
		}
		if errors.Is(err, services.ErrEmailAlreadyExists) {
			return fiber.NewError(fiber.StatusConflict, err.Error())
		}
		if errors.Is(err, services.ErrSameEmail) {
			return fiber.NewError(fiber.StatusBadRequest, err.Error())
		}
		return err
	}

	return c.JSON(fiber.Map{
		"message":      "verification_code_sent_to_new_email",
		"pendingEmail": user.PendingEmail,
		"user":         user,
	})
}

func (h *AuthHandler) ConfirmEmailChange(c *fiber.Ctx) error {
	userID, ok := c.Locals("userID").(string)
	if !ok || userID == "" {
		return fiber.NewError(fiber.StatusUnauthorized, "invalid_claims")
	}

	var req confirmEmailChangeRequest
	if err := c.BodyParser(&req); err != nil {
		return fiber.NewError(fiber.StatusBadRequest, "invalid_request_body")
	}
	if req.Code == "" {
		return fiber.NewError(fiber.StatusBadRequest, "missing_required_fields")
	}

	user, err := h.auth.ConfirmEmailChange(c.Context(), userID, req.Code)
	if err != nil {
		if errors.Is(err, services.ErrInvalidVerificationCode) {
			return fiber.NewError(fiber.StatusBadRequest, err.Error())
		}
		if errors.Is(err, services.ErrUserNotFound) {
			return fiber.NewError(fiber.StatusNotFound, err.Error())
		}
		if errors.Is(err, services.ErrEmailChangeNotPending) {
			return fiber.NewError(fiber.StatusBadRequest, err.Error())
		}
		return err
	}

	return c.JSON(fiber.Map{
		"message": "email_changed",
		"user":    user,
	})
}

func (h *AuthHandler) CancelEmailChange(c *fiber.Ctx) error {
	userID, ok := c.Locals("userID").(string)
	if !ok || userID == "" {
		return fiber.NewError(fiber.StatusUnauthorized, "invalid_claims")
	}

	if err := h.auth.CancelEmailChange(c.Context(), userID); err != nil {
		if errors.Is(err, services.ErrUserNotFound) {
			return fiber.NewError(fiber.StatusNotFound, err.Error())
		}
		if errors.Is(err, services.ErrEmailChangeNotPending) {
			return fiber.NewError(fiber.StatusBadRequest, err.Error())
		}
		return err
	}

	return c.JSON(fiber.Map{
		"message": "email_change_cancelled",
	})
}
