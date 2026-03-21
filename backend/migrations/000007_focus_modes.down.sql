-- Rollback: Focus modes migration

-- 1. Remove constraints
ALTER TABLE focus_sessions DROP CONSTRAINT IF EXISTS chk_focus_sessions_mode;
ALTER TABLE focus_configs DROP CONSTRAINT IF EXISTS chk_focus_configs_default_mode;

-- 2. Remove default_mode and mode_config columns
ALTER TABLE focus_configs DROP COLUMN IF EXISTS default_mode;
ALTER TABLE focus_configs DROP COLUMN IF EXISTS mode_config;

-- 3. Rename columns back to pomodoro-specific names
ALTER TABLE focus_configs RENAME COLUMN work_duration TO pomodoro_time;
ALTER TABLE focus_configs RENAME COLUMN short_break_duration TO break_time;
ALTER TABLE focus_configs RENAME COLUMN long_break_duration TO rest_time;
ALTER TABLE focus_configs RENAME COLUMN pomodoros_per_cycle TO qty_pomodoros;

-- 4. Drop mode-specific columns from focus_stats
ALTER TABLE focus_stats DROP COLUMN IF EXISTS flowtime_seconds;
ALTER TABLE focus_stats DROP COLUMN IF EXISTS timeblock_seconds;
ALTER TABLE focus_stats DROP COLUMN IF EXISTS stopwatch_seconds;
ALTER TABLE focus_stats DROP COLUMN IF EXISTS flowtime_count;
ALTER TABLE focus_stats DROP COLUMN IF EXISTS timeblock_count;
ALTER TABLE focus_stats DROP COLUMN IF EXISTS stopwatch_count;

-- 5. Drop mode column and index from focus_sessions
DROP INDEX IF EXISTS idx_focus_sessions_user_mode;
ALTER TABLE focus_sessions DROP COLUMN IF EXISTS mode;

-- 6. Rename tables back to pomodoro_*
ALTER TABLE focus_sessions RENAME TO pomodoro_sessions;
ALTER TABLE focus_configs RENAME TO pomodoro_configs;
ALTER TABLE focus_stats RENAME TO pomodoro_stats;
