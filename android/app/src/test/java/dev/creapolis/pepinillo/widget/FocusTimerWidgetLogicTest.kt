package dev.creapolis.pepinillo.widget

import dev.creapolis.pepinillo.domain.timer.TimerStatus
import dev.creapolis.pepinillo.service.FocusTimerService
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class FocusTimerWidgetLogicTest {

    @Test
    fun `WaitingForNext is treated as active session`() {
        assertTrue(FocusTimerWidgetLogic.isActiveSession(TimerStatus.WaitingForNext))
    }

    @Test
    fun `Idle is not active session`() {
        assertFalse(FocusTimerWidgetLogic.isActiveSession(TimerStatus.Idle))
    }

    @Test
    fun `WaitingForNext primary control uses RESUME not START_MODE`() {
        assertEquals(
            FocusTimerService.ACTION_RESUME,
            FocusTimerWidgetLogic.primaryControlAction(TimerStatus.WaitingForNext),
        )
    }

    @Test
    fun `Running primary control uses PAUSE`() {
        assertEquals(
            FocusTimerService.ACTION_PAUSE,
            FocusTimerWidgetLogic.primaryControlAction(TimerStatus.Running),
        )
    }

    @Test
    fun `Idle primary control uses START_MODE`() {
        assertEquals(
            FocusTimerService.ACTION_START_MODE,
            FocusTimerWidgetLogic.primaryControlAction(TimerStatus.Idle),
        )
    }

    @Test
    fun `running countdown uses shorter widget throttle`() {
        assertEquals(1_000L, FocusTimerWidgetLogic.widgetUpdateThrottleMs(TimerStatus.Running))
        assertEquals(30_000L, FocusTimerWidgetLogic.widgetUpdateThrottleMs(TimerStatus.Paused))
    }

    // P2(g): the count-up widget chronometer used to mix clocks — a wall/monotonic
    // snapshot of elapsed combined with the render-time monotonic reading — so a
    // re-render after deep sleep jumped the timer. The base must come from the
    // (anchor, elapsed) pair persisted together, not from the render-time clock.
    @Test
    fun `count-up chronometer base uses the persisted monotonic anchor, not the render-time clock`() {
        val earlyRender = FocusTimerWidgetLogic.countUpChronometerBase(
            elapsedMillis = 150_000L,
            anchorElapsedRealtime = 600_000L,
            nowElapsedRealtime = 600_000L,
        )
        val lateRender = FocusTimerWidgetLogic.countUpChronometerBase(
            elapsedMillis = 150_000L,
            anchorElapsedRealtime = 600_000L,
            nowElapsedRealtime = 9_000_000L,
        )

        assertEquals(450_000L, earlyRender)
        assertEquals("base must not depend on when the widget re-renders", earlyRender, lateRender)
    }

    @Test
    fun `count-up chronometer base falls back to render-time clock when no anchor is stored`() {
        // Legacy states persisted before the anchor existed keep the old behavior.
        assertEquals(
            850_000L,
            FocusTimerWidgetLogic.countUpChronometerBase(
                elapsedMillis = 150_000L,
                anchorElapsedRealtime = null,
                nowElapsedRealtime = 1_000_000L,
            ),
        )
    }
}