-- Migration: Add email verification fields to users table
-- Version: 000002
-- Date: 2026-02-12

-- Add email verification fields to users table
ALTER TABLE users ADD COLUMN IF NOT EXISTS email_verified BOOLEAN NOT NULL DEFAULT FALSE;
ALTER TABLE users ADD COLUMN IF NOT EXISTS email_verified_at TIMESTAMPTZ;
ALTER TABLE users ADD COLUMN IF NOT EXISTS pending_email VARCHAR(255);
ALTER TABLE users ADD COLUMN IF NOT EXISTS email_changed_at TIMESTAMPTZ;

-- Add indexes for email verification queries
CREATE INDEX IF NOT EXISTS idx_users_email_verified ON users(email_verified);
CREATE INDEX IF NOT EXISTS idx_users_pending_email ON users(pending_email) WHERE pending_email IS NOT NULL;

-- Add comment to new columns
COMMENT ON COLUMN users.email_verified IS 'Indicates if the user email has been verified';
COMMENT ON COLUMN users.email_verified_at IS 'Timestamp when email was verified';
COMMENT ON COLUMN users.pending_email IS 'New email address waiting for verification during email change process';
COMMENT ON COLUMN users.email_changed_at IS 'Timestamp when email change was requested';
