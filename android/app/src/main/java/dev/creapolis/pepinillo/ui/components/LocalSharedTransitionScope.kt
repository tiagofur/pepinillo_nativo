package dev.creapolis.pepinillo.ui.components

import androidx.compose.animation.AnimatedVisibilityScope
import androidx.compose.animation.ExperimentalSharedTransitionApi
import androidx.compose.animation.SharedTransitionScope
import androidx.compose.runtime.Composable
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.Modifier
import dev.creapolis.pepinillo.ui.theme.isReduceMotionEnabled

/**
 * Injects the [SharedTransitionScope] from the [androidx.compose.animation.SharedTransitionLayout]
 * that wraps the NavHost in [dev.creapolis.pepinillo.MainActivity], without polluting screen
 * signatures. `null` outside of a shared-transition host (e.g. previews) (#489).
 */
@OptIn(ExperimentalSharedTransitionApi::class)
val LocalSharedTransitionScope = staticCompositionLocalOf<SharedTransitionScope?> { null }

/**
 * Injects the per-destination [AnimatedVisibilityScope] (the `this` receiver of each
 * `composable { }` lambda) so screens can wire shared elements without receiving it as a param.
 * Provided once per participating destination in MainActivity.
 */
val LocalNavAnimatedVisibilityScope = staticCompositionLocalOf<AnimatedVisibilityScope?> { null }

/**
 * Returns a [Modifier] tagging this composable as a shared-bounds anchor with [key].
 *
 * - Returns [Modifier] (no-op) when there is no shared-transition host (previews / tests) or no
 *   [AnimatedVisibilityScope] for the current destination.
 * - When "Reduce motion" is enabled, shared bounds are disabled so the swap is instant rather
 *   than animated (#489 acceptance criterion #7).
 *
 * Use [sharedBounds] (not [SharedTransitionScope.sharedElement]) because the matched anchors
 * often differ in content/size (e.g. a toolbar icon morphing into a screen title) and
 * `sharedBounds` cross-fades the contents while animating the bounds — the intended effect.
 */
@OptIn(ExperimentalSharedTransitionApi::class)
@Composable
fun rememberSharedBoundsModifier(key: String): Modifier {
    val sharedScope = LocalSharedTransitionScope.current ?: return Modifier
    val visibilityScope = LocalNavAnimatedVisibilityScope.current ?: return Modifier
    // Reduce motion: skip shared-element animation entirely → instant swap.
    if (isReduceMotionEnabled()) return Modifier

    with(sharedScope) {
        return Modifier.sharedBounds(
            rememberSharedContentState(key = key),
            animatedVisibilityScope = visibilityScope,
        )
    }
}
