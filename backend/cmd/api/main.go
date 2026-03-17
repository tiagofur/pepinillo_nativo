package main

import (
	"context"
	"log"
	"net/http"
	"strings"
	"time"

	"github.com/gofiber/fiber/v2"
	"github.com/gofiber/fiber/v2/middleware/cors"
	"github.com/gofiber/fiber/v2/middleware/helmet"
	"github.com/gofiber/fiber/v2/middleware/limiter"

	"pepinillo/backend/internal/adapters/behavior"
	"pepinillo/backend/internal/adapters/handlers"
	geminiLLM "pepinillo/backend/internal/adapters/llm/gemini"
	noopLLM "pepinillo/backend/internal/adapters/llm/noop"
	"pepinillo/backend/internal/adapters/notifier"
	apnsPush "pepinillo/backend/internal/adapters/push/apns"
	fcmPush "pepinillo/backend/internal/adapters/push/fcm"
	muxPush "pepinillo/backend/internal/adapters/push/mux"
	noopPush "pepinillo/backend/internal/adapters/push/noop"
	"pepinillo/backend/internal/adapters/repositories/postgres"
	minioStorage "pepinillo/backend/internal/adapters/storage/minio"
	noopStorage "pepinillo/backend/internal/adapters/storage/noop"
	memoryStore "pepinillo/backend/internal/adapters/stores/memory"
	redisStore "pepinillo/backend/internal/adapters/stores/redis"
	"pepinillo/backend/internal/adapters/websocket"
	"pepinillo/backend/internal/config"
	"pepinillo/backend/internal/observability"
	"pepinillo/backend/internal/ports"
	"pepinillo/backend/internal/services"
)

func main() {
	cfg, err := config.Load()
	if err != nil {
		log.Fatalf("failed to load config: %v", err)
	}
	observability.ConfigureAlertRules(observability.AlertRules{
		BillingMinSamples:                 cfg.AlertBillingMinSamples,
		BillingFailureRatioWarnPct:        cfg.AlertBillingFailureRatioWarnPct,
		BillingFailureRatioCriticalPct:    cfg.AlertBillingFailureRatioCriticalPct,
		PushFailureRatioWarnPct:           cfg.AlertPushFailureRatioWarnPct,
		PushFailureRatioCriticalPct:       cfg.AlertPushFailureRatioCriticalPct,
		RecurrenceFailureRatioWarnPct:     cfg.AlertRecurrenceFailureRatioWarnPct,
		RecurrenceFailureRatioCriticalPct: cfg.AlertRecurrenceFailureRatioCriticalPct,
		AlertCooldownSeconds:              cfg.AlertCooldownSeconds,
		AlertMuteWindowEnabled:            cfg.AlertMuteWindowEnabled,
		AlertMuteStartHourUTC:             cfg.AlertMuteStartHourUTC,
		AlertMuteEndHourUTC:               cfg.AlertMuteEndHourUTC,
	})

	app := fiber.New(fiber.Config{
		AppName:      "Pepinillo API",
		ErrorHandler: handlers.ErrorHandler,
	})

	app.Use(helmet.New())
	app.Use(cors.New(cors.Config{
		AllowOrigins: cfg.CORSAllowedOrigins,
		AllowHeaders: "Origin, Content-Type, Accept, Authorization",
		AllowMethods: "GET,POST,PUT,DELETE,PATCH,OPTIONS",
	}))
	app.Use(limiter.New(limiter.Config{
		Max:        120,
		Expiration: time.Minute,
	}))

	db, err := postgres.NewDB(cfg.DatabaseURL)
	if err != nil {
		log.Fatalf("failed to connect database: %v", err)
	}

	userRepo := postgres.NewUserRepository(db)
	taskRepo := postgres.NewTaskRepository(db)
	deviceTokenRepo := postgres.NewDeviceTokenRepository(db)
	subtaskRepo := postgres.NewSubTaskRepository(db)
	pomodoroRepo := postgres.NewPomodoroRepository(db)
	aiRepo := postgres.NewAIInsightRepository(db)

	var authStore ports.AuthStore
	if cfg.RedisURL != "" {
		store, err := redisStore.NewAuthStore(cfg.RedisURL)
		if err != nil {
			log.Printf("redis unavailable, using memory auth store: %v", err)
			authStore = memoryStore.NewAuthStore()
		} else {
			authStore = store
		}
	} else {
		authStore = memoryStore.NewAuthStore()
	}

	var fileStorage ports.FileStorage = noopStorage.NewStorage()
	if cfg.MinIOEndpoint != "" && cfg.MinIOAccessKey != "" && cfg.MinIOSecretKey != "" {
		storage, err := minioStorage.NewStorage(
			cfg.MinIOEndpoint,
			cfg.MinIOAccessKey,
			cfg.MinIOSecretKey,
			cfg.MinIOBucket,
			cfg.MinIOPublicBaseURL,
			cfg.MinIOUseSSL,
		)
		if err != nil {
			log.Printf("minio unavailable, using noop storage: %v", err)
		} else {
			fileStorage = storage
		}
	}

	behaviorLog := behavior.NewPostgresLogger(db)

	// WebSocket Hub and Manager
	wsHub := websocket.NewHub()
	go wsHub.Run()
	wsManager := websocket.NewManager(wsHub)
	log.Println("WebSocket Hub and Manager initialized")

	// Email provider: SendGrid if API key present, else fallback to log notifier
	var emailNotifier ports.Notifier
	if cfg.EmailProvider == "sendgrid" && cfg.SendGridAPIKey != "" {
		emailNotifier = notifier.NewFallbackNotifier(cfg.SendGridAPIKey, cfg.SendGridFromEmail, cfg.SendGridFromName)
	} else {
		emailNotifier = notifier.NewLogNotifier()
		if cfg.EmailProvider == "sendgrid" {
			log.Println("EMAIL_PROVIDER=sendgrid but SENDGRID_API_KEY not set, using log notifier")
		}
	}

	authService := services.NewAuthService(
		userRepo,
		authStore,
		emailNotifier,
		behaviorLog,
		wsManager,
		cfg.JWTSecret,
		cfg.JWTIssuer,
		cfg.JWTAccessTTLSeconds,
		cfg.JWTRefreshTTLSeconds,
	)
	taskService := services.NewTaskService(taskRepo, behaviorLog, wsManager)
	subtaskService := services.NewSubTaskService(subtaskRepo, taskRepo, behaviorLog)
	pomodoroService := services.NewPomodoroService(pomodoroRepo, behaviorLog, wsManager)
	billingService := services.NewBillingService(userRepo, services.BillingConfig{
		GooglePlayPackageName:              cfg.GooglePlayPackageName,
		GooglePlayAPIToken:                 cfg.GooglePlayAPIToken,
		GooglePlayAPIBaseURL:               cfg.GooglePlayAPIBaseURL,
		GooglePlayServiceAccountEmail:      cfg.GooglePlayServiceAccountEmail,
		GooglePlayServiceAccountPrivateKey: cfg.GooglePlayServiceAccountPrivateKey,
		GooglePlayOAuthTokenURL:            cfg.GooglePlayOAuthTokenURL,
		GooglePlayOAuthScope:               cfg.GooglePlayOAuthScope,
		AppStoreSharedSecret:               cfg.AppStoreSharedSecret,
		AppStoreVerifyReceiptURL:           cfg.AppStoreVerifyReceiptURL,
		AppStoreSandboxVerifyReceiptURL:    cfg.AppStoreSandboxVerifyReceiptURL,
		AppStoreServerAPIIssuerID:          cfg.AppStoreServerAPIIssuerID,
		AppStoreServerAPIKeyID:             cfg.AppStoreServerAPIKeyID,
		AppStoreServerAPIPrivateKey:        cfg.AppStoreServerAPIPrivateKey,
		AppStoreServerAPIBundleID:          cfg.AppStoreServerAPIBundleID,
		AppStoreServerAPIBaseURL:           cfg.AppStoreServerAPIBaseURL,
	}, behaviorLog)
	noopProvider := noopPush.NewProvider()
	fcmProvider := fcmPush.NewProvider(fcmPush.Config{
		ProjectID:                cfg.FCMProjectID,
		ServiceAccountEmail:      cfg.FCMServiceAccountEmail,
		ServiceAccountPrivateKey: cfg.FCMServiceAccountPrivateKey,
		OAuthTokenURL:            cfg.FCMOAuthTokenURL,
		OAuthScope:               cfg.FCMOAuthScope,
		APIBaseURL:               cfg.FCMAPIBaseURL,
	})
	apnsProvider := apnsPush.NewProvider(apnsPush.Config{
		TeamID:     cfg.APNSTeamID,
		KeyID:      cfg.APNSKeyID,
		PrivateKey: cfg.APNSPrivateKey,
		Topic:      cfg.APNSTopic,
		BaseURL:    cfg.APNSBaseURL,
	})

	pushMode := strings.ToLower(strings.TrimSpace(cfg.PushProvider))
	var pushProvider ports.PushProvider
	switch pushMode {
	case "fcm":
		pushProvider = muxPush.NewProvider(fcmProvider, fcmProvider, noopProvider)
		log.Println("Push provider mode: fcm")
	case "apns":
		pushProvider = muxPush.NewProvider(apnsProvider, noopProvider, noopProvider)
		log.Println("Push provider mode: apns")
	case "hybrid":
		pushProvider = muxPush.NewProvider(apnsProvider, fcmProvider, noopProvider)
		log.Println("Push provider mode: hybrid")
	default:
		pushProvider = muxPush.NewProvider(noopProvider, noopProvider, noopProvider)
		log.Println("Push provider mode: noop")
	}
	pushService := services.NewPushService(deviceTokenRepo, pushProvider, behaviorLog)

	// LLM provider: Gemini if API key present, else noop (graceful fallback)
	var llmProvider ports.LLMProvider
	if cfg.GeminiAPIKey != "" {
		llmProvider = geminiLLM.NewProvider(cfg.GeminiAPIKey)
		log.Println("Gemini 2.5 Flash LLM provider enabled")
	} else {
		llmProvider = noopLLM.NewProvider()
		log.Println("No GEMINI_API_KEY set — AI endpoints will use fallback responses")
	}

	aiService := services.NewAIService(aiRepo, taskRepo, pomodoroRepo, llmProvider, cfg.MLServiceURL)
	startRecurringTaskGenerator(taskService, pushService)

	routeDeps := handlers.RouteHandlers{
		Auth:      handlers.NewAuthHandler(authService),
		Users:     handlers.NewUserHandler(userRepo, fileStorage),
		Tasks:     handlers.NewTaskHandler(taskService),
		SubTasks:  handlers.NewSubTaskHandler(subtaskService),
		Pomodoro:  handlers.NewPomodoroHandler(pomodoroService),
		AI:        handlers.NewAIHandler(aiService),
		Billing:   handlers.NewBillingHandler(billingService),
		Push:      handlers.NewPushHandler(pushService),
		WebSocket: handlers.NewWebSocketHandler(wsManager, cfg.JWTSecret),
		JWTSecret: cfg.JWTSecret,
		HealthChecks: handlers.DependencyChecksFrom(
			func(ctx context.Context) error {
				sqlDB, err := db.DB()
				if err != nil {
					return err
				}
				return sqlDB.PingContext(ctx)
			},
			func(ctx context.Context) error {
				if cfg.RedisURL == "" {
					return nil
				}
				store, err := redisStore.NewAuthStore(cfg.RedisURL)
				if err != nil {
					return err
				}
				return store.Ping(ctx)
			},
			func(ctx context.Context) error {
				if cfg.MinIOEndpoint == "" {
					return nil
				}
				_, err := minioStorage.NewStorage(
					cfg.MinIOEndpoint,
					cfg.MinIOAccessKey,
					cfg.MinIOSecretKey,
					cfg.MinIOBucket,
					cfg.MinIOPublicBaseURL,
					cfg.MinIOUseSSL,
				)
				return err
			},
			func(ctx context.Context) error {
				if cfg.MLServiceURL == "" {
					return nil
				}
				req, err := http.NewRequestWithContext(ctx, http.MethodGet, cfg.MLServiceURL+"/health", nil)
				if err != nil {
					return err
				}
				resp, err := http.DefaultClient.Do(req)
				if err != nil {
					return err
				}
				defer resp.Body.Close()
				if resp.StatusCode < 200 || resp.StatusCode >= 300 {
					return fiber.NewError(resp.StatusCode, "ml_health_failed")
				}
				return nil
			},
		),
	}

	api := app.Group("/api/v1")
	handlers.RegisterAPIRoutes(api, routeDeps)

	log.Printf("Pepinillo API listening on :%s", cfg.Port)
	if err := app.Listen(":" + cfg.Port); err != nil {
		log.Fatalf("failed to start server: %v", err)
	}
}

func startRecurringTaskGenerator(taskService *services.TaskService, pushService *services.PushService) {
	go func() {
		run := func() {
			now := time.Now().UTC()
			from := now
			to := now.AddDate(0, 0, 14)
			users, created, byUser, err := taskService.GenerateRecurrencesForAllUsersWithSummary(context.Background(), from, to)
			if err != nil {
				log.Printf("recurrence generator failed: %v", err)
				return
			}

			for _, row := range byUser {
				if err := pushService.SendRecurrenceGeneratedPush(context.Background(), row.UserID, row.Created, services.RecurrencePushWindow{
					From: from,
					To:   to,
				}); err != nil {
					log.Printf("recurrence push failed user=%s: %v", row.UserID, err)
				}
			}

			log.Printf("recurrence generator completed: users=%d created=%d", users, created)
		}

		run()
		ticker := time.NewTicker(24 * time.Hour)
		defer ticker.Stop()

		for range ticker.C {
			run()
		}
	}()
}
