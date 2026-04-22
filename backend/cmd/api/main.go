package main

import (
	"context"
	cryptorand "crypto/rand"
	"log/slog"
	"net/http"
	"os"
	"strings"
	"time"

	sentryfiber "github.com/getsentry/sentry-go/fiber"
	"github.com/gofiber/fiber/v2"
	"github.com/gofiber/fiber/v2/middleware/compress"
	"github.com/gofiber/fiber/v2/middleware/cors"
	"github.com/gofiber/fiber/v2/middleware/helmet"
	"github.com/gofiber/fiber/v2/middleware/limiter"
	"github.com/golang-migrate/migrate/v4"
	_ "github.com/golang-migrate/migrate/v4/database/postgres"
	_ "github.com/golang-migrate/migrate/v4/source/file"

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
		// Logger not yet initialized — fall back to default slog so the
		// boot failure still produces a structured record.
		slog.Error("failed to load config", "error", err)
		os.Exit(1)
	}

	// Initialize structured JSON logger BEFORE anything else so every
	// subsequent line (including migrations, Sentry init, Fiber boot) is
	// structured. Level is env-driven via LOG_LEVEL.
	observability.InitLogger(observability.LoggerConfig{
		Level:       cfg.LogLevel,
		Environment: cfg.Environment,
		Service:     "pepinillo-backend",
	})

	// Initialize Sentry BEFORE the Fiber app so the middleware can attach.
	// When SENTRY_DSN is empty this is a no-op (dev default).
	if observability.InitSentry(observability.SentryConfig{
		DSN:              cfg.SentryDSN,
		Environment:      cfg.Environment,
		Release:          cfg.SentryRelease,
		SampleRate:       cfg.SentrySampleRate,
		TracesSampleRate: cfg.SentryTracesSampleRate,
		AttachStacktrace: true,
	}) {
		defer observability.FlushSentry(2 * time.Second)
	}

	runMigrations(cfg.DatabaseURL)

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

	// Sentry Fiber middleware: captures panics and propagates request
	// context (URL, method, headers minus cookies) to reported events. It
	// is safe to attach when Sentry is disabled — the middleware no-ops
	// when the hub has no client.
	app.Use(sentryfiber.New(sentryfiber.Options{
		Repanic:         true,
		WaitForDelivery: false,
	}))

	app.Use(helmet.New())
	app.Use(compress.New(compress.Config{
		Level: compress.LevelDefault,
	}))
	// CORS: config.Load() already rejects empty or "*" origins when APP_ENV=production.
	// In development, warn loudly if the config allows any origin — devs sometimes
	// copy those settings to prod, and the production guard is the last line of defense.
	corsOrigins := cfg.CORSAllowedOrigins
	if corsOrigins == "" {
		slog.Warn("CORS_ALLOWED_ORIGINS is empty; falling back to \"*\" (development only)")
		corsOrigins = "*"
	} else if strings.Contains(corsOrigins, "*") {
		slog.Warn("CORS_ALLOWED_ORIGINS contains \"*\" (development only — production boot rejects this)")
	}
	app.Use(cors.New(cors.Config{
		AllowOrigins: corsOrigins,
		AllowHeaders: "Origin, Content-Type, Accept, Authorization",
		AllowMethods: "GET,POST,PUT,DELETE,PATCH,OPTIONS",
	}))
	app.Use(limiter.New(limiter.Config{
		Max:        120,
		Expiration: time.Minute,
	}))

	db, err := postgres.NewDBWithPool(cfg.DatabaseURL, postgres.PoolConfig{
		MaxOpenConns:    int(cfg.DBMaxOpenConns),
		MaxIdleConns:    int(cfg.DBMaxIdleConns),
		ConnMaxLifetime: time.Duration(cfg.DBConnMaxLifetimeSeconds) * time.Second,
		ConnMaxIdleTime: time.Duration(cfg.DBConnMaxIdleTimeSeconds) * time.Second,
	})
	if err != nil {
		slog.Error("failed to connect database", "error", err)
		observability.CaptureError(err, map[string]string{"stage": "db_connect"})
		os.Exit(1)
	}

	userRepo := postgres.NewUserRepository(db)
	taskRepo := postgres.NewTaskRepository(db)
	deviceTokenRepo := postgres.NewDeviceTokenRepository(db)
	subtaskRepo := postgres.NewSubTaskRepository(db)
	pomodoroRepo := postgres.NewPomodoroRepository(db)
	aiRepo := postgres.NewAIInsightRepository(db)

	// Refresh tokens are hashed with HMAC-SHA-256 keyed by REFRESH_TOKEN_HASH_KEY
	// before being stored. config.Load() enforces a non-empty 32+ byte key in
	// production; in development we pad short/empty keys with a random suffix
	// so the stores (which require ≥32 bytes) still construct and local
	// iteration works without configuration.
	hashKey := []byte(cfg.RefreshTokenHashKey)
	if len(hashKey) < 32 {
		if len(hashKey) > 0 {
			slog.Warn("REFRESH_TOKEN_HASH_KEY is shorter than 32 bytes; padding with random bytes (development only)")
		}
		padding := make([]byte, 32-len(hashKey))
		if _, err := cryptorand.Read(padding); err != nil {
			slog.Error("failed to generate refresh token hash key padding", "error", err)
			os.Exit(1)
		}
		hashKey = append(hashKey, padding...)
	}
	var authStore ports.AuthStore
	if cfg.RedisURL != "" {
		store, err := redisStore.NewAuthStore(cfg.RedisURL, hashKey)
		if err != nil {
			slog.Warn("redis unavailable, using memory auth store", "error", err)
			authStore = memoryStore.NewAuthStoreWithKey(hashKey)
		} else {
			authStore = store
		}
	} else {
		authStore = memoryStore.NewAuthStoreWithKey(hashKey)
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
			slog.Warn("minio unavailable, using noop storage", "error", err)
		} else {
			fileStorage = storage
		}
	}

	behaviorLog := behavior.NewPostgresLogger(db)

	// WebSocket Hub and Manager
	wsHub := websocket.NewHub()
	go wsHub.Run()
	wsManager := websocket.NewManager(wsHub)
	slog.Info("WebSocket Hub and Manager initialized")

	// Email provider: SendGrid if API key present, else fallback to log notifier
	var emailNotifier ports.Notifier
	if cfg.EmailProvider == "sendgrid" && cfg.SendGridAPIKey != "" {
		emailNotifier = notifier.NewFallbackNotifier(cfg.SendGridAPIKey, cfg.SendGridFromEmail, cfg.SendGridFromName)
	} else {
		emailNotifier = notifier.NewLogNotifier()
		if cfg.EmailProvider == "sendgrid" {
			slog.Warn("EMAIL_PROVIDER=sendgrid but SENDGRID_API_KEY not set, using log notifier")
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

	var googleClientIDs []string
	if cfg.GoogleClientIDs != "" {
		for _, id := range strings.Split(cfg.GoogleClientIDs, ",") {
			if trimmed := strings.TrimSpace(id); trimmed != "" {
				googleClientIDs = append(googleClientIDs, trimmed)
			}
		}
	}

	oauthService := services.NewOAuthService(
		userRepo,
		authStore,
		cfg.JWTSecret,
		cfg.JWTIssuer,
		cfg.JWTAccessTTLSeconds,
		cfg.JWTRefreshTTLSeconds,
		googleClientIDs,
		cfg.AppleBundleID,
	)

	focusRepo := postgres.NewFocusRepository(db)

	taskService := services.NewTaskService(taskRepo, behaviorLog, wsManager)
	subtaskService := services.NewSubTaskService(subtaskRepo, taskRepo, behaviorLog)
	pomodoroService := services.NewPomodoroService(pomodoroRepo, behaviorLog, wsManager)
	focusService := services.NewFocusService(focusRepo, behaviorLog, wsManager)
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

	// Initialize RevenueCat service
	revenuecatService := services.NewRevenueCatService(userRepo, services.RevenueCatConfig{
		APIKey:           cfg.RevenueCatAPIKey,
		WebhookAuthToken: cfg.RevenueCatWebhookAuthToken,
		APIBaseURL:       cfg.RevenueCatAPIBaseURL,
	}, behaviorLog)
	billingService.SetRevenueCatService(revenuecatService)
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
		slog.Info("push provider configured", "mode", "fcm")
	case "apns":
		pushProvider = muxPush.NewProvider(apnsProvider, noopProvider, noopProvider)
		slog.Info("push provider configured", "mode", "apns")
	case "hybrid":
		pushProvider = muxPush.NewProvider(apnsProvider, fcmProvider, noopProvider)
		slog.Info("push provider configured", "mode", "hybrid")
	default:
		pushProvider = muxPush.NewProvider(noopProvider, noopProvider, noopProvider)
		slog.Info("push provider configured", "mode", "noop")
	}
	pushService := services.NewPushService(deviceTokenRepo, pushProvider, behaviorLog)

	// LLM provider: Gemini if API key present, else noop (graceful fallback)
	var llmProvider ports.LLMProvider
	if cfg.GeminiAPIKey != "" {
		llmProvider = geminiLLM.NewProvider(cfg.GeminiAPIKey)
		slog.Info("Gemini 2.5 Flash LLM provider enabled")
	} else {
		llmProvider = noopLLM.NewProvider()
		slog.Info("No GEMINI_API_KEY set — AI endpoints will use fallback responses")
	}

	aiService := services.NewAIService(aiRepo, taskRepo, pomodoroRepo, llmProvider, cfg.MLServiceURL)
	startRecurringTaskGenerator(taskService, pushService)

	preferenceRepo := postgres.NewPreferenceRepository(db)
	preferenceService := services.NewPreferenceService(preferenceRepo, wsManager)

	syncService := services.NewSyncService(focusRepo, taskRepo, preferenceRepo, wsManager)

	analyticsRepo := postgres.NewAnalyticsRepository(db)
	analyticsService := services.NewAnalyticsService(analyticsRepo)

	routeDeps := handlers.RouteHandlers{
		Auth:       handlers.NewAuthHandler(authService),
		OAuth:      handlers.NewOAuthHandler(oauthService),
		Users:      handlers.NewUserHandler(userRepo, fileStorage),
		Tasks:      handlers.NewTaskHandler(taskService),
		SubTasks:   handlers.NewSubTaskHandler(subtaskService),
		Pomodoro:   handlers.NewPomodoroHandler(pomodoroService),
		Focus:      handlers.NewFocusHandler(focusService),
		AI:         handlers.NewAIHandler(aiService),
		Billing:    handlers.NewBillingHandler(billingService),
		RevenueCat: handlers.NewRevenueCatHandler(revenuecatService),
		Push:       handlers.NewPushHandler(pushService),
		WebSocket:  handlers.NewWebSocketHandler(wsManager, cfg.JWTSecret, cfg.DeprecatedWSQueryAuth),
		Analytics:   handlers.NewAnalyticsHandler(analyticsService),
		Preferences: handlers.NewPreferenceHandler(preferenceService),
		Sync:           handlers.NewSyncHandler(syncService),
		UserRepository: userRepo,
		JWTSecret:      cfg.JWTSecret,
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
				store, err := redisStore.NewAuthStore(cfg.RedisURL, hashKey)
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

	slog.Info("Pepinillo API listening", "port", cfg.Port)
	if err := app.Listen(":" + cfg.Port); err != nil {
		slog.Error("failed to start server", "error", err)
		observability.CaptureError(err, map[string]string{"stage": "fiber_listen"})
		os.Exit(1)
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
				slog.Error("recurrence generator failed", "error", err)
				observability.CaptureError(err, map[string]string{"stage": "recurrence_generator"})
				return
			}

			for _, row := range byUser {
				if err := pushService.SendRecurrenceGeneratedPush(context.Background(), row.UserID, row.Created, services.RecurrencePushWindow{
					From: from,
					To:   to,
				}); err != nil {
					slog.Error("recurrence push failed", "userId", row.UserID, "error", err)
					observability.CaptureError(err, map[string]string{
						"stage":  "recurrence_push",
						"userId": row.UserID,
					})
				}
			}

			slog.Info("recurrence generator completed", "users", users, "created", created)
		}

		run()
		ticker := time.NewTicker(24 * time.Hour)
		defer ticker.Stop()

		for range ticker.C {
			run()
		}
	}()
}

func runMigrations(databaseURL string) {
	m, err := migrate.New(
		"file://migrations",
		databaseURL,
	)
	if err != nil {
		slog.Warn("migration setup skipped", "error", err)
		return
	}
	defer m.Close()

	if err := m.Up(); err != nil && err != migrate.ErrNoChange {
		slog.Error("migration failed", "error", err)
		observability.CaptureError(err, map[string]string{"stage": "migrations"})
		os.Exit(1)
	}
	slog.Info("database migrations applied successfully")
}
