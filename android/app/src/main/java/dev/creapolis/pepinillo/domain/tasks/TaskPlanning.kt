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

    /** Local midnight of today (S4 «Hoy» chip). */
    fun plannedDay(): Long = DueDateEncoding.startOfLocalDay()

    /** Local midnight of tomorrow (S4 «Mañana» / S5 quick add). */
    fun tomorrow(now: Long = System.currentTimeMillis()): Long {
        val cal = java.util.Calendar.getInstance().apply {
            timeInMillis = DueDateEncoding.startOfLocalDay(now)
            add(java.util.Calendar.DAY_OF_YEAR, 1)
        }
        return cal.timeInMillis
    }

    /** Local midnight of the coming Saturday — «Este fin de semana» (S4).
     *  If today is Saturday or Sunday, next weekend's Saturday. */
    fun upcomingWeekend(now: Long = System.currentTimeMillis()): Long {
        val cal = java.util.Calendar.getInstance().apply { timeInMillis = DueDateEncoding.startOfLocalDay(now) }
        // Calendar.DAY_OF_WEEK: 1 = Sunday … 7 = Saturday
        val daysUntilSaturday = (java.util.Calendar.SATURDAY - cal.get(java.util.Calendar.DAY_OF_WEEK) + 7) % 7
        cal.add(java.util.Calendar.DAY_OF_YEAR, if (daysUntilSaturday == 0) 7 else daysUntilSaturday)
        return cal.timeInMillis
    }

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

    /** True when [millis] falls strictly after the local day of [now]. */
    fun isFutureDay(millis: Long, now: Long = System.currentTimeMillis()): Boolean =
        DueDateEncoding.normalizedLocalDate(millis).after(DueDateEncoding.normalizedLocalDate(now))

    private fun isFutureDay(millis: Long, today: Calendar): Boolean =
        DueDateEncoding.normalizedLocalDate(millis).after(today)

    /** True when the task's plan is today or already past (S6 badge logic). */
    fun isPlannedTodayOrPast(task: HasPlan, now: Long = System.currentTimeMillis()): Boolean {
        if (task.scheduledForToday) return true
        val planned = task.plannedDate ?: return false
        return !isFutureDay(planned, now)
    }

    /** True when the task's plan is exactly today's local day. */
    fun isPlannedToday(task: HasPlan, now: Long = System.currentTimeMillis()): Boolean {
        val planned = task.plannedDate ?: return false
        return DueDateEncoding.isSameLocalDay(planned, DueDateEncoding.normalizedLocalDate(now))
    }

    /** Minimal read surface for badge/filter call sites. */
    interface HasPlan {
        val scheduledForToday: Boolean
        val plannedDate: Long?
    }
}
