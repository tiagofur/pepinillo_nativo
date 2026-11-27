-- 000021: plannedDate — the local calendar day the user plans to work on a
-- task (issue #991 S1/S9). Replaces the scheduledForToday boolean, which
-- expires client-side per platform rules; plannedDate is durable so past
-- plans stay visible as "postponed" (S6) and future plans appear in Upcoming.
-- Additive column: rows keep NULL until a #991 client writes a plan.
ALTER TABLE tasks ADD COLUMN IF NOT EXISTS planned_date TIMESTAMPTZ;
