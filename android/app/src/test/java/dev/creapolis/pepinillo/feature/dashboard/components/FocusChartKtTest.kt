package dev.creapolis.pepinillo.feature.dashboard.components

import dev.creapolis.pepinillo.feature.dashboard.model.DailyFocus
import org.junit.Assert.assertEquals
import org.junit.Test

class FocusChartKtTest {

    // -----------------------------------------------------------------------
    // computeAverageMinutes
    // -----------------------------------------------------------------------

    @Test
    fun `computeAverageMinutes returns 0 for empty data`() {
        val data = emptyList<DailyFocus>()
        assertEquals(0.0, computeAverageMinutes(data), 0.001)
    }

    @Test
    fun `computeAverageMinutes computes correct average`() {
        val data = listOf(
            DailyFocus("Mon", 30),
            DailyFocus("Tue", 60),
            DailyFocus("Wed", 90),
        )
        assertEquals(60.0, computeAverageMinutes(data), 0.001)
    }

    @Test
    fun `computeAverageMinutes handles all zeros`() {
        val data = listOf(
            DailyFocus("Mon", 0),
            DailyFocus("Tue", 0),
            DailyFocus("Wed", 0),
        )
        assertEquals(0.0, computeAverageMinutes(data), 0.001)
    }

    @Test
    fun `computeAverageMinutes handles mixed values`() {
        val data = listOf(
            DailyFocus("Mon", 10),
            DailyFocus("Tue", 20),
        )
        assertEquals(15.0, computeAverageMinutes(data), 0.001)
    }

    // -----------------------------------------------------------------------
    // mapToChartEntries
    // -----------------------------------------------------------------------

    @Test
    fun `mapToChartEntries returns empty list for empty data`() {
        val data = emptyList<DailyFocus>()
        assertEquals(0, mapToChartEntries(data).size)
    }

    @Test
    fun `mapToChartEntries maps data with correct x and y values`() {
        val data = listOf(
            DailyFocus("Mon", 25),
            DailyFocus("Tue", 50),
            DailyFocus("Wed", 75),
        )
        val entries = mapToChartEntries(data)
        assertEquals(3, entries.size)
        assertEquals(0f, entries[0].x, 0.001f)
        assertEquals(25f, entries[0].y, 0.001f)
        assertEquals(1f, entries[1].x, 0.001f)
        assertEquals(50f, entries[1].y, 0.001f)
        assertEquals(2f, entries[2].x, 0.001f)
        assertEquals(75f, entries[2].y, 0.001f)
    }

    @Test
    fun `mapToChartEntries handles single entry`() {
        val data = listOf(DailyFocus("Mon", 120))
        val entries = mapToChartEntries(data)
        assertEquals(1, entries.size)
        assertEquals(0f, entries[0].x, 0.001f)
        assertEquals(120f, entries[0].y, 0.001f)
    }

    // -----------------------------------------------------------------------
    // formatPreviewLine
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
    fun `formatPreviewLine formats exact hours`() {
        assertEquals("2h 0m in 10 sessions", formatPreviewLine(120, 10))
    }

    @Test
    fun `formatPreviewLine handles zero values`() {
        assertEquals("0m in 0 sessions", formatPreviewLine(0, 0))
    }

    @Test
    fun `formatPreviewLine handles single session`() {
        assertEquals("30m in 1 session", formatPreviewLine(30, 1))
    }
}
