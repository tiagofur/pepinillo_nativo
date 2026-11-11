-- Explicit opt-in for sharing aggregated usage metrics (GET /internal/stats).
-- Default FALSE: nobody is counted until they consent in the client.
-- Activity lookups reuse idx_focus_sessions_user_started_at and
-- idx_tasks_user_updated_at from migration 000012; no new indexes on large tables.
ALTER TABLE users ADD COLUMN IF NOT EXISTS metrics_opt_in BOOLEAN NOT NULL DEFAULT FALSE;
CREATE INDEX IF NOT EXISTS idx_users_metrics_opt_in ON users(id) WHERE metrics_opt_in;
