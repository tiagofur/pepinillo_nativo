package dev.creapolis.pepinillo.feature.dashboard

import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * Unit tests for pure functions in DashboardScreen.kt.
 *
 * Compose UI rendering cannot be unit-tested without Robolectric (not available
 * in this project). All testable logic is extracted into pure functions and
 * verified here. See PR 2 notes for the same pattern used for component tests.
 */
class DashboardScreenTest {

    // -------------------------------------------------------------------
    // formatCompletionRate
    // -------------------------------------------------------------------

    @Test
    fun `formatCompletionRate formats zero as 0 percent`() {
        assertEquals("0%", formatCompletionRate(0.0))
    }

    @Test
    fun `formatCompletionRate formats half as 50 percent`() {
        assertEquals("50%", formatCompletionRate(0.5))
    }

    @Test
    fun `formatCompletionRate formats 0_78 as 78 percent`() {
        assertEquals("78%", formatCompletionRate(0.78))
    }

    @Test
    fun `formatCompletionRate formats 1_0 as 100 percent`() {
        assertEquals("100%", formatCompletionRate(1.0))
    }

    @Test
    fun `formatCompletionRate truncates instead of rounding`() {
        // 0.789 → 78% (truncated, not rounded to 79%)
        assertEquals("78%", formatCompletionRate(0.789))
    }
}
