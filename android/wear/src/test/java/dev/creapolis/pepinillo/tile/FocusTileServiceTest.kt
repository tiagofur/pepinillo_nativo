package dev.creapolis.pepinillo.tile

import org.junit.Assert.assertEquals
import org.junit.Test

class FocusTileServiceTest {

    @Test
    fun `REFRESH_ACTIVE_MS equals 30 seconds`() {
        // Bug #389: tile was refreshing every 5s, wasting GMS binder bandwidth.
        // Spec requires 30s interval for active tiles.
        assertEquals(30_000L, FocusTileService.REFRESH_ACTIVE_MS)
    }

    @Test
    fun `REFRESH_IDLE_MS equals 60 seconds`() {
        // Idle tiles refresh less frequently to save battery.
        assertEquals(60_000L, FocusTileService.REFRESH_IDLE_MS)
    }
}
