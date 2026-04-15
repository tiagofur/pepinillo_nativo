-- Rollback performance indexes
DROP INDEX IF EXISTS idx_focus_sessions_user_started_at;
DROP INDEX IF EXISTS idx_tasks_user_updated_at_active;
DROP INDEX IF EXISTS idx_tasks_user_updated_at;
