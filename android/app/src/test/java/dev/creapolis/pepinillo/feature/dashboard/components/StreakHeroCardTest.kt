package dev.creapolis.pepinillo.feature.dashboard.components

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class StreakHeroCardTest {

    // -----------------------------------------------------------------------
    // getStreakDisplayText
    // -----------------------------------------------------------------------

    @Test
    fun `getStreakDisplayText returns motivational copy for zero streak`() {
        assertEquals("Start your streak!", getStreakDisplayText(0))
    }

    @Test
    fun `getStreakDisplayText returns number for positive streak`() {
        assertEquals("7", getStreakDisplayText(7))
    }

    @Test
    fun `getStreakDisplayText returns number for streak of 1`() {
        assertEquals("1", getStreakDisplayText(1))
    }

    // -----------------------------------------------------------------------
    // shouldShowGlow
    // -----------------------------------------------------------------------

    @Test
    fun `shouldShowGlow returns false for zero streak`() {
        assertFalse(shouldShowGlow(0))
    }

    @Test
    fun `shouldShowGlow returns true for positive streak`() {
        assertTrue(shouldShowGlow(7))
    }

    @Test
    fun `shouldShowGlow returns true for streak of 1`() {
        assertTrue(shouldShowGlow(1))
    }

    // -----------------------------------------------------------------------
    // formatPeriodStats
    // -----------------------------------------------------------------------

    @Test
    fun `formatPeriodStats formats hours and minutes with sessions`() {
        assertEquals("2h 30m \u00B7 5 sessions", formatPeriodStats(150, 5))
    }

    @Test
    fun `formatPeriodStats formats only minutes when less than 60`() {
        assertEquals("45m \u00B7 3 sessions", formatPeriodStats(45, 3))
    }

    @Test
    fun `formatPeriodStats handles zero values`() {
        assertEquals("0m \u00B7 0 sessions", formatPeriodStats(0, 0))
    }

    @Test
    fun `formatPeriodStats handles single session`() {
        assertEquals("30m \u00B7 1 session", formatPeriodStats(30, 1))
    }
}
