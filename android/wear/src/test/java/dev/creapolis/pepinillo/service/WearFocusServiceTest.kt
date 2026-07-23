package dev.creapolis.pepinillo.service

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class WearFocusServiceTest {

    @Test
    fun `Idle status should stop service`() {
        // This will FAIL until isForegroundServiceStatus("Idle") is implemented
        assertFalse(WearFocusService.isForegroundServiceStatus("Idle"))
    }

    @Test
    fun `Running status should keep service alive`() {
        assertTrue(WearFocusService.isForegroundServiceStatus("Running"))
    }

    @Test
    fun `Paused status should keep service alive`() {
        assertTrue(WearFocusService.isForegroundServiceStatus("Paused"))
    }

    @Test
    fun `WaitingForNext status should keep service alive`() {
        // This is the bug fix: WaitingForNext should NOT stop the service
        assertTrue(WearFocusService.isForegroundServiceStatus("WaitingForNext"))
    }

    @Test
    fun `unknown status should stop service`() {
        assertFalse(WearFocusService.isForegroundServiceStatus("Unknown"))
    }

    @Test
    fun `empty status should stop service`() {
        assertFalse(WearFocusService.isForegroundServiceStatus(""))
    }
}
