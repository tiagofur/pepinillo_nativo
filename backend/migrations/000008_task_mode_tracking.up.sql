-- Migration: Add mode-specific tracking to tasks
-- Version: 000008
-- Date: 2026-03-20

-- 1. Add mode-specific completion tracking columns
ALTER TABLE tasks ADD COLUMN IF NOT EXISTS completed_pomodoros INTEGER DEFAULT 0;
ALTER TABLE tasks ADD COLUMN IF NOT EXISTS completed_flowtime_sessions INTEGER DEFAULT 0;
ALTER TABLE tasks ADD COLUMN IF NOT EXISTS completed_timeblock_sessions INTEGER DEFAULT 0;
ALTER TABLE tasks ADD COLUMN IF NOT EXISTS completed_stopwatch_seconds INTEGER DEFAULT 0;

-- 2. Add mode-specific focus time columns
ALTER TABLE tasks ADD COLUMN IF NOT EXISTS focused_seconds_pomodoro INTEGER DEFAULT 0;
ALTER TABLE tasks ADD COLUMN IF NOT EXISTS focused_seconds_flowtime INTEGER DEFAULT 0;
ALTER TABLE tasks ADD COLUMN IF NOT EXISTS focused_seconds_timeblock INTEGER DEFAULT 0;
ALTER TABLE tasks ADD COLUMN IF NOT EXISTS focused_seconds_stopwatch INTEGER DEFAULT 0;

-- 3. Add default tracking mode column
ALTER TABLE tasks ADD COLUMN IF NOT EXISTS tracking_mode VARCHAR(20) DEFAULT 'pomodoro';

-- 4. Migrate existing data to pomodoro mode
UPDATE tasks 
SET 
  completed_pomodoros = completed_pomodoros,
  focused_seconds_pomodoro = focused_seconds
WHERE tracking_mode = 'pomodoro' OR tracking_mode IS NULL;

-- 5. Add constraint for valid tracking modes
ALTER TABLE tasks ADD CONSTRAINT chk_tasks_tracking_mode 
  CHECK (tracking_mode IN ('pomodoro', 'flowtime', 'timeblock', 'stopwatch'));

-- 6. Create indexes for mode-specific queries
CREATE INDEX IF NOT EXISTS idx_tasks_tracking_mode ON tasks(tracking_mode);
CREATE INDEX IF NOT EXISTS idx_tasks_user_tracking ON tasks(user_id, tracking_mode);
