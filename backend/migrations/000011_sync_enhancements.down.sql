ALTER TABLE focus_sessions DROP COLUMN IF EXISTS interruptions;
ALTER TABLE focus_sessions DROP COLUMN IF EXISTS pomodoro_number;
ALTER TABLE focus_sessions DROP COLUMN IF EXISTS satisfaction_rating;
ALTER TABLE focus_sessions DROP COLUMN IF EXISTS journal_note;

ALTER TABLE focus_stats DROP COLUMN IF EXISTS tasks_completed;
ALTER TABLE focus_stats DROP COLUMN IF EXISTS longest_session_seconds;
