-- Migration: Revert energy/recurrence fields from tasks table
-- Version: 000003
-- Date: 2026-03-12

DROP INDEX IF EXISTS idx_tasks_energy_level;
DROP INDEX IF EXISTS idx_tasks_recurring_template_id;

COMMENT ON COLUMN tasks.energy_level IS NULL;
COMMENT ON COLUMN tasks.recurrence_rule IS NULL;
COMMENT ON COLUMN tasks.recurring_template_id IS NULL;

DO $$ BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name='tasks' AND column_name='energy_level'
    ) THEN
        ALTER TABLE tasks DROP COLUMN energy_level;
    END IF;
END $$;

DO $$ BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name='tasks' AND column_name='recurrence_rule'
    ) THEN
        ALTER TABLE tasks DROP COLUMN recurrence_rule;
    END IF;
END $$;

DO $$ BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name='tasks' AND column_name='recurring_template_id'
    ) THEN
        ALTER TABLE tasks DROP COLUMN recurring_template_id;
    END IF;
END $$;

