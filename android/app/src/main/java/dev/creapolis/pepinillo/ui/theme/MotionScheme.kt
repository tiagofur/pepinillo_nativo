package dev.creapolis.pepinillo.ui.theme

import androidx.compose.animation.EnterTransition
import androidx.compose.animation.ExitTransition
import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import dev.creapolis.pepinillo.navigation.NavigationTransitions

/**
 * App-wide expressive-motion tokens — the single source of truth for every spring, tween
 * duration and transition spec outside navigation (#517 / JD-17).
 *
 * [NavigationTransitions] already owns nav-enter/exit specs and the [NavigationTransitions.DURATION_TOP_LEVEL]
 * / [NavigationTransitions.DURATION_DETAIL] / [NavigationTransitions.DURATION_MODAL] constants.
 * This object complements it with the tokens the rest of the UI needs, so screens stop hand-picking
 * ad-hoc springs, magic-number durations and silent Compose defaults.
 *
 * Three motion "characters" are recognised, each with its own token so the app can keep one
 * deliberate, expressive feel rather than many one-offs:
 *
 * - **Standard** ([standardSpring]) — stable, critically-damped motion for state/colour changes.
 *   Wraps [NavigationTransitions.expressiveSpring] (NoBouncy / StiffnessMediumLow).
 * - **Effects** ([effectsSpring]) — a bouncier spring reserved for satisfying micro-feedback
 *   (checkbox "pop", bottom-sheet entrance). MediumBouncy / StiffnessMedium.
 * - **Tweens** — colour and fade transitions on explicit duration tokens below.
 *
 * ## Reduce motion
 * The `reduceMotion` parameter on the spring helpers lets a caller collapse motion to an
 * instant snap when the user has enabled "Remove animations". Navigation and infinite
 * animations already honor this elsewhere; wiring the scattered springs is an incremental
 * follow-up that does not change current behaviour, so callers pass the default (`false`)
 * unless they already have the flag in scope.
 *
 * ## Policy
 * Every value here is pinned to what the app shipped before #517, so swapping an inline
 * `spring(...)` or `tween(400)` for the matching token is a pure refactor with zero visual
 * change. The one deliberate behavioural shift is replacing bare `spring()` (which silently
 * used Compose's bouncy default) with [standardSpring] — that stabilises those transitions
 * and is exactly what JD-17 asked for.
 */
object MotionScheme {

    // ───────── Springs ─────────

    /**
     * Standard spring for state/colour changes — stable and critically damped. Wraps
     * [NavigationTransitions.expressiveSpring]. Pass [reduceMotion] = true to snap instantly.
     */
    fun <T> standardSpring(reduceMotion: Boolean = false): androidx.compose.animation.core.FiniteAnimationSpec<T> =
        if (reduceMotion) {
            spring(stiffness = Spring.StiffnessHigh)
        } else {
            NavigationTransitions.expressiveSpring()
        }

    /**
     * Effects spring for satisfying micro-feedback (checkbox pop, sheet entrance). Bouncier
     * than [standardSpring]. Pass [reduceMotion] = true to snap instantly.
     */
    fun <T> effectsSpring(reduceMotion: Boolean = false): androidx.compose.animation.core.FiniteAnimationSpec<T> =
        if (reduceMotion) {
            spring(stiffness = Spring.StiffnessHigh)
        } else {
            spring(
                dampingRatio = Spring.DampingRatioMediumBouncy,
                stiffness = Spring.StiffnessMedium,
            )
        }

    // ───────── Durations ─────────

    /** Accent / focus colour transitions (was 400ms). */
    const val DURATION_COLOR = 400

    /** Slower task-item colour transitions (was 500ms). */
    const val DURATION_COLOR_SLOW = 500

    /** Quick exit fade (was 180ms). */
    const val DURATION_FADE_FAST = 180

    /** Standard enter fade (was 240ms). */
    const val DURATION_FADE = 240

    /** Onboarding pager transitions (was 350ms). */
    const val DURATION_ONBOARDING = 350

    /** Infinite: focus "breathe" emoji scale (was 1000ms). */
    const val DURATION_BREATHE = 1000

    /** Infinite: shimmer translate (was 1400ms). */
    const val DURATION_SHIMMER = 1400

    /** Infinite: timer ring pulse (was 1800ms). */
    const val DURATION_RING_PULSE = 1800

    // ───────── Transition specs ─────────

    /** Expressive entrance for modal/bottom-sheet content: scale-in (0.93) + fade. */
    fun expressiveSheetEnter(reduceMotion: Boolean = false): EnterTransition =
        if (reduceMotion) {
            fadeIn(tween(0))
        } else {
            fadeIn(tween(NavigationTransitions.DURATION_MODAL)) +
                scaleIn(
                    initialScale = 0.93f,
                    animationSpec = effectsSpring(),
                )
        }

    /** Fade-in factory; pass `0` for an instant transition under Reduce motion. */
    fun fadeEnter(durationMs: Int = DURATION_FADE): EnterTransition = fadeIn(tween(durationMs))

    /** Fade-out factory; pass `0` for an instant transition under Reduce motion. */
    fun fadeExit(durationMs: Int = DURATION_FADE_FAST): ExitTransition = fadeOut(tween(durationMs))
}
