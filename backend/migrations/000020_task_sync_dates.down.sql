-- 000020 down: drop the canonical task-model columns and the energy CHECK
-- (issue #989). The backfilled values are not recoverable from finish_date
-- alone after this point; the down migration exists for symmetric rollbacks,
-- not for data preservation.

ALTER TABLE tasks DROP CONSTRAINT IF EXISTS chk_tasks_energy_level;
ALTER TABLE tasks DROP COLUMN IF EXISTS sort_order;
ALTER TABLE tasks DROP COLUMN IF EXISTS scheduled_for_today;
ALTER TABLE tasks DROP COLUMN IF EXISTS completed_at;
ALTER TABLE tasks DROP COLUMN IF EXISTS due_date;

COMMENT ON COLUMN tasks.energy_level IS 'Task energy classification (deep/shallow/admin/none)';
