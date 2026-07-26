package dev.creapolis.pepinillo.presentation

import android.provider.Settings
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.geometry.RoundRect
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.PathMeasure
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.unit.Dp

/**
 * Wear OS counterpart of the phone's [dev.creapolis.pepinillo.feature.focus.components.CircularTimerRing].
 *
 * Wear Compose Material3's `CircularProgressIndicator` always draws a circular arc and cannot
 * morph its shape, so this Canvas-based ring mirrors the phone's circular→squircle morphing to
 * give both surfaces the same urgency cue during the last 20% of countdown sessions (Sprint 6, #492).
 *
 * @param progress     Session progress in [0f, 1f].
 * @param color        Progress arc color.
 * @param trackColor   Full-ring track color.
 * @param strokeWidth  Ring stroke width.
 * @param morphProgress 0f = circle, 1f = full squircle. Forced to 0f under Reduce Motion.
 */
@Composable
internal fun WearTimerRing(
    progress: Float,
    color: Color,
    trackColor: Color,
    strokeWidth: Dp,
    modifier: Modifier = Modifier,
    morphProgress: Float = 0f,
) {
    val strokeWidthPx = with(LocalDensity.current) { strokeWidth.toPx() }
    val reduceMotion = isReduceMotionEnabled()
    val actualMorph = if (reduceMotion) 0f else morphProgress

    Canvas(modifier = modifier.fillMaxSize()) {
        val diameter = size.minDimension
        val inset = strokeWidthPx / 2f
        val arcSize = Size(diameter - strokeWidthPx, diameter - strokeWidthPx)
        val topLeft = Offset(inset, inset)
        // Display floor: keep a sliver visible at very-near-zero progress. Under REMAINING
        // (#502) that happens at the *end* of a countdown; under count-up it's the *start*.
        val displayProgress = if (progress < 0.02f) 0.02f else progress

        if (actualMorph > 0.01f) {
            // Linear interpolation from the inscribed-circle radius down to a squircle radius.
            val circleRadius = diameter / 2f
            val squircleRadius = diameter * 0.22f
            val cornerRadius = circleRadius + (squircleRadius - circleRadius) * actualMorph
            val ringPath = Path().apply {
                addRoundRect(
                    RoundRect(
                        rect = Rect(topLeft, arcSize),
                        cornerRadius = CornerRadius(cornerRadius, cornerRadius),
                    )
                )
            }

            drawPath(
                path = ringPath,
                color = trackColor,
                style = Stroke(width = strokeWidthPx, cap = StrokeCap.Round),
            )

            if (displayProgress > 0f) {
                val fraction = displayProgress.coerceIn(0f, 1f)
                val progressPath = Path()
                val measure = PathMeasure().apply { setPath(ringPath, false) }
                
                // Align squircle origin with circle (12 o'clock) (#510).
                val startOffset = (arcSize.width / 2f) - cornerRadius
                measure.getSegment(startOffset, startOffset + measure.length * fraction, progressPath, true)
                drawPath(
                    path = progressPath,
                    color = color,
                    style = Stroke(width = strokeWidthPx, cap = StrokeCap.Round),
                )
            }
        } else {
            // Pure-circle path — matches the Wear M3 indicator the ring replaces.
            drawArc(
                color = trackColor,
                startAngle = -90f,
                sweepAngle = 360f,
                useCenter = false,
                topLeft = topLeft,
                size = arcSize,
                style = Stroke(width = strokeWidthPx, cap = StrokeCap.Round),
            )
            if (displayProgress > 0f) {
                drawArc(
                    color = color,
                    startAngle = -90f,
                    sweepAngle = 360f * displayProgress.coerceIn(0f, 1f),
                    useCenter = false,
                    topLeft = topLeft,
                    size = arcSize,
                    style = Stroke(width = strokeWidthPx, cap = StrokeCap.Round),
                )
            }
        }
    }
}

/**
 * Wear-local Reduce Motion check (ported from the app's `ThemeController.isReduceMotionEnabled`).
 * Kept here rather than shared because the :wear module cannot depend on :app; matching the
 * existing app behaviour (ANIMATOR_DURATION_SCALE == 0 ⇒ reduce motion).
 */
@Composable
internal fun isReduceMotionEnabled(): Boolean {
    val context = LocalContext.current
    val cached = remember(context) {
        try {
            val scale = Settings.Global.getFloat(
                context.contentResolver,
                Settings.Global.ANIMATOR_DURATION_SCALE,
                1f,
            )
            mutableStateOf(scale == 0f)
        } catch (_: Exception) {
            mutableStateOf(false)
        }
    }
    return cached.value
}

/**
 * Pure (no-Compose) morph target for Wear, mirroring the app's `TimerMorph.calculateMorphTarget`
 * so the formula stays consistent across surfaces without a cross-module dependency.
 *
 * **Polarity contract (#502 unified REMAINING):** [progress] is the **remaining fraction** of the
 * session for countdown modes (1f = full ring / just started, 0f = done). Count-up modes
 * (Flow/Chrono) are out of scope here — `hasCountdown` is false for them and the morph returns 0.
 * Callers pass `localProgress` directly: `WearTimerDisplay.tick` and the tile/complication
 * producers all yield REMAINING for countdown modes. The morph fires over the last 20% of the
 * session, i.e. when `progress` drops below [REMAINING_TRIGGER] (0.2f).
 *
 * @param sessionActive True only while a countdown is actually in progress (Running or Paused).
 */
internal object WearTimerMorph {
    /** Below this remaining fraction the squircle morph ramps in (the last 20% of the session). */
    const val REMAINING_TRIGGER = 0.2f
    const val WINDOW = 0.2f

    fun calculateMorphTarget(
        progress: Float,
        hasCountdown: Boolean,
        sessionActive: Boolean,
        reduceMotion: Boolean,
    ): Float {
        if (!hasCountdown || !sessionActive || reduceMotion) return 0f
        // REMAINING polarity (#502): morph ramps as progress falls from 0.2f → 0f (last 20%).
        if (progress >= REMAINING_TRIGGER) return 0f
        return ((REMAINING_TRIGGER - progress) / WINDOW).coerceIn(0f, 1f)
    }
}
