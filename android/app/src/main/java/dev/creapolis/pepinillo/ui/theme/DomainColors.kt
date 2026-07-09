package dev.creapolis.pepinillo.ui.theme

import androidx.compose.ui.graphics.Color

/**
 * Domain-specific semantic colors used across the app (due-today orange, trend up/down, etc.).
 *
 * Centralized here so feature screens don't sprinkle `Color(0xFF...)` literals that bypass the
 * theme and can't adapt. These intentionally do NOT vary by theme variant — they carry fixed
 * semantic meaning (warning/positive/negative) consistent with Material guidance for such colors.
 *
 * If a color should adapt to light/dark or dynamic color, it belongs in the M3 colorScheme instead.
 */
object DomainColors {
    /** Amber/orange used for "due today" task state and the period-picker Today filter. */
    val DueToday: Color = Color(0xFFFF8A00)

    /** Blue used for the Inbox filter chip. */
    val FilterInbox: Color = Color(0xFF1A73E8)

    /** Purple used for the Upcoming filter chip. */
    val FilterUpcoming: Color = Color(0xFF8E24AA)

    /** Green used for the Completed filter chip and positive trends. */
    val Positive: Color = Color(0xFF4CAF50)

    /** Red used for negative trends / overdue. */
    val Negative: Color = Color(0xFFF44336)

    /** Gold used for "best" / trophy accents in reviews. */
    val Gold: Color = Color(0xFFFFD700)

    /** Orange used for the weekly review reflection card accent. */
    val ReviewWeekly: Color = Color(0xFFFF9800)

    /** Purple used for the monthly review reflection card accent. */
    val ReviewMonthly: Color = Color(0xFF9C27B0)
}
