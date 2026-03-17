-- Migration: Revert email verification fields from users table
-- Version: 000002
-- Date: 2026-02-12

-- Remove indexes
DROP INDEX IF EXISTS idx_users_email_verified;
DROP INDEX IF EXISTS idx_users_pending_email;

-- Remove comments
COMMENT ON COLUMN users.email_verified IS NULL;
COMMENT ON COLUMN users.email_verified_at IS NULL;
COMMENT ON COLUMN users.pending_email IS NULL;
COMMENT ON COLUMN users.email_changed_at IS NULL;

-- Remove columns (PostgreSQL doesn't support DROP COLUMN IF NOT EXISTS in older versions, so we need to check)
DO $$ BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name='users' AND column_name='email_verified'
    ) THEN
        ALTER TABLE users DROP COLUMN email_verified;
    END IF;
END $$;

DO $$ BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name='users' AND column_name='email_verified_at'
    ) THEN
        ALTER TABLE users DROP COLUMN email_verified_at;
    END IF;
END $$;

DO $$ BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name='users' AND column_name='pending_email'
    ) THEN
        ALTER TABLE users DROP COLUMN pending_email;
    END IF;
END $$;

DO $$ BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name='users' AND column_name='email_changed_at'
    ) THEN
        ALTER TABLE users DROP COLUMN email_changed_at;
    END IF;
END $$;
