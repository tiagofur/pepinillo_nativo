package dev.creapolis.pepinillo.ui.haptics

import androidx.compose.ui.hapticfeedback.HapticFeedback
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Pure-JVM unit tests for [PepinilloHaptics]. [HapticFeedback] is a single-method interface,
 * so we record calls with a tiny fake — no Robolectric or instrumentation required.
 */
class PepinilloHapticsTest {

    /** Records every [HapticFeedbackType] passed to performHapticFeedback. */
    private class RecordingHapticFeedback : HapticFeedback {
        val performed = mutableListOf<HapticFeedbackType>()
        override fun performHapticFeedback(hapticFeedbackType: HapticFeedbackType) {
            performed += hapticFeedbackType
        }
    }

    @Test
    fun `onTaskComplete fires LongPress when enabled`() {
        val haptic = RecordingHapticFeedback()

        PepinilloHaptics.onTaskComplete(haptic, enabled = true)

        assertEquals(listOf(HapticFeedbackType.LongPress), haptic.performed)
    }

    @Test
    fun `onTaskComplete is silent when disabled`() {
        val haptic = RecordingHapticFeedback()

        PepinilloHaptics.onTaskComplete(haptic, enabled = false)

        assertTrue("No haptic should fire when the master toggle is off", haptic.performed.isEmpty())
    }

    @Test
    fun `onModeChange fires LongPress when enabled`() {
        val haptic = RecordingHapticFeedback()

        PepinilloHaptics.onModeChange(haptic, enabled = true)

        assertEquals(listOf(HapticFeedbackType.LongPress), haptic.performed)
    }

    @Test
    fun `onModeChange is silent when disabled`() {
        val haptic = RecordingHapticFeedback()

        PepinilloHaptics.onModeChange(haptic, enabled = false)

        assertTrue(haptic.performed.isEmpty())
    }

    @Test
    fun `onTimerTickUI fires TextHandleMove when enabled`() {
        val haptic = RecordingHapticFeedback()

        PepinilloHaptics.onTimerTickUI(haptic, enabled = true)

        assertEquals(listOf(HapticFeedbackType.TextHandleMove), haptic.performed)
    }

    @Test
    fun `onTimerTickUI is silent when disabled`() {
        val haptic = RecordingHapticFeedback()

        PepinilloHaptics.onTimerTickUI(haptic, enabled = false)

        assertTrue(haptic.performed.isEmpty())
    }

    @Test
    fun `onControlTap fires LongPress by default when enabled`() {
        val haptic = RecordingHapticFeedback()

        PepinilloHaptics.onControlTap(haptic, enabled = true)

        assertEquals(listOf(HapticFeedbackType.LongPress), haptic.performed)
    }

    @Test
    fun `onControlTap fires lighter TextHandleMove when light flag set`() {
        val haptic = RecordingHapticFeedback()

        PepinilloHaptics.onControlTap(haptic, enabled = true, light = true)

        assertEquals(listOf(HapticFeedbackType.TextHandleMove), haptic.performed)
    }

    @Test
    fun `onControlTap is silent when disabled regardless of light flag`() {
        val haptic = RecordingHapticFeedback()

        PepinilloHaptics.onControlTap(haptic, enabled = false, light = true)

        assertTrue(haptic.performed.isEmpty())
    }
}
