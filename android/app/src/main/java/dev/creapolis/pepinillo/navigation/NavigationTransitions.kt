package dev.creapolis.pepinillo.navigation

import androidx.compose.animation.AnimatedContentTransitionScope
import androidx.compose.animation.EnterTransition
import androidx.compose.animation.ExitTransition
import androidx.compose.animation.core.tween
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.Spring
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically

/**
 * Single source of truth for navigation + shared-element animation timings and the
 * reusable enter/exit specs used across the app (#489).
 *
 * Durations live here as constants; the actual transition factories accept the resolved
 * duration so callers can pass `0` when "Reduce motion" is enabled (see
 * [dev.creapolis.pepinillo.ui.theme.isReduceMotionEnabled]), which makes every transition
 * effectively instant without needing per-call branches.
 */
object NavigationTransitions {

    /** Tab / top-level destinations (Focus ↔ Plan ↔ Dashboard ↔ More). */
    const val DURATION_TOP_LEVEL = 200

    /** Pushed detail routes (analytics, calendar, settings, paywall, …). */
    const val DURATION_DETAIL = 280

    /** Modal content such as the TaskDetail BottomSheet expressive entrance. */
    const val DURATION_MODAL = 320

    /** Subtle vertical travel used by detail push/pop (fraction of the element height). */
    private const val DETAIL_SLIDE_FRACTION = 12

    /**
     * Top-level fade in. Pass [durationMs] = 0 for instant transitions under Reduce motion.
     */
    fun topLevelEnter(durationMs: Int): AnimatedContentTransitionScope<*>.() -> EnterTransition = {
        fadeIn(tween(durationMs))
    }

    fun topLevelExit(durationMs: Int): AnimatedContentTransitionScope<*>.() -> ExitTransition = {
        fadeOut(tween(durationMs))
    }

    /**
     * Detail/push enter: fade + a subtle slide-up that reads as "stacking" on top of the
     * current screen. Symmetric with [detailPopExit].
     */
    fun detailEnter(durationMs: Int): AnimatedContentTransitionScope<*>.() -> EnterTransition = {
        fadeIn(tween(durationMs)) +
            slideInVertically(
                initialOffsetY = { it / DETAIL_SLIDE_FRACTION },
                animationSpec = tween(durationMs),
            )
    }

    /** Detail/pop exit: the inverse of [detailEnter] — fade + slide-down. */
    fun detailPopExit(durationMs: Int): AnimatedContentTransitionScope<*>.() -> ExitTransition = {
        fadeOut(tween(durationMs)) +
            slideOutVertically(
                targetOffsetY = { it / DETAIL_SLIDE_FRACTION },
                animationSpec = tween(durationMs),
            )
    }

    /**
     * Standard expressive spring for UI components (buttons, cards, chips) (#517).
     * High damping for stability with enough "snap" to feel responsive.
     */
    fun <T> expressiveSpring() = spring<T>(
        dampingRatio = Spring.DampingRatioNoBouncy,
        stiffness = Spring.StiffnessMediumLow,
    )
}
