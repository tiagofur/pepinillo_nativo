package dev.creapolis.pepinillo.data.sync

import org.junit.Assert.assertEquals
import org.junit.Test

class FocusPhaseSyncMapperTest {

    @Test
    fun `toServerPhase maps canonical local pomodoro phases`() {
        assertEquals("work", FocusPhaseSyncMapper.toServerPhase("Work"))
        assertEquals("short_break", FocusPhaseSyncMapper.toServerPhase("ShortBreak"))
        assertEquals("long_break", FocusPhaseSyncMapper.toServerPhase("LongBreak"))
    }

    @Test
    fun `toLocalPhase maps canonical server wire phases`() {
        assertEquals("Work", FocusPhaseSyncMapper.toLocalPhase("work"))
        assertEquals("ShortBreak", FocusPhaseSyncMapper.toLocalPhase("short_break"))
        assertEquals("LongBreak", FocusPhaseSyncMapper.toLocalPhase("long_break"))
    }

    @Test
    fun `toLocalPhase maps legacy display strings with spaces`() {
        assertEquals("ShortBreak", FocusPhaseSyncMapper.toLocalPhase("Short Break"))
        assertEquals("LongBreak", FocusPhaseSyncMapper.toLocalPhase("Long Break"))
        assertEquals("CheckIn", FocusPhaseSyncMapper.toLocalPhase("Check In"))
    }

    @Test
    fun `toServerPhase maps non-pomodoro local phases`() {
        assertEquals("flow", FocusPhaseSyncMapper.toServerPhase("Flow"))
        assertEquals("break", FocusPhaseSyncMapper.toServerPhase("Break"))
        assertEquals("check_in", FocusPhaseSyncMapper.toServerPhase("CheckIn"))
        assertEquals("freeform", FocusPhaseSyncMapper.toServerPhase("Freeform"))
    }

    @Test
    fun `toLocalPhase maps non-pomodoro server phases`() {
        assertEquals("Flow", FocusPhaseSyncMapper.toLocalPhase("flow"))
        assertEquals("Break", FocusPhaseSyncMapper.toLocalPhase("break"))
        assertEquals("CheckIn", FocusPhaseSyncMapper.toLocalPhase("check_in"))
        assertEquals("Freeform", FocusPhaseSyncMapper.toLocalPhase("freeform"))
    }

    @Test
    fun `canonical pomodoro phases round-trip`() {
        val phases = listOf("Work", "ShortBreak", "LongBreak")
        for (local in phases) {
            val server = FocusPhaseSyncMapper.toServerPhase(local)
            assertEquals(local, FocusPhaseSyncMapper.toLocalPhase(server))
        }
    }

    @Test
    fun `unknown local phase falls back to work on server`() {
        assertEquals("work", FocusPhaseSyncMapper.toServerPhase("unknown"))
    }

    @Test
    fun `null-safe outbound default uses work wire format`() {
        assertEquals("work", FocusPhaseSyncMapper.toServerPhase("Work"))
    }
}