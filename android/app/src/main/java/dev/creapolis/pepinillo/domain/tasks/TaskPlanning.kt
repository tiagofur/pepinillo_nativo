package dev.creapolis.pepinillo.domain.tasks

import java.util.Calendar

/**
 * Single «Hoy» rule shared by every Android surface (issue #991 S2/S3): the
 * tasks list filters, the widget and the Wear tile all resolve buckets here.
 * The rule is asserted against contracts/fixtures/task-planning-cases-991.json
 * — a shared case table that the iOS and web suites decode too.
 *
 * Storage: `planned_date` is the **local-midnight epoch millis** of the
 * planned calendar day (same encoding as `due_date` — see [DueDateEncoding]).
 */
object TaskPlanning {

    /** Where a task lives in Plan. `.Completed` exists for fixture
     * completeness; most callers filter completed tasks before bucketing. */
    sealed interface Bucket {
        /**
         * «Hoy» — planned today or earlier ([postponed] = S6 badge for past
         * plans), or due today or overdue.
         */
        data class Today(val postponed: Boolean) : Bucket

        /** «Próximas» — first planned or due day is strictly in the future. */
        data object Upcoming : Bucket

        /** «Bandeja» — no planned date and no due date. */
        data object Inbox : Bucket

        /** Completed tasks belong to no active bucket. */
        data object Completed : Bucket
    }

    /**
     * Canonical storage form for a planned date: local midnight of that day.
     * Recurrence (S8) and every write path normalize through this.
     */
    fun plannedDay(millis: Long): Long = DueDateEncoding.startOfLocalDay(millis)

    /**
     * The bucket a task belongs to right now.
     *
     * `scheduledForToday` is the legacy pre-#991 boolean that still travels on
     * the wire (S9) and still exists in older rows: it acts as a sync shim
     * only where the new semantics don't speak (no planned date, or a future
     * one). A past planned date always keeps its S6 postponement.
     */
    fun bucket(
        plannedDate: Long?,
        dueDate: Long?,
        scheduledForToday: Boolean = false,
        isCompleted: Boolean,
        now: Long = System.currentTimeMillis(),
    ): Bucket {
        if (isCompleted) return Bucket.Completed
        val today = DueDateEncoding.normalizedLocalDate(now)

        // Legacy shim: an older cohort's "in today's list" flag keeps the
        // task in «Hoy» until a written planned date (past plans keep the
        // S6 badge) or the MIGRATION_14_15 backfill replaces it.
        if (scheduledForToday && (plannedDate == null || isFutureDay(plannedDate, today))) {
            return Bucket.Today(postponed = false)
        }

        if (plannedDate != null && !isFutureDay(plannedDate, today)) {
            return Bucket.Today(postponed = !DueDateEncoding.isSameLocalDay(plannedDate, today))
        }
        if (dueDate != null && !isFutureDay(dueDate, today)) {
            return Bucket.Today(postponed = false)
        }
        return if (plannedDate != null || dueDate != null) Bucket.Upcoming else Bucket.Inbox
    }

    private fun isFutureDay(millis: Long, today: Calendar): Boolean =
        DueDateEncoding.normalizedLocalDate(millis).after(today)
}
