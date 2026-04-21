package config

import (
	"strings"
	"testing"
)

// setEnv applies env vars via t.Setenv, which automatically restores previous
// values when the test ends. Load() reads the process environment so we must
// scope these changes carefully.
func setEnv(t *testing.T, values map[string]string) {
	t.Helper()
	for k, v := range values {
		t.Setenv(k, v)
	}
}

func baseProdEnv() map[string]string {
	return map[string]string{
		"APP_ENV":                "production",
		"JWT_SECRET":             "prod-secret-value",
		"REFRESH_TOKEN_HASH_KEY": strings.Repeat("a", 32),
		"CORS_ALLOWED_ORIGINS":   "https://app.example.com",
		"APPLE_BUNDLE_ID":        "dev.creapolis.pepinillo",
	}
}

func TestLoad_ProductionRejectsWildcardCORS(t *testing.T) {
	env := baseProdEnv()
	env["CORS_ALLOWED_ORIGINS"] = "*"
	setEnv(t, env)

	_, err := Load()
	if err == nil {
		t.Fatal("expected error for CORS=* in production")
	}
	if !strings.Contains(err.Error(), "CORS_ALLOWED_ORIGINS") {
		t.Fatalf("expected CORS error, got: %v", err)
	}
}

func TestLoad_ProductionRejectsEmptyCORS(t *testing.T) {
	env := baseProdEnv()
	env["CORS_ALLOWED_ORIGINS"] = ""
	setEnv(t, env)

	_, err := Load()
	if err == nil {
		t.Fatal("expected error for empty CORS in production")
	}
	if !strings.Contains(err.Error(), "CORS_ALLOWED_ORIGINS") {
		t.Fatalf("expected CORS error, got: %v", err)
	}
}

func TestLoad_ProductionRejectsWildcardInList(t *testing.T) {
	env := baseProdEnv()
	env["CORS_ALLOWED_ORIGINS"] = "https://app.example.com,*"
	setEnv(t, env)

	_, err := Load()
	if err == nil {
		t.Fatal("expected error for CORS list containing *")
	}
	if !strings.Contains(err.Error(), "\"*\"") {
		t.Fatalf("expected wildcard-in-list error, got: %v", err)
	}
}

func TestLoad_ProductionRequiresHashKey(t *testing.T) {
	env := baseProdEnv()
	env["REFRESH_TOKEN_HASH_KEY"] = ""
	setEnv(t, env)

	_, err := Load()
	if err == nil {
		t.Fatal("expected error for missing hash key in production")
	}
	if !strings.Contains(err.Error(), "REFRESH_TOKEN_HASH_KEY") {
		t.Fatalf("expected hash key error, got: %v", err)
	}
}

func TestLoad_ProductionRejectsShortHashKey(t *testing.T) {
	env := baseProdEnv()
	env["REFRESH_TOKEN_HASH_KEY"] = "tooshort"
	setEnv(t, env)

	_, err := Load()
	if err == nil {
		t.Fatal("expected error for short hash key in production")
	}
}

func TestLoad_ProductionRequiresAppleBundleID(t *testing.T) {
	env := baseProdEnv()
	env["APPLE_BUNDLE_ID"] = ""
	setEnv(t, env)

	_, err := Load()
	if err == nil {
		t.Fatal("expected error for missing APPLE_BUNDLE_ID in production")
	}
	if !strings.Contains(err.Error(), "APPLE_BUNDLE_ID") {
		t.Fatalf("expected APPLE_BUNDLE_ID error, got: %v", err)
	}
}

func TestLoad_ProductionAcceptsValidConfig(t *testing.T) {
	env := baseProdEnv()
	setEnv(t, env)

	cfg, err := Load()
	if err != nil {
		t.Fatalf("expected production config to load, got: %v", err)
	}
	if cfg.Environment != "production" {
		t.Fatalf("expected production env, got %s", cfg.Environment)
	}
	if cfg.CORSAllowedOrigins != "https://app.example.com" {
		t.Fatalf("unexpected CORS origins: %s", cfg.CORSAllowedOrigins)
	}
}

func TestLoad_DevelopmentAllowsWildcardCORS(t *testing.T) {
	env := map[string]string{
		"APP_ENV":              "development",
		"JWT_SECRET":           "dev-secret",
		"CORS_ALLOWED_ORIGINS": "*",
	}
	setEnv(t, env)

	cfg, err := Load()
	if err != nil {
		t.Fatalf("dev config with CORS=* must load, got: %v", err)
	}
	if cfg.CORSAllowedOrigins != "*" {
		t.Fatalf("expected CORS=*, got %s", cfg.CORSAllowedOrigins)
	}
}

func TestLoad_DevelopmentDoesNotRequireHashKey(t *testing.T) {
	env := map[string]string{
		"APP_ENV":                "development",
		"JWT_SECRET":             "dev-secret",
		"CORS_ALLOWED_ORIGINS":   "*",
		"REFRESH_TOKEN_HASH_KEY": "",
	}
	setEnv(t, env)

	if _, err := Load(); err != nil {
		t.Fatalf("dev config must not require hash key, got: %v", err)
	}
}
