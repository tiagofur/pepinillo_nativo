package dev.creapolis.pepinillo.widget

import dev.creapolis.pepinillo.domain.timer.FocusEngine
import dev.creapolis.pepinillo.domain.timer.FocusTimerState
import dev.creapolis.pepinillo.domain.timer.TimerStatus
import dev.creapolis.pepinillo.feature.focus.FocusMode
import kotlinx.coroutines.flow.StateFlow
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class FocusWidgetBridge @Inject constructor(
    private val focusEngine: FocusEngine,
) {
    val state: StateFlow<FocusTimerState> = focusEngine.state

    fun selectMode(mode: FocusMode) = focusEngine.selectMode(mode)
    fun start() = focusEngine.start()
    fun pause() = focusEngine.pause()
    fun stop() = focusEngine.stop()
}
