-- Migration: Add performance indexes for common query patterns
-- Version: 000012
-- Date: 2026-04-15
--
-- Context: Production hygiene (Track A4). The existing schema has single-column
-- indexes on tasks(user_id) and tasks(updated_at) but no composite indexes
-- matching the actual query patterns used by the sync service, analytics
-- queries on focus_sessions, and active-task listings. This migration adds
-- those composites idempotently.
--
-- Notes on what is NOT added (already covered by previous migrations):
--   - users.email UNIQUE              -> set in 000001_init (column constraint)
--   - users.google_id / users.apple_id -> unique + indexed in 000006
--   - subtasks(task_id)               -> idx_subtasks_task_id in 000001
--   - device_tokens(user_id, is_active)-> idx_device_tokens_user_active in 000004
--   - oauth_providers(provider, provider_user_id)
--       There is no oauth_providers table; OAuth identities live as columns
--       on users (google_id, apple_id) with per-provider unique indexes.

-- 1. Tasks: sync pagination and listing by user, ordered by updated_at desc.
CREATE INDEX IF NOT EXISTS idx_tasks_user_updated_at
  ON tasks (user_id, updated_at DESC);

-- 2. Tasks: active (non-deleted) tasks since X, per user. Partial index keeps
--    the working set small and is ideal for the common "pull my active tasks
--    updated since {cursor}" query.
CREATE INDEX IF NOT EXISTS idx_tasks_user_updated_at_active
  ON tasks (user_id, updated_at DESC)
  WHERE is_deleted = FALSE;

-- 3. Focus sessions: analytics queries (user timeline, "last N sessions").
CREATE INDEX IF NOT EXISTS idx_focus_sessions_user_started_at
  ON focus_sessions (user_id, started_at DESC);
