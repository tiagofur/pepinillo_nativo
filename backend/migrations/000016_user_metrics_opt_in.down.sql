DROP INDEX IF EXISTS idx_users_metrics_opt_in;
ALTER TABLE users DROP COLUMN IF EXISTS metrics_opt_in;
