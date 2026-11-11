DROP INDEX IF EXISTS idx_tasks_created_date;
DROP INDEX IF EXISTS idx_focus_sessions_started_at;
DROP INDEX IF EXISTS idx_users_metrics_opt_in;
ALTER TABLE users DROP COLUMN IF EXISTS metrics_opt_in;
