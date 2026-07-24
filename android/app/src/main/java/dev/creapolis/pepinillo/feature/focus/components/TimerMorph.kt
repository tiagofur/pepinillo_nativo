package dev.creapolis.pepinillo.feature.focus.components

/**
 * Pure (no-Compose) calculation of the circular→squircle morph target for [CircularTimerRing].
 *
 * Extracted from the Composable so it can be unit-tested on the JVM without Robolectric.
 * The morphing communicates urgency peripherally (Sprint 6, #492): when a countdown session
 * reaches its final 20%, the ring gradually morphs from a perfect circle toward a squircle.
 * Count-up modes (Flow, Chrono) and "Reduce Motion" keep the ring perfectly circular.
 *
 * @param progress     Current session progress in [0f, 1f].
 * @param hasCountdown True for modes with a fixed total (Pomodoro, Blocks); false for count-up
 *                     modes (Flow, Chrono) where the ring must stay circular.
 * @param reduceMotion True when the user enabled "Reduce Motion" — disables morphing entirely.
 * @return Morph amount in [0f, 1f]: 0f = circle, 1f = full squircle.
 */
object TimerMorph {
    /** Progress above which morphing begins (last 20% of the session). */
    const val THRESHOLD = 0.8f

    /** Width of the morphing window; morph goes 0→1 across [THRESHOLD, THRESHOLD + WINDOW]. */
    const val WINDOW = 0.2f

    fun calculateMorphTarget(
        progress: Float,
        hasCountdown: Boolean,
        reduceMotion: Boolean,
    ): Float {
        if (!hasCountdown || reduceMotion) return 0f
        if (progress <= THRESHOLD) return 0f
        return ((progress - THRESHOLD) / WINDOW).coerceIn(0f, 1f)
    }
}
