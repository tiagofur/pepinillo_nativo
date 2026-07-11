package dev.creapolis.pepinillo.data.sync

import org.junit.Assert.assertEquals
import org.junit.Test

class FocusModeSyncMapperTest {

    @Test
    fun `toServerMode maps canonical local modes`() {
        assertEquals("pomodoro", FocusModeSyncMapper.toServerMode("Pomodoro"))
        assertEquals("flowtime", FocusModeSyncMapper.toServerMode("Flow"))
        assertEquals("timeblock", FocusModeSyncMapper.toServerMode("Blocks"))
        assertEquals("stopwatch", FocusModeSyncMapper.toServerMode("Chrono"))
    }

    @Test
    fun `toServerMode maps legacy local aliases`() {
        assertEquals("flowtime", FocusModeSyncMapper.toServerMode("flowtime"))
        assertEquals("flowtime", FocusModeSyncMapper.toServerMode("Flowtime"))
        assertEquals("timeblock", FocusModeSyncMapper.toServerMode("TimeBlock"))
        assertEquals("timeblock", FocusModeSyncMapper.toServerMode("time block"))
        assertEquals("timeblock", FocusModeSyncMapper.toServerMode("timeblocking"))
        assertEquals("stopwatch", FocusModeSyncMapper.toServerMode("Stopwatch"))
        assertEquals("stopwatch", FocusModeSyncMapper.toServerMode("stopwatch"))
    }

    @Test
    fun `toLocalMode maps canonical server modes`() {
        assertEquals("Pomodoro", FocusModeSyncMapper.toLocalMode("pomodoro"))
        assertEquals("Flow", FocusModeSyncMapper.toLocalMode("flowtime"))
        assertEquals("Blocks", FocusModeSyncMapper.toLocalMode("timeblock"))
        assertEquals("Chrono", FocusModeSyncMapper.toLocalMode("stopwatch"))
    }

    @Test
    fun `toLocalMode maps legacy server aliases`() {
        assertEquals("Flow", FocusModeSyncMapper.toLocalMode("flow"))
        assertEquals("Blocks", FocusModeSyncMapper.toLocalMode("blocks"))
        assertEquals("Blocks", FocusModeSyncMapper.toLocalMode("time block"))
        assertEquals("Blocks", FocusModeSyncMapper.toLocalMode("timeblocking"))
        assertEquals("Chrono", FocusModeSyncMapper.toLocalMode("chrono"))
    }

    @Test
    fun `toLocalMode maps legacy wrong inbound names`() {
        assertEquals("Flow", FocusModeSyncMapper.toLocalMode("Flowtime"))
        assertEquals("Blocks", FocusModeSyncMapper.toLocalMode("TimeBlock"))
        assertEquals("Chrono", FocusModeSyncMapper.toLocalMode("Stopwatch"))
    }

    @Test
    fun `canonical local modes round-trip through server wire strings`() {
        val localModes = listOf("Pomodoro", "Flow", "Blocks", "Chrono")
        for (local in localModes) {
            val server = FocusModeSyncMapper.toServerMode(local)
            assertEquals(local, FocusModeSyncMapper.toLocalMode(server))
        }
    }

    @Test
    fun `unknown local mode falls back to pomodoro on server`() {
        assertEquals("pomodoro", FocusModeSyncMapper.toServerMode("unknown"))
    }

    @Test
    fun `unknown server mode falls back to Pomodoro locally`() {
        assertEquals("Pomodoro", FocusModeSyncMapper.toLocalMode("unknown"))
    }
}