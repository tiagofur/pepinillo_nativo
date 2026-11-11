-- Explicit opt-in for sharing aggregated usage metrics (GET /internal/stats).
-- Default FALSE: nobody is counted until they consent in the client.
ALTER TABLE users ADD COLUMN IF NOT EXISTS metrics_opt_in BOOLEAN NOT NULL DEFAULT FALSE;
CREATE INDEX IF NOT EXISTS idx_users_metrics_opt_in ON users(id) WHERE metrics_opt_in;
CREATE INDEX IF NOT EXISTS idx_focus_sessions_started_at ON focus_sessions(started_at);
CREATE INDEX IF NOT EXISTS idx_tasks_created_date ON tasks(created_date);
