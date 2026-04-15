package handlers

import (
	"encoding/json"
	"strings"

	fiberws "github.com/gofiber/contrib/websocket"
	"github.com/gofiber/fiber/v2"
	"github.com/gofiber/fiber/v2/middleware/limiter"
	"github.com/golang-jwt/jwt/v5"

	"pepinillo/backend/internal/adapters/middleware"
)

func jwtParser() *jwt.Parser {
	return jwt.NewParser()
}

type RouteHandlers struct {
	Auth         *AuthHandler
	OAuth        *OAuthHandler
	Users        *UserHandler
	Tasks        *TaskHandler
	SubTasks     *SubTaskHandler
	Pomodoro     *PomodoroHandler
	Focus        *FocusHandler
	AI           *AIHandler
	Billing      *BillingHandler
	RevenueCat   *RevenueCatHandler
	Push         *PushHandler
	WebSocket    *WebSocketHandler
	Analytics    *AnalyticsHandler
	Preferences  *PreferenceHandler
	Sync         *SyncHandler
	JWTSecret    string
	HealthChecks DependencyChecks
}

func RegisterAPIRoutes(api fiber.Router, deps RouteHandlers) {
	RegisterHealthRoutes(api, deps.HealthChecks)

	auth := api.Group("/auth")
	authLimiter := limiter.New(limiter.Config{Max: 60})
	// Per-IP limits — the existing line of defence.
	loginRegisterLimiter := limiter.New(limiter.Config{Max: 5})
	refreshLimiter := limiter.New(limiter.Config{Max: 10})
	passwordRecoveryLimiter := limiter.New(limiter.Config{Max: 5})
	emailVerificationLimiter := limiter.New(limiter.Config{Max: 10})

	// Per-identity limits — catch credential-stuffing that rotates IP but targets
	// a single account, and distributed-account-creation from one email. Keyed
	// by the submitted email (login/register/password recovery/email verify) or
	// by the userID decoded from the refresh token (refresh). Same storage as
	// the IP limiter (Fiber's in-memory default) so no new deps.
	loginRegisterByEmail := limiter.New(limiter.Config{
		Max:          10, // slightly higher than per-IP to avoid false positives when multiple users share NAT
		KeyGenerator: emailKeyGenerator("auth:login-register"),
	})
	refreshByUser := limiter.New(limiter.Config{
		Max:          20,
		KeyGenerator: refreshTokenUserKeyGenerator(),
	})
	passwordRecoveryByEmail := limiter.New(limiter.Config{
		Max:          5,
		KeyGenerator: emailKeyGenerator("auth:password-recovery"),
	})
	emailVerifyByEmail := limiter.New(limiter.Config{
		Max:          10,
		KeyGenerator: emailKeyGenerator("auth:email-verify"),
	})

	auth.Use(authLimiter)
	auth.Post("/register", loginRegisterLimiter, loginRegisterByEmail, deps.Auth.Register)
	auth.Post("/login", loginRegisterLimiter, loginRegisterByEmail, deps.Auth.Login)
	auth.Post("/google", loginRegisterLimiter, deps.OAuth.LoginWithGoogle)
	auth.Post("/apple", loginRegisterLimiter, deps.OAuth.LoginWithApple)
	auth.Post("/refresh", refreshLimiter, refreshByUser, deps.Auth.Refresh)
	auth.Post("/forgot-password", passwordRecoveryLimiter, passwordRecoveryByEmail, deps.Auth.ForgotPassword)
	auth.Post("/reset-password", passwordRecoveryLimiter, passwordRecoveryByEmail, deps.Auth.ResetPassword)
	auth.Post("/verify-email", emailVerificationLimiter, emailVerifyByEmail, deps.Auth.VerifyEmail)
	auth.Post("/resend-verification", emailVerificationLimiter, emailVerifyByEmail, deps.Auth.ResendVerification)

	protected := api.Group("", middleware.JWT(deps.JWTSecret))

	protected.Delete("/auth/account", deps.Auth.DeleteAccount)
	protected.Post("/auth/logout", deps.Auth.Logout)
	protected.Post("/auth/change-password", deps.Auth.ChangePassword)
	protected.Post("/auth/request-email-change", deps.Auth.RequestEmailChange)
	protected.Post("/auth/confirm-email-change", deps.Auth.ConfirmEmailChange)
	protected.Post("/auth/cancel-email-change", deps.Auth.CancelEmailChange)

	// OAuth account linking
	protected.Post("/auth/link/google", deps.OAuth.LinkGoogleAccount)
	protected.Post("/auth/link/apple", deps.OAuth.LinkAppleAccount)
	protected.Delete("/auth/unlink/google", deps.OAuth.UnlinkGoogleAccount)
	protected.Delete("/auth/unlink/apple", deps.OAuth.UnlinkAppleAccount)
	protected.Get("/auth/providers", deps.OAuth.GetLinkedProviders)

	users := protected.Group("/users")
	users.Get("/me", deps.Users.Me)
	users.Put("/me", deps.Users.UpdateMe)
	users.Post("/me/image", deps.Users.UploadImage)

	tasks := protected.Group("/tasks")
	tasks.Get("/", deps.Tasks.List)
	tasks.Post("/", deps.Tasks.Upsert)
	tasks.Put("/:id", deps.Tasks.Upsert)
	tasks.Delete("/:id", deps.Tasks.Delete)
	tasks.Post("/sync", deps.Tasks.Sync)
	tasks.Get("/recurrences", deps.Tasks.ListRecurrences)
	tasks.Post("/recurrences/generate", deps.Tasks.GenerateRecurrences)

	// Mode-specific tracking endpoints
	tasks.Put("/:id/tracking-mode", deps.Tasks.UpdateTrackingMode)
	tasks.Post("/:id/completion", deps.Tasks.IncrementCompletion)
	tasks.Post("/:id/focus-time", deps.Tasks.IncrementFocusTime)
	tasks.Put("/:id/active-session", deps.Tasks.SetActiveSession)

	// Subtask CRUD (independent)
	tasks.Get("/:taskId/subtasks", deps.SubTasks.List)
	tasks.Post("/:taskId/subtasks", deps.SubTasks.Create)
	tasks.Put("/:taskId/subtasks/:subtaskId", deps.SubTasks.Update)
	tasks.Delete("/:taskId/subtasks/:subtaskId", deps.SubTasks.Delete)

	pomodoro := protected.Group("/pomodoro")
	pomodoro.Get("/config", deps.Pomodoro.GetConfig)
	pomodoro.Put("/config", deps.Pomodoro.UpsertConfig)
	pomodoro.Get("/stats", deps.Pomodoro.ListStats)
	pomodoro.Post("/stats", deps.Pomodoro.UpsertStats)
	pomodoro.Get("/sessions/all", deps.Pomodoro.ListAllSessions)
	pomodoro.Get("/sessions/range", deps.Pomodoro.ListSessionsByRange)
	pomodoro.Get("/sessions/task-stats/:taskId", deps.Pomodoro.GetTaskStats)
	pomodoro.Get("/sessions", deps.Pomodoro.ListSessionsByTask)
	pomodoro.Post("/sessions", deps.Pomodoro.InsertSession)
	pomodoro.Put("/sessions/:id", deps.Pomodoro.UpdateSession)

	// New Focus endpoints (multi-mode support)
	focus := protected.Group("/focus")
	focus.Get("/config", deps.Focus.GetConfig)
	focus.Put("/config", deps.Focus.UpsertConfig)
	focus.Get("/stats", deps.Focus.ListStats)
	focus.Post("/stats", deps.Focus.UpsertStats)
	focus.Get("/sessions/all", deps.Focus.ListAllSessions)
	focus.Get("/sessions/range", deps.Focus.ListSessionsByRange)
	focus.Get("/sessions/task-stats/:taskId", deps.Focus.GetTaskStats)
	focus.Get("/sessions", deps.Focus.ListSessionsByTask)
	focus.Post("/sessions", deps.Focus.InsertSession)
	focus.Put("/sessions/:id", deps.Focus.UpdateSession)

	ai := protected.Group("/ai")
	ai.Use(middleware.NewRequireProFeatureMiddleware("predictions"))
	ai.Use(middleware.NewRequireProFeatureMiddleware("advanced_analytics"))
	ai.Get("/daily-tip", deps.AI.DailyTip)
	ai.Get("/insights", deps.AI.ListInsights)
	ai.Get("/weekly-report", deps.AI.WeeklyReport)
	ai.Post("/analyze", deps.AI.Analyze)
	ai.Get("/predictions/productivity", deps.AI.ProductivityPrediction)
	ai.Get("/predictions/burnout-risk", deps.AI.BurnoutRisk)
	ai.Get("/optimal-hours", deps.AI.OptimalHours)

	billing := protected.Group("/billing")
	billing.Post("/verify-receipt", deps.Billing.VerifyReceipt)

	// RevenueCat webhook (no JWT auth - uses its own auth token)
	webhooks := api.Group("/webhooks")
	webhooks.Post("/revenuecat", deps.RevenueCat.Webhook)

	push := protected.Group("/push")
	push.Post("/devices", deps.Push.RegisterDevice)
	push.Get("/devices", deps.Push.ListDevices)
	push.Delete("/devices/:token", deps.Push.UnregisterDevice)
	push.Post("/test", deps.Push.SendTestPush)

	// Analytics endpoints (PRO only)
	analytics := protected.Group("/analytics")
	analytics.Use(middleware.NewRequireProFeatureMiddleware("advanced_analytics"))
	analytics.Get("/weekly-report", deps.Analytics.WeeklyReport)
	analytics.Get("/monthly-report", deps.Analytics.MonthlyReport)
	analytics.Get("/completion-rate", deps.Analytics.CompletionRate)
	analytics.Get("/streak", deps.Analytics.StreakStats)

	preferences := protected.Group("/preferences")
	preferences.Get("/", deps.Preferences.List)
	preferences.Put("/", deps.Preferences.Upsert)

	sync := protected.Group("/sync")
	sync.Get("/full", deps.Sync.FullSync)
	sync.Post("/sessions", deps.Sync.SyncSessions)
	sync.Post("/initial-upload", deps.Sync.InitialUpload)

	// WebSocket endpoint: JWT validated via Authorization header (or
	// Sec-WebSocket-Protocol sub-protocol) before upgrade. Query param is a
	// deprecated fallback gated by DEPRECATED_WS_QUERY_AUTH.
	api.Use("/ws", deps.WebSocket.WebSocketUpgrade)
	api.Get("/ws", fiberws.New(deps.WebSocket.HandleWebSocket))
}

// emailKeyGenerator returns a Fiber limiter KeyGenerator that keys by the
// submitted email (normalized lower-case + trimmed) under the given namespace,
// falling back to c.IP() when the email cannot be extracted. Chain this after
// the per-IP limiter so both bucket independently: a credential-stuffer that
// rotates IPs but targets one account hits the email bucket; a bot scanning
// from one IP hits the IP bucket.
func emailKeyGenerator(namespace string) func(*fiber.Ctx) string {
	return func(c *fiber.Ctx) string {
		email := extractEmailFromBody(c.Body())
		if email == "" {
			return namespace + ":ip:" + c.IP()
		}
		return namespace + ":email:" + email
	}
}

// refreshTokenUserKeyGenerator keys by the userID claim in the (unverified)
// refresh token. Verification happens inside the handler; here we only need a
// stable identity for rate limiting. Falls back to c.IP() if the token is
// missing, malformed, or has no userID.
func refreshTokenUserKeyGenerator() func(*fiber.Ctx) string {
	return func(c *fiber.Ctx) string {
		token := extractStringField(c.Body(), "refreshToken")
		if token == "" {
			return "auth:refresh:ip:" + c.IP()
		}
		if uid := unsafeUserIDFromJWT(token); uid != "" {
			return "auth:refresh:user:" + uid
		}
		return "auth:refresh:ip:" + c.IP()
	}
}

// extractEmailFromBody reads the "email" field from a JSON body without
// mutating the buffer. Returns "" when the body is not JSON or the field is
// absent. The body slice from Fiber is safe to read multiple times.
func extractEmailFromBody(body []byte) string {
	email := extractStringField(body, "email")
	return strings.ToLower(strings.TrimSpace(email))
}

func extractStringField(body []byte, field string) string {
	if len(body) == 0 {
		return ""
	}
	var payload map[string]any
	if err := json.Unmarshal(body, &payload); err != nil {
		return ""
	}
	v, ok := payload[field].(string)
	if !ok {
		return ""
	}
	return v
}

// unsafeUserIDFromJWT decodes a JWT without verifying its signature and
// returns the userID claim. Used ONLY for rate-limiter key derivation; the
// handler still validates the token cryptographically before trusting it.
func unsafeUserIDFromJWT(token string) string {
	parser := jwtParser()
	claims := &middleware.UserClaims{}
	_, _, err := parser.ParseUnverified(token, claims)
	if err != nil {
		return ""
	}
	return claims.UserID
}
