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
}