package postgres

import (
	"fmt"
	"time"

	"gorm.io/driver/postgres"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"
)

// PoolConfig controls the database connection pool. Zero or negative values
// fall back to sensible production defaults.
type PoolConfig struct {
	MaxOpenConns    int
	MaxIdleConns    int
	ConnMaxLifetime time.Duration
	ConnMaxIdleTime time.Duration
}

// Default pool values (see 000012 migration rationale / Track A4 hygiene).
const (
	defaultMaxOpenConns    = 25
	defaultMaxIdleConns    = 5
	defaultConnMaxLifetime = time.Hour
	defaultConnMaxIdleTime = 30 * time.Minute
)

func (p PoolConfig) withDefaults() PoolConfig {
	if p.MaxOpenConns <= 0 {
		p.MaxOpenConns = defaultMaxOpenConns
	}
	if p.MaxIdleConns <= 0 {
		p.MaxIdleConns = defaultMaxIdleConns
	}
	if p.ConnMaxLifetime <= 0 {
		p.ConnMaxLifetime = defaultConnMaxLifetime
	}
	if p.ConnMaxIdleTime <= 0 {
		p.ConnMaxIdleTime = defaultConnMaxIdleTime
	}
	return p
}

// NewDB opens the GORM Postgres connection using default pool settings.
// Prefer NewDBWithPool when explicit, env-driven pool tuning is required.
func NewDB(databaseURL string) (*gorm.DB, error) {
	return NewDBWithPool(databaseURL, PoolConfig{})
}

// NewDBWithPool opens the GORM Postgres connection and applies the given
// connection pool configuration. Missing fields are filled with defaults.
func NewDBWithPool(databaseURL string, pool PoolConfig) (*gorm.DB, error) {
	if databaseURL == "" {
		return nil, fmt.Errorf("database url is required")
	}

	db, err := gorm.Open(postgres.Open(databaseURL), &gorm.Config{
		Logger: logger.Default.LogMode(logger.Warn),
	})
	if err != nil {
		return nil, err
	}

	sqlDB, err := db.DB()
	if err != nil {
		return nil, err
	}

	pool = pool.withDefaults()
	sqlDB.SetMaxOpenConns(pool.MaxOpenConns)
	sqlDB.SetMaxIdleConns(pool.MaxIdleConns)
	sqlDB.SetConnMaxLifetime(pool.ConnMaxLifetime)
	sqlDB.SetConnMaxIdleTime(pool.ConnMaxIdleTime)

	if err := sqlDB.Ping(); err != nil {
		return nil, err
	}

	return db, nil
}
