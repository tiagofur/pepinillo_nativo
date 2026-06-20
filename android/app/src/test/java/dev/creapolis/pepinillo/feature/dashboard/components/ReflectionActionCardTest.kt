package dev.creapolis.pepinillo.feature.dashboard.components

import org.junit.Assert.assertEquals
import org.junit.Test

class ReflectionActionCardTest {

    // -----------------------------------------------------------------------
    // formatPreviewLine (already in WeeklyChart.kt, re-tested for completeness)
    // -----------------------------------------------------------------------

    @Test
    fun `formatPreviewLine formats hours and minutes with sessions`() {
        assertEquals("1h 20m in 5 sessions", formatPreviewLine(80, 5))
    }

    @Test
    fun `formatPreviewLine formats only minutes when less than 60`() {
        assertEquals("45m in 3 sessions", formatPreviewLine(45, 3))
    }

    @Test
    fun `formatPreviewLine handles zero values`() {
        assertEquals("0m in 0 sessions", formatPreviewLine(0, 0))
    }

    @Test
    fun `formatPreviewLine handles single session`() {
        assertEquals("30m in 1 session", formatPreviewLine(30, 1))
    }

    // -----------------------------------------------------------------------
    // getLockIconVisibility
    // -----------------------------------------------------------------------

    @Test
    fun `getLockIconVisibility returns true when not premium`() {
        assertEquals(true, getLockIconVisibility(isPremium = false))
    }

    @Test
    fun `getLockIconVisibility returns false when premium`() {
        assertEquals(false, getLockIconVisibility(isPremium = true))
    }

    // -----------------------------------------------------------------------
    // getPreviewText
    // -----------------------------------------------------------------------

    @Test
    fun `getPreviewText formats with minutes and sessions`() {
        assertEquals("1h 30m in 5 sessions", getPreviewText(90, 5))
    }

    @Test
    fun `getPreviewText handles zero data`() {
        assertEquals("0m in 0 sessions", getPreviewText(0, 0))
    }

    @Test
    fun `getPreviewText formats under an hour`() {
        assertEquals("45m in 3 sessions", getPreviewText(45, 3))
    }
}
