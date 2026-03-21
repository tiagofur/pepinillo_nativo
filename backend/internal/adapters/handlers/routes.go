package handlers

import (
	fiberws "github.com/gofiber/contrib/websocket"
	"github.com/gofiber/fiber/v2"
	"github.com/gofiber/fiber/v2/middleware/limiter"

	"pepinillo/backend/internal/adapters/middleware"
)

type RouteHandlers struct {
	Auth         *AuthHandler
	OAuth        *OAuthHandler
	Users        *UserHandler
	Tasks        *TaskHandler
	SubTasks     *SubTaskHandler
	Pomodoro     *PomodoroHandler
	AI           *AIHandler
	Billing      *BillingHandler
	Push         *PushHandler
	WebSocket    *WebSocketHandler
	JWTSecret    string
	HealthChecks DependencyChecks
}

func RegisterAPIRoutes(api fiber.Router, deps RouteHandlers) {
	RegisterHealthRoutes(api, deps.HealthChecks)

	auth := api.Group("/auth")
	authLimiter := limiter.New(limiter.Config{Max: 60})
	loginRegisterLimiter := limiter.New(limiter.Config{Max: 5})
	refreshLimiter := limiter.New(limiter.Config{Max: 10})
	passwordRecoveryLimiter := limiter.New(limiter.Config{Max: 5})
	emailVerificationLimiter := limiter.New(limiter.Config{Max: 10})
	auth.Use(authLimiter)
	auth.Post("/register", loginRegisterLimiter, deps.Auth.Register)
	auth.Post("/login", loginRegisterLimiter, deps.Auth.Login)
	auth.Post("/google", loginRegisterLimiter, deps.OAuth.LoginWithGoogle)
	auth.Post("/apple", loginRegisterLimiter, deps.OAuth.LoginWithApple)
	auth.Post("/refresh", refreshLimiter, deps.Auth.Refresh)
	auth.Post("/forgot-password", passwordRecoveryLimiter, deps.Auth.ForgotPassword)
	auth.Post("/reset-password", passwordRecoveryLimiter, deps.Auth.ResetPassword)
	auth.Post("/verify-email", emailVerificationLimiter, deps.Auth.VerifyEmail)
	auth.Post("/resend-verification", emailVerificationLimiter, deps.Auth.ResendVerification)

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

	ai := protected.Group("/ai")
	ai.Get("/daily-tip", deps.AI.DailyTip)
	ai.Get("/insights", deps.AI.ListInsights)
	ai.Get("/weekly-report", deps.AI.WeeklyReport)
	ai.Post("/analyze", deps.AI.Analyze)
	ai.Get("/predictions/productivity", deps.AI.ProductivityPrediction)
	ai.Get("/predictions/burnout-risk", deps.AI.BurnoutRisk)
	ai.Get("/optimal-hours", deps.AI.OptimalHours)

	billing := protected.Group("/billing")
	billing.Post("/verify-receipt", deps.Billing.VerifyReceipt)

	push := protected.Group("/push")
	push.Post("/devices", deps.Push.RegisterDevice)
	push.Get("/devices", deps.Push.ListDevices)
	push.Delete("/devices/:token", deps.Push.UnregisterDevice)
	push.Post("/test", deps.Push.SendTestPush)

	// WebSocket endpoint: JWT validated via query param before upgrade
	api.Use("/ws", deps.WebSocket.WebSocketUpgrade)
	api.Get("/ws", fiberws.New(deps.WebSocket.HandleWebSocket))
}
