-- Migration: Rename Pomodoro tables to Focus and add multi-mode support
-- Version: 000007
-- Date: 2026-03-20

-- 1. Rename tables from pomodoro_* to focus_*
ALTER TABLE pomodoro_sessions RENAME TO focus_sessions;
ALTER TABLE pomodoro_configs RENAME TO focus_configs;
ALTER TABLE pomodoro_stats RENAME TO focus_stats;

-- 2. Add mode column to focus_sessions
ALTER TABLE focus_sessions ADD COLUMN IF NOT EXISTS mode VARCHAR(50) NOT NULL DEFAULT 'pomodoro';

-- Update existing sessions to have pomodoro mode
UPDATE focus_sessions SET mode = 'pomodoro' WHERE mode = 'pomodoro';

-- Create index for mode
CREATE INDEX IF NOT EXISTS idx_focus_sessions_user_mode ON focus_sessions(user_id, mode);

-- 3. Add mode-specific columns to focus_stats
ALTER TABLE focus_stats ADD COLUMN IF NOT EXISTS flowtime_seconds INTEGER DEFAULT 0;
ALTER TABLE focus_stats ADD COLUMN IF NOT EXISTS timeblock_seconds INTEGER DEFAULT 0;
ALTER TABLE focus_stats ADD COLUMN IF NOT EXISTS stopwatch_seconds INTEGER DEFAULT 0;
ALTER TABLE focus_stats ADD COLUMN IF NOT EXISTS flowtime_count INTEGER DEFAULT 0;
ALTER TABLE focus_stats ADD COLUMN IF NOT EXISTS timeblock_count INTEGER DEFAULT 0;
ALTER TABLE focus_stats ADD COLUMN IF NOT EXISTS stopwatch_count INTEGER DEFAULT 0;

-- 4. Update phase column comment to reflect multiple modes
COMMENT ON COLUMN focus_sessions.phase IS 'Session phase: work/short_break/long_break for pomodoro, flow/break for flowtime, work/check_in for timeblock, freeform for stopwatch';

-- 5. Rename pomodoro-specific columns to be generic (keep old names for backward compatibility)
ALTER TABLE focus_configs RENAME COLUMN pomodoro_time TO work_duration;
ALTER TABLE focus_configs RENAME COLUMN break_time TO short_break_duration;
ALTER TABLE focus_configs RENAME COLUMN rest_time TO long_break_duration;
ALTER TABLE focus_configs RENAME COLUMN qty_pomodoros TO pomodoros_per_cycle;

-- 6. Add JSONB column for mode-specific configurations
ALTER TABLE focus_configs ADD COLUMN IF NOT EXISTS mode_config JSONB DEFAULT '{}'::jsonb;

-- Update existing configs with default pomodoro mode config
UPDATE focus_configs 
SET mode_config = jsonb_build_object(
  'pomodoro', jsonb_build_object(
    'workDuration', work_duration,
    'shortBreakDuration', short_break_duration,
    'longBreakDuration', long_break_duration,
    'pomodorosPerCycle', pomodoros_per_cycle
  ),
  'flowtime', jsonb_build_object(
    'minSessionMinutes', 5,
    'showBreakSuggestion', true
  ),
  'timeblock', jsonb_build_object(
    'defaultBlockDuration', 60,
    'midpointCheckIn', false
  ),
  'stopwatch', jsonb_build_object()
)
WHERE jsonb_typeof(mode_config) = 'unknown';

-- 7. Add default_mode column
ALTER TABLE focus_configs ADD COLUMN IF NOT EXISTS default_mode VARCHAR(20) NOT NULL DEFAULT 'pomodoro';

-- 8. Add constraints to mode column
ALTER TABLE focus_sessions ADD CONSTRAINT chk_focus_sessions_mode 
  CHECK (mode IN ('pomodoro', 'flowtime', 'timeblock', 'stopwatch'));

ALTER TABLE focus_configs ADD CONSTRAINT chk_focus_configs_default_mode 
  CHECK (default_mode IN ('pomodoro', 'flowtime', 'timeblock', 'stopwatch'));
