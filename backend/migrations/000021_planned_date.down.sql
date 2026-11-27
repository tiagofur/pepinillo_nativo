-- Reverse of 000021 (issue #991): drop the planned-date column.
ALTER TABLE tasks DROP COLUMN IF EXISTS planned_date;
