package dev.creapolis.pepinillo.feature.focus

import dev.creapolis.pepinillo.domain.timer.TimerStatus
import dev.creapolis.pepinillo.feature.focus.components.FocusPipLogic
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class FocusPipLogicTest {

    @Test
    fun `resolveEffectivePipMode returns true when either state or activity reports PiP`() {
        assertTrue(FocusPipLogic.resolveEffectivePipMode(statePipMode = true, activityInPipMode = false))
        assertTrue(FocusPipLogic.resolveEffectivePipMode(statePipMode = false, activityInPipMode = true))
        assertTrue(FocusPipLogic.resolveEffectivePipMode(statePipMode = true, activityInPipMode = true))
        assertFalse(FocusPipLogic.resolveEffectivePipMode(statePipMode = false, activityInPipMode = false))
    }

    @Test
    fun `shouldAutoEnterPip returns true only when timer is running`() {
        assertTrue(FocusPipLogic.shouldAutoEnterPip(TimerStatus.Running))
        assertFalse(FocusPipLogic.shouldAutoEnterPip(TimerStatus.Idle))
        assertFalse(FocusPipLogic.shouldAutoEnterPip(TimerStatus.Paused))
        assertFalse(FocusPipLogic.shouldAutoEnterPip(TimerStatus.WaitingForNext))
    }
}
