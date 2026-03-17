-- Migration: Add energy/recurrence fields to tasks table
-- Version: 000003
-- Date: 2026-03-12

ALTER TABLE tasks ADD COLUMN IF NOT EXISTS energy_level VARCHAR(50);
ALTER TABLE tasks ADD COLUMN IF NOT EXISTS recurrence_rule TEXT;
ALTER TABLE tasks ADD COLUMN IF NOT EXISTS recurring_template_id VARCHAR(255);

CREATE INDEX IF NOT EXISTS idx_tasks_energy_level ON tasks(energy_level);
CREATE INDEX IF NOT EXISTS idx_tasks_recurring_template_id ON tasks(recurring_template_id);

COMMENT ON COLUMN tasks.energy_level IS 'Task energy classification (deep/shallow/admin/none)';
COMMENT ON COLUMN tasks.recurrence_rule IS 'RRULE recurrence definition for recurring task templates';
COMMENT ON COLUMN tasks.recurring_template_id IS 'Template identifier linking generated recurring instances';

