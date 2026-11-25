-- 000020: the Task contract never covered the client task model (issue #989).
-- Clients kept dueDate, completedAt, scheduledForToday and sortOrder locally,
-- and finishDate was overloaded: Apple clients sent the due date there while
-- Android clients sent the completion instant. This migration adds the
-- canonical columns, backfills them from finish_date with a heuristic, and
-- normalizes the legacy energy vocabulary before adding a CHECK constraint.

ALTER TABLE tasks ADD COLUMN IF NOT EXISTS due_date TIMESTAMPTZ;
ALTER TABLE tasks ADD COLUMN IF NOT EXISTS completed_at TIMESTAMPTZ;
ALTER TABLE tasks ADD COLUMN IF NOT EXISTS scheduled_for_today BOOLEAN NOT NULL DEFAULT FALSE;
ALTER TABLE tasks ADD COLUMN IF NOT EXISTS sort_order INTEGER NOT NULL DEFAULT 0;

-- Backfill due_date. For unfinished rows finish_date is always a due date
-- (Android only stamps it when completing). For finished rows the value is
-- ambiguous: Android-origin rows have finish_date ≈ updated_at (the
-- completion instant is stamped right before upload); anything outside a
-- symmetric 1-hour window around updated_at is an Apple-origin due date —
-- including tasks completed BEFORE their due date (finish_date in the
-- future), which is common (issue #989 judgment round 1). Known residual:
-- an Android-origin task finished and edited more than an hour later gets a
-- phantom due_date from its completion instant; harmless (every read
-- COALESCEs) and overwritten by the first post-PR-B full-row push.
UPDATE tasks SET due_date = finish_date
WHERE finish_date IS NOT NULL
  AND (
    NOT is_finished
    OR finish_date < updated_at - INTERVAL '1 hour'
    OR finish_date > updated_at + INTERVAL '1 hour'
  );

-- Recover Android-origin completion instants: finished rows whose
-- finish_date sits within a symmetric 1-hour window of updated_at are
-- completion stamps (bounded on BOTH sides — an unbounded future side
-- misclassified Apple tasks completed before their due date). Boundary
-- residual: an Apple row completed within an hour OF its due instant lands
-- in this window (due dropped, completed_at inferred); benign — every read
-- COALESCEs back to the same instant, and PR-B overwrites explicitly.
UPDATE tasks SET completed_at = finish_date
WHERE is_finished
  AND finish_date IS NOT NULL
  AND finish_date >= updated_at - INTERVAL '1 hour'
  AND finish_date <= updated_at + INTERVAL '1 hour';

-- Normalize the legacy energy vocabulary (Android: Deep/Regular/Light; web
-- legacy: low/medium/high) onto the canonical enum before adding the CHECK.
-- Canonical values are left untouched by the WHERE guard; NULL stays NULL;
-- any other unexpected value fails safe to shallow.
UPDATE tasks SET energy_level = CASE lower(btrim(energy_level))
  WHEN 'deep' THEN 'deep'
  WHEN 'high' THEN 'deep'
  WHEN 'light' THEN 'shallow'
  WHEN 'medium' THEN 'shallow'
  WHEN 'regular' THEN 'admin'
  WHEN 'low' THEN 'admin'
  ELSE 'shallow'
END
WHERE energy_level IS NOT NULL
  AND lower(btrim(energy_level)) NOT IN ('deep', 'shallow', 'admin');

ALTER TABLE tasks ADD CONSTRAINT chk_tasks_energy_level
  CHECK (energy_level IS NULL OR energy_level IN ('deep', 'shallow', 'admin'));

COMMENT ON COLUMN tasks.due_date IS 'When the task is due (canonical). Supersedes the overloaded finish_date (issue #989).';
COMMENT ON COLUMN tasks.completed_at IS 'When the task was completed; NULL while unfinished (issue #989).';
COMMENT ON COLUMN tasks.scheduled_for_today IS 'User pinned the task to Today; legacy boolean pending planned_date (issue #989).';
COMMENT ON COLUMN tasks.sort_order IS 'Manual plan order (drag order) (issue #989).';
COMMENT ON COLUMN tasks.energy_level IS 'Canonical energy classification: deep | shallow | admin; legacy values normalized on write (issue #989).';
