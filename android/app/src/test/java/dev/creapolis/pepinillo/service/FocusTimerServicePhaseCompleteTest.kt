package dev.creapolis.pepinillo.service

import dev.creapolis.pepinillo.domain.timer.FocusPhase
import dev.creapolis.pepinillo.domain.timer.TimerStatus
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Documents the call-site logic in [FocusTimerService]'s state collector that decides
 * when to invoke [dev.creapolis.pepinillo.wear.WearDataLayerHelper.pushPhaseComplete].
 */
class FocusTimerServicePhaseCompleteTest {

    private fun shouldPushPhaseComplete(
        previousStatus: TimerStatus?,
        previousPhase: FocusPhase?,
        currentStatus: TimerStatus,
        currentPhase: FocusPhase,
    ): Boolean {
        val phaseCompletedForWaiting = previousStatus == TimerStatus.Running &&
            currentStatus == TimerStatus.WaitingForNext &&
            previousPhase != null
        val phaseChangedWhileRunning = previousStatus == TimerStatus.Running &&
            currentStatus == TimerStatus.Running &&
            previousPhase != null &&
            currentPhase != previousPhase
        return phaseCompletedForWaiting || phaseChangedWhileRunning
    }

    @Test
    fun `Running to WaitingForNext pushes using previous phase`() {
        assertTrue(
            shouldPushPhaseComplete(
                previousStatus = TimerStatus.Running,
                previousPhase = FocusPhase.Work,
                currentStatus = TimerStatus.WaitingForNext,
                currentPhase = FocusPhase.ShortBreak,
            ),
        )
    }

    @Test
    fun `Running to Running with phase change pushes for auto-start path`() {
        assertTrue(
            shouldPushPhaseComplete(
                previousStatus = TimerStatus.Running,
                previousPhase = FocusPhase.Work,
                currentStatus = TimerStatus.Running,
                currentPhase = FocusPhase.ShortBreak,
            ),
        )
    }

    @Test
    fun `steady Running tick does not push`() {
        assertFalse(
            shouldPushPhaseComplete(
                previousStatus = TimerStatus.Running,
                previousPhase = FocusPhase.Work,
                currentStatus = TimerStatus.Running,
                currentPhase = FocusPhase.Work,
            ),
        )
    }

    @Test
    fun `Paused transition does not push`() {
        assertFalse(
            shouldPushPhaseComplete(
                previousStatus = TimerStatus.Running,
                previousPhase = FocusPhase.Work,
                currentStatus = TimerStatus.Paused,
                currentPhase = FocusPhase.Work,
            ),
        )
    }
}