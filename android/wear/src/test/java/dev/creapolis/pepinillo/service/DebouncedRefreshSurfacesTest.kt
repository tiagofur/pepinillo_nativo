package dev.creapolis.pepinillo.service

import kotlinx.coroutines.delay
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Test

class DebouncedRefreshSurfacesTest {

    @Test
    fun `debounce collapses rapid calls into one refresh`() = runBlocking {
        var refreshCount = 0
        val debouncer = DebouncedRefreshSurfaces(this) { refreshCount++ }

        // Simulate 3 rapid calls within 200ms window
        debouncer.submit()
        delay(50)
        debouncer.submit()
        delay(50)
        debouncer.submit()

        // Before debounce window expires — no refresh yet
        assertEquals(0, refreshCount)

        // Advance past debounce window
        delay(250)

        // Only one refresh should have fired
        assertEquals(1, refreshCount)
    }

    @Test
    fun `separate calls outside debounce window produce separate refreshes`() = runBlocking {
        var refreshCount = 0
        val debouncer = DebouncedRefreshSurfaces(this) { refreshCount++ }

        // First call
        debouncer.submit()
        delay(250) // past debounce window
        assertEquals(1, refreshCount)

        // Second call — outside window, should fire separately
        debouncer.submit()
        delay(250)
        assertEquals(2, refreshCount)
    }
}
