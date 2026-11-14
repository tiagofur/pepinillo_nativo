package dev.creapolis.pepinillo.tile

import org.junit.Assert.assertEquals
import org.junit.Test

class FocusTileServiceTest {

    @Test
    fun `REFRESH_ACTIVE_MS equals 5 seconds`() {
        // User-approved: active tile ticks every 5s so the countdown looks alive.
        // Push updates from WearFocusService cover in-between ticks; freshness is fallback.
        assertEquals(5_000L, FocusTileService.REFRESH_ACTIVE_MS)
    }

    @Test
    fun `tile action extras are defined`() {
        assertEquals("tile_action", FocusTileService.EXTRA_TILE_ACTION)
        assertEquals("pause", FocusTileService.ACTION_PAUSE)
        assertEquals("resume", FocusTileService.ACTION_RESUME)
        assertEquals("stop", FocusTileService.ACTION_STOP)
    }

    @Test
    fun `REFRESH_IDLE_MS equals 60 seconds`() {
        // Idle tiles refresh less frequently to save battery.
        assertEquals(60_000L, FocusTileService.REFRESH_IDLE_MS)
    }
}
