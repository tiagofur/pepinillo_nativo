-- Rollback: Task mode-specific tracking

-- 1. Drop indexes
DROP INDEX IF EXISTS idx_tasks_user_tracking;
DROP INDEX IF EXISTS idx_tasks_tracking_mode;

-- 2. Drop constraint
ALTER TABLE tasks DROP CONSTRAINT IF EXISTS chk_tasks_tracking_mode;

-- 3. Drop mode-specific columns
ALTER TABLE tasks DROP COLUMN IF EXISTS tracking_mode;
ALTER TABLE tasks DROP COLUMN IF EXISTS focused_seconds_stopwatch;
ALTER TABLE tasks DROP COLUMN IF EXISTS focused_seconds_timeblock;
ALTER TABLE tasks DROP COLUMN IF EXISTS focused_seconds_flowtime;
ALTER TABLE tasks DROP COLUMN IF EXISTS focused_seconds_pomodoros;
ALTER TABLE tasks DROP COLUMN IF EXISTS completed_stopwatch_seconds;
ALTER TABLE tasks DROP COLUMN IF EXISTS completed_timeblock_sessions;
ALTER TABLE tasks DROP COLUMN IF EXISTS completed_flowtime_sessions;
ALTER TABLE tasks DROP COLUMN IF EXISTS completed_pomodoros;
