-- Add missing fields to focus_sessions
ALTER TABLE focus_sessions ADD COLUMN IF NOT EXISTS interruptions INT DEFAULT 0;
ALTER TABLE focus_sessions ADD COLUMN IF NOT EXISTS pomodoro_number INT DEFAULT 0;
ALTER TABLE focus_sessions ADD COLUMN IF NOT EXISTS satisfaction_rating INT DEFAULT 0;
ALTER TABLE focus_sessions ADD COLUMN IF NOT EXISTS journal_note TEXT DEFAULT '';

-- Add missing fields to focus_stats
ALTER TABLE focus_stats ADD COLUMN IF NOT EXISTS tasks_completed INT DEFAULT 0;
ALTER TABLE focus_stats ADD COLUMN IF NOT EXISTS longest_session_seconds INT DEFAULT 0;
