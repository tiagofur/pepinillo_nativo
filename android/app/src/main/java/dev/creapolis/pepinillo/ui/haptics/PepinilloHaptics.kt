package dev.creapolis.pepinillo.ui.haptics

import androidx.compose.ui.hapticfeedback.HapticFeedback
import androidx.compose.ui.hapticfeedback.HapticFeedbackType

/**
 * Centralized entry point for Compose UI haptics across the app.
 *
 * Every call is gated by the master `vibrationEnabled` preference, passed in as [enabled]
 * by each screen. This keeps haptic behaviour consistent and gives users a single switch to
 * silence all tactile feedback.
 *
 * Platform-level haptics (phase-completion vibration via `Vibrator`/`VibrationEffect`) live
 * in `platform/feedback/FeedbackManager` and are driven by `FocusEngine`. This object only
 * owns the lightweight Compose haptics fired directly from the UI layer.
 *
 * @see dev.creapolis.pepinillo.platform.feedback.FeedbackManager
 */
object PepinilloHaptics {

    /** Pulso satisfactorio al marcar una tarea como completada. */
    fun onTaskComplete(haptic: HapticFeedback, enabled: Boolean) {
        if (enabled) haptic.performHapticFeedback(HapticFeedbackType.LongPress)
    }

    /** Confirmación suave al cambiar de modo de foco. */
    fun onModeChange(haptic: HapticFeedback, enabled: Boolean) {
        if (enabled) haptic.performHapticFeedback(HapticFeedbackType.LongPress)
    }

    /** Micro-pulso en cada tick periódico del timer para feedback táctil vivo. */
    fun onTimerTickUI(haptic: HapticFeedback, enabled: Boolean) {
        if (enabled) haptic.performHapticFeedback(HapticFeedbackType.TextHandleMove)
    }

    /** Pulso ligero al pulsar un botón de control del timer (pausar/reanudar/stop/skip). */
    fun onControlTap(haptic: HapticFeedback, enabled: Boolean, light: Boolean = false) {
        if (!enabled) return
        haptic.performHapticFeedback(
            if (light) HapticFeedbackType.TextHandleMove else HapticFeedbackType.LongPress
        )
    }
}
