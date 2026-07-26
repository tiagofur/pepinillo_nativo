package dev.creapolis.pepinillo.feature.focus.components

/**
 * Pure (no-Compose) calculation of the circular→squircle morph target for [CircularTimerRing].
 *
 * Extracted from the Composable so it can be unit-tested on the JVM without Robolectric.
 * The morphing communicates urgency peripherally (Sprint 6, #492): when a countdown session
 * reaches its final 20%, the ring gradually morphs from a perfect circle toward a squircle.
 * Count-up modes (Flow, Chrono), inactive sessions, and "Reduce Motion" keep the ring circular.
 *
 * **Polarity contract (#501 regression fix):** [progress] is the **elapsed fraction** of the
 * session (0f = just started, 1f = finished). The phone's `FocusTimerState.progress` is the
 * opposite (remaining fraction), so callers MUST pass `1f - state.progress`. Wear's tick helper
 * already yields the elapsed fraction directly. Without this convention, idle/start (remaining
 * = 1f) produced a full squircle and the final stretch produced a circle — the inverse of #492.
 *
 * @param progress       Elapsed fraction of the session in [0f, 1f] (NOT remaining).
 * @param hasCountdown   True for modes with a fixed total (Pomodoro, Blocks); false for count-up
 *                       modes (Flow, Chrono) where the ring must stay circular.
 * @param sessionActive  True only while a countdown is actually in progress (Running or Paused).
 *                       Idle/WaitingForNext states keep progress pinned at 1f (full) on the phone,
 *                       which would otherwise read as "session complete" — gate to 0 here.
 * @param reduceMotion   True when the user enabled "Reduce Motion" — disables morphing entirely.
 * @return Morph amount in [0f, 1f]: 0f = circle, 1f = full squircle.
 */
object TimerMorph {
    /** Elapsed fraction above which morphing begins (last 20% of the session). */
    const val THRESHOLD = 0.8f

    /** Width of the morphing window; morph goes 0→1 across [THRESHOLD, THRESHOLD + WINDOW]. */
    const val WINDOW = 0.2f

    fun calculateMorphTarget(
        progress: Float,
        hasCountdown: Boolean,
        sessionActive: Boolean,
        reduceMotion: Boolean,
    ): Float {
        if (!hasCountdown || !sessionActive || reduceMotion) return 0f
        if (progress <= THRESHOLD) return 0f
        return ((progress - THRESHOLD) / WINDOW).coerceIn(0f, 1f)
    }
}
