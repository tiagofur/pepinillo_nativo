package config

import (
	"fmt"
	"os"
	"strconv"

	"github.com/joho/godotenv"
)

type Config struct {
	Port                                   string
	Environment                            string
	CORSAllowedOrigins                     string
	DatabaseURL                            string
	RedisURL                               string
	JWTSecret                              string
	JWTIssuer                              string
	JWTAccessTTLSeconds                    int64
	JWTRefreshTTLSeconds                   int64
	MinIOEndpoint                          string
	MinIOAccessKey                         string
	MinIOSecretKey                         string
	MinIOBucket                            string
	MinIOUseSSL                            bool
	MinIOPublicBaseURL                     string
	LLMProvider                            string
	LLMApiKey                              string
	MLServiceURL                           string
	GeminiAPIKey                           string
	SendGridAPIKey                         string
	SendGridFromEmail                      string
	SendGridFromName                       string
	EmailProvider                          string
	GooglePlayPackageName                  string
	GooglePlayAPIToken                     string
	GooglePlayAPIBaseURL                   string
	GooglePlayServiceAccountEmail          string
	GooglePlayServiceAccountPrivateKey     string
	GooglePlayOAuthTokenURL                string
	GooglePlayOAuthScope                   string
	AppStoreSharedSecret                   string
	AppStoreVerifyReceiptURL               string
	AppStoreSandboxVerifyReceiptURL        string
	AppStoreServerAPIIssuerID              string
	AppStoreServerAPIKeyID                 string
	AppStoreServerAPIPrivateKey            string
	AppStoreServerAPIBundleID              string
	AppStoreServerAPIBaseURL               string
	PushProvider                           string
	FCMProjectID                           string
	FCMServiceAccountEmail                 string
	FCMServiceAccountPrivateKey            string
	FCMOAuthTokenURL                       string
	FCMOAuthScope                          string
	FCMAPIBaseURL                          string
	APNSTeamID                             string
	APNSKeyID                              string
	APNSPrivateKey                         string
	APNSTopic                              string
	APNSBaseURL                            string
	AlertBillingMinSamples                 int64
	AlertBillingFailureRatioWarnPct        int64
	AlertBillingFailureRatioCriticalPct    int64
	AlertPushFailureRatioWarnPct           int64
	AlertPushFailureRatioCriticalPct       int64
	AlertRecurrenceFailureRatioWarnPct     int64
	AlertRecurrenceFailureRatioCriticalPct int64
	AlertCooldownSeconds                   int64
	AlertMuteWindowEnabled                 bool
	AlertMuteStartHourUTC                  int64
	AlertMuteEndHourUTC                    int64
	GoogleClientIDs                        string
	AppleBundleID                          string
	RevenueCatAPIKey                       string
	RevenueCatSecretKey                    string // Secret API Key (V2) for server-to-server validation
	RevenueCatWebhookAuthToken             string
	RevenueCatAPIBaseURL                   string
}

func Load() (*Config, error) {
	_ = godotenv.Load()

	cfg := &Config{
		Port:                                   getEnv("PORT", "8080"),
		Environment:                            getEnv("APP_ENV", "development"),
		CORSAllowedOrigins:                     getEnv("CORS_ALLOWED_ORIGINS", "*"),
		DatabaseURL:                            getEnv("DATABASE_URL", ""),
		RedisURL:                               getEnv("REDIS_URL", ""),
		JWTSecret:                              getEnv("JWT_SECRET", ""),
		JWTIssuer:                              getEnv("JWT_ISSUER", "pepinillo-api"),
		JWTAccessTTLSeconds:                    getEnvInt64("JWT_ACCESS_TTL_SECONDS", 900),
		JWTRefreshTTLSeconds:                   getEnvInt64("JWT_REFRESH_TTL_SECONDS", 2592000),
		MinIOEndpoint:                          getEnv("MINIO_ENDPOINT", ""),
		MinIOAccessKey:                         getEnv("MINIO_ACCESS_KEY", ""),
		MinIOSecretKey:                         getEnv("MINIO_SECRET_KEY", ""),
		MinIOBucket:                            getEnv("MINIO_BUCKET", "profiles"),
		MinIOUseSSL:                            getEnv("MINIO_USE_SSL", "false") == "true",
		MinIOPublicBaseURL:                     getEnv("MINIO_PUBLIC_BASE_URL", "http://localhost:9000"),
		LLMProvider:                            getEnv("LLM_PROVIDER", "openai"),
		LLMApiKey:                              getEnv("LLM_API_KEY", ""),
		MLServiceURL:                           getEnv("ML_SERVICE_URL", "http://ml-service:8001"),
		GeminiAPIKey:                           getEnv("GEMINI_API_KEY", ""),
		SendGridAPIKey:                         getEnv("SENDGRID_API_KEY", ""),
		SendGridFromEmail:                      getEnv("SENDGRID_FROM_EMAIL", "noreply@pepinillo.app"),
		SendGridFromName:                       getEnv("SENDGRID_FROM_NAME", "Pepinillo"),
		EmailProvider:                          getEnv("EMAIL_PROVIDER", "log"),
		GooglePlayPackageName:                  getEnv("GOOGLE_PLAY_PACKAGE_NAME", ""),
		GooglePlayAPIToken:                     getEnv("GOOGLE_PLAY_API_TOKEN", ""),
		GooglePlayAPIBaseURL:                   getEnv("GOOGLE_PLAY_API_BASE_URL", "https://androidpublisher.googleapis.com"),
		GooglePlayServiceAccountEmail:          getEnv("GOOGLE_PLAY_SERVICE_ACCOUNT_EMAIL", ""),
		GooglePlayServiceAccountPrivateKey:     getEnv("GOOGLE_PLAY_SERVICE_ACCOUNT_PRIVATE_KEY", ""),
		GooglePlayOAuthTokenURL:                getEnv("GOOGLE_PLAY_OAUTH_TOKEN_URL", "https://oauth2.googleapis.com/token"),
		GooglePlayOAuthScope:                   getEnv("GOOGLE_PLAY_OAUTH_SCOPE", "https://www.googleapis.com/auth/androidpublisher"),
		AppStoreSharedSecret:                   getEnv("APP_STORE_SHARED_SECRET", ""),
		AppStoreVerifyReceiptURL:               getEnv("APP_STORE_VERIFY_RECEIPT_URL", "https://buy.itunes.apple.com/verifyReceipt"),
		AppStoreSandboxVerifyReceiptURL:        getEnv("APP_STORE_SANDBOX_VERIFY_RECEIPT_URL", "https://sandbox.itunes.apple.com/verifyReceipt"),
		AppStoreServerAPIIssuerID:              getEnv("APP_STORE_SERVER_API_ISSUER_ID", ""),
		AppStoreServerAPIKeyID:                 getEnv("APP_STORE_SERVER_API_KEY_ID", ""),
		AppStoreServerAPIPrivateKey:            getEnv("APP_STORE_SERVER_API_PRIVATE_KEY", ""),
		AppStoreServerAPIBundleID:              getEnv("APP_STORE_SERVER_API_BUNDLE_ID", ""),
		AppStoreServerAPIBaseURL:               getEnv("APP_STORE_SERVER_API_BASE_URL", "https://api.storekit.itunes.apple.com"),
		PushProvider:                           getEnv("PUSH_PROVIDER", "noop"),
		FCMProjectID:                           getEnv("FCM_PROJECT_ID", ""),
		FCMServiceAccountEmail:                 getEnv("FCM_SERVICE_ACCOUNT_EMAIL", ""),
		FCMServiceAccountPrivateKey:            getEnv("FCM_SERVICE_ACCOUNT_PRIVATE_KEY", ""),
		FCMOAuthTokenURL:                       getEnv("FCM_OAUTH_TOKEN_URL", "https://oauth2.googleapis.com/token"),
		FCMOAuthScope:                          getEnv("FCM_OAUTH_SCOPE", "https://www.googleapis.com/auth/firebase.messaging"),
		FCMAPIBaseURL:                          getEnv("FCM_API_BASE_URL", "https://fcm.googleapis.com"),
		APNSTeamID:                             getEnv("APNS_TEAM_ID", ""),
		APNSKeyID:                              getEnv("APNS_KEY_ID", ""),
		APNSPrivateKey:                         getEnv("APNS_PRIVATE_KEY", ""),
		APNSTopic:                              getEnv("APNS_TOPIC", ""),
		APNSBaseURL:                            getEnv("APNS_BASE_URL", "https://api.push.apple.com"),
		AlertBillingMinSamples:                 getEnvInt64("ALERT_BILLING_MIN_SAMPLES", 5),
		AlertBillingFailureRatioWarnPct:        getEnvInt64("ALERT_BILLING_FAILURE_RATIO_WARN_PCT", 20),
		AlertBillingFailureRatioCriticalPct:    getEnvInt64("ALERT_BILLING_FAILURE_RATIO_CRITICAL_PCT", 40),
		AlertPushFailureRatioWarnPct:           getEnvInt64("ALERT_PUSH_FAILURE_RATIO_WARN_PCT", 20),
		AlertPushFailureRatioCriticalPct:       getEnvInt64("ALERT_PUSH_FAILURE_RATIO_CRITICAL_PCT", 40),
		AlertRecurrenceFailureRatioWarnPct:     getEnvInt64("ALERT_RECURRENCE_FAILURE_RATIO_WARN_PCT", 20),
		AlertRecurrenceFailureRatioCriticalPct: getEnvInt64("ALERT_RECURRENCE_FAILURE_RATIO_CRITICAL_PCT", 40),
		AlertCooldownSeconds:                   getEnvInt64("ALERT_COOLDOWN_SECONDS", 300),
		AlertMuteWindowEnabled:                 getEnvBool("ALERT_MUTE_WINDOW_ENABLED", false),
		AlertMuteStartHourUTC:                  getEnvInt64("ALERT_MUTE_START_HOUR_UTC", 0),
		AlertMuteEndHourUTC:                    getEnvInt64("ALERT_MUTE_END_HOUR_UTC", 0),
		GoogleClientIDs:                        getEnv("GOOGLE_CLIENT_IDS", ""),
		AppleBundleID:                          getEnv("APPLE_BUNDLE_ID", ""),
		RevenueCatAPIKey:                       getEnv("REVENUECAT_API_KEY", ""),
		RevenueCatSecretKey:                    getEnv("REVENUECAT_SECRET_KEY", ""),
		RevenueCatWebhookAuthToken:             getEnv("REVENUECAT_WEBHOOK_AUTH_TOKEN", ""),
		RevenueCatAPIBaseURL:                   getEnv("REVENUECAT_API_BASE_URL", "https://api.revenuecat.com/v1"),
	}

	if cfg.JWTSecret == "" {
		return nil, fmt.Errorf("JWT_SECRET is required")
	}

	return cfg, nil
}

func getEnv(key, fallback string) string {
	value := os.Getenv(key)
	if value == "" {
		return fallback
	}
	return value
}

func getEnvInt64(key string, fallback int64) int64 {
	value := os.Getenv(key)
	if value == "" {
		return fallback
	}
	parsed, err := strconv.ParseInt(value, 10, 64)
	if err != nil {
		return fallback
	}
	return parsed
}

func getEnvBool(key string, fallback bool) bool {
	value := os.Getenv(key)
	if value == "" {
		return fallback
	}
	parsed, err := strconv.ParseBool(value)
	if err != nil {
		return fallback
	}
	return parsed
}
