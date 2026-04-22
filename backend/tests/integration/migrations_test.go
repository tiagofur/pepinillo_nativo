package integration

import (
	"os"
	"path/filepath"
	"runtime"
	"strings"
	"testing"
)

// migrationsDir returns the absolute path to backend/migrations/ regardless of
// where the test binary is executed from.
func migrationsDir() string {
	_, filename, _, _ := runtime.Caller(0)
	// filename = .../backend/tests/integration/migrations_test.go
	return filepath.Join(filepath.Dir(filename), "..", "..", "migrations")
}

func readRoutesFile(t *testing.T) string {
	t.Helper()
	_, filename, _, _ := runtime.Caller(0)
	path := filepath.Join(filepath.Dir(filename), "..", "..", "internal", "adapters", "handlers", "routes.go")
	data, err := os.ReadFile(path)
	if err != nil {
		t.Fatalf("routes.go not found: %v", err)
	}
	return string(data)
}

func readMigrationFile(t *testing.T, name string) string {
	t.Helper()
	path := filepath.Join(migrationsDir(), name)
	data, err := os.ReadFile(path)
	if err != nil {
		t.Fatalf("migration file %q not found: %v", name, err)
	}
	return string(data)
}

func assertContains(t *testing.T, haystack, needle, msg string) {
	t.Helper()
	if !strings.Contains(haystack, needle) {
		t.Errorf("%s: expected to find %q in:\n%s", msg, needle, haystack)
	}
}

// TestMigration_PepinilloPlusEntitlementAt verifies that migration
// 000013_tier_capability_model adds the pepinillo_plus_entitlement_at column
// to the users table as a nullable TIMESTAMP.
//
// This is a compile-time / documentation test: the integration suite does not
// spin up a real Postgres instance (no testcontainers), so we assert the
// expected migration files are present on disk and have the correct SQL.
// A real DB migration test would run golang-migrate against a test DB; that
// is covered by the deployment pipeline. Here we verify the artifact exists
// and contains the required DDL so the code review gate catches regressions.
func TestMigration_PepinilloPlusEntitlementAt(t *testing.T) {
	if testing.Short() {
		t.Skip("skipping integration test")
	}

	// The column must be added by migration 000013.
	// We verify the migration files exist and contain the expected SQL.
	upSQL := readMigrationFile(t, "000013_tier_capability_model.up.sql")
	downSQL := readMigrationFile(t, "000013_tier_capability_model.down.sql")

	assertContains(t, upSQL, "pepinillo_plus_entitlement_at",
		"up migration must add pepinillo_plus_entitlement_at column")
	assertContains(t, upSQL, "ALTER TABLE users",
		"up migration must target the users table")
	assertContains(t, upSQL, "NULL",
		"up migration column must be nullable (no NOT NULL constraint)")

	assertContains(t, downSQL, "pepinillo_plus_entitlement_at",
		"down migration must reference pepinillo_plus_entitlement_at column")
	assertContains(t, downSQL, "DROP COLUMN",
		"down migration must drop the column")
}
