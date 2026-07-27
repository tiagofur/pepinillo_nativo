package dev.creapolis.pepinillo.data

import android.content.Context

/**
 * Standalone detection of calendar-day changes for the Wear module.
 *
 * The phone app is the source of truth for `completedSessions` while connected
 * and pushes the reset-at-midnight value via the DataLayer. When the watch is
 * offline (no phone, Bluetooth off, Wear-only session), this module lets the
 * watch reset its own cycle counter to 0 at local midnight so a fresh day
 * starts clean.
 *
 * Mirrors the policy of `FocusEngine.onDayChanged()` on the phone:
 *   - Resets `completedSessions` to 0.
 *   - Does NOT interrupt an in-progress session (product decision, 2026-07-26).
 *
 * `startOfDay` / `addDays` are local replicas of
 * `SessionRepository.startOfDay` / `addDays` (app module), which are not
 * visible from the wear module — they are trivial Calendar math.
 */
object WearDayReset {

    /** Trunca [millis] a 00:00:00.000 del día calendario local. */
    fun startOfDay(millis: Long): Long {
        val cal = java.util.Calendar.getInstance(java.util.TimeZone.getDefault())
        cal.timeInMillis = millis
        cal.set(java.util.Calendar.HOUR_OF_DAY, 0)
        cal.set(java.util.Calendar.MINUTE, 0)
        cal.set(java.util.Calendar.SECOND, 0)
        cal.set(java.util.Calendar.MILLISECOND, 0)
        return cal.timeInMillis
    }

    /** Suma [days] días a un start-of-day (respeta DST vía Calendar.add). */
    fun addDays(startOfDayMillis: Long, days: Int): Long {
        val cal = java.util.Calendar.getInstance(java.util.TimeZone.getDefault())
        cal.timeInMillis = startOfDayMillis
        cal.add(java.util.Calendar.DAY_OF_YEAR, days)
        return cal.timeInMillis
    }

    /**
     * Pure decision function: compares the persisted day-start against the
     * start-of-day of [now] and returns the action to take. Extracted from
     * [maybeResetForNewDay] so it can be unit-tested without a Context.
     *
     * @param savedDayStart the value persisted under `KEY_DAY_START_MILLIS`,
     *        or `0L` if none has ever been written.
     * @param now reference timestamp (injectable for tests).
     * @return non-null [ResetDecision]. `shouldReset == false` when the day is
     *         unchanged.
     */
    fun computeResetDecision(
        savedDayStart: Long,
        now: Long,
    ): ResetDecision {
        val todayStart = startOfDay(now)
        return if (savedDayStart == todayStart) {
            ResetDecision.NoReset(todayStart)
        } else {
            ResetDecision.Reset(todayStart)
        }
    }

    /**
     * Si el día persistido (`KEY_DAY_START_MILLIS`) difiere del día de [now]
     * (o no existe todavía), resetea `completedSessions` a 0 y actualiza la
     * marca de día en `WearSnapshotStore`.
     *
     * Idempotente: una segunda invocación dentro del mismo día calendario es
     * un no-op y devuelve `false`.
     *
     * @param now timestamp de referencia (inyectable para tests). Por defecto
     *           `System.currentTimeMillis()`.
     * @return `true` si se aplicó un reset (es decir, el día cambió o no había
     *         marca previa), `false` si ya era el mismo día.
     */
    fun maybeResetForNewDay(
        context: Context,
        now: Long = System.currentTimeMillis(),
    ): Boolean {
        val decision = computeResetDecision(
            savedDayStart = WearSnapshotStore.readDayStartMillis(context),
            now = now,
        )
        if (decision !is ResetDecision.Reset) return false

        WearSnapshotStore.persistDayStartMillis(context, decision.todayStart)
        WearSnapshotStore.persistCompletedSessions(context, 0)
        return true
    }
}

/** Resultado de evaluar si hay que resetear el contador diario. */
sealed interface ResetDecision {
    /** Start-of-day (local tz, epoch millis) computed from the reference `now`. */
    val todayStart: Long

    /** The day changed (or no marker existed): caller should zero the counter. */
    data class Reset(override val todayStart: Long) : ResetDecision

    /** Same day as the persisted marker: no-op. */
    data class NoReset(override val todayStart: Long) : ResetDecision
}
