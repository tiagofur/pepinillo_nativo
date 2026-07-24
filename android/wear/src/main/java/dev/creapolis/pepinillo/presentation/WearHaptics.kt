package dev.creapolis.pepinillo.presentation

import androidx.compose.ui.hapticfeedback.HapticFeedback
import androidx.compose.ui.hapticfeedback.HapticFeedbackType

/**
 * Centralized Compose haptics for Wear OS. Mirrors the phone-side [PepinilloHaptics] but
 * lives in the wear module (separate codebase). The watch already receives phase-completion
 * vibrations from [dev.creapolis.pepinillo.service.WearSyncListenerService.vibrateWatch] when
 * the phone signals a phase transition; this object only owns local UI-tap haptics.
 *
 * Note: Wear has no settings UI for a haptic master toggle, so these always fire on taps.
 * Phase-completion vibration is driven by the phone's sync events, not here.
 */
object WearHaptics {

    /** Confirmation pulse for control taps (pause/resume/stop/skip). */
    fun onControlTap(haptic: HapticFeedback) {
        haptic.performHapticFeedback(HapticFeedbackType.LongPress)
    }

    /** Pulse when starting/selecting a focus mode. */
    fun onModeSelect(haptic: HapticFeedback) {
        haptic.performHapticFeedback(HapticFeedbackType.LongPress)
    }

    /** Confirmation pulse for long-press / task-complete confirmation gestures. */
    fun onConfirm(haptic: HapticFeedback) {
        haptic.performHapticFeedback(HapticFeedbackType.LongPress)
    }
}
