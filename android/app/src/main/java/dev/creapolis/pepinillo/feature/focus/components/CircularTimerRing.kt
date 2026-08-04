package dev.creapolis.pepinillo.feature.focus.components

import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.size
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
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.PathMeasure
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import dev.creapolis.pepinillo.ui.theme.MotionScheme
import dev.creapolis.pepinillo.ui.theme.PepinilloTheme
import dev.creapolis.pepinillo.ui.theme.isReduceMotionEnabled

@Composable
fun CircularTimerRing(
    progress: Float,
    ringColor: Color,
    trackColor: Color,
    strokeWidth: Dp = 13.dp,
    modifier: Modifier = Modifier,
    isRunning: Boolean = false,
    showDashedOverlay: Boolean = false,
    /**
     * Circular→squircle morph amount in [0f, 1f] (Sprint 6, #492).
     * `0f` = perfect circle (default), `1f` = full squircle. The morphing communicates urgency
     * peripherally during the last 20% of countdown sessions. Forced to `0f` under "Reduce Motion".
     * See [TimerMorph] for the testable calculation of this value.
     */
    morphProgress: Float = 0f,
) {
    val strokeWidthPx = with(LocalDensity.current) { strokeWidth.toPx() }
    val dashPx = with(LocalDensity.current) { 4.dp.toPx() }
    val gapPx = with(LocalDensity.current) { 10.dp.toPx() }

    // Ring pulse — disabled when reduce-motion is on (#401).
    val pulseAlpha by if (isReduceMotionEnabled()) {
        remember { mutableStateOf(0.5f) }
    } else {
        val infiniteTransition = rememberInfiniteTransition(label = "ringPulse")
        infiniteTransition.animateFloat(
            initialValue = 0.3f,
            targetValue = 0.7f,
            animationSpec = infiniteRepeatable(
                animation = tween(MotionScheme.DURATION_RING_PULSE, easing = FastOutSlowInEasing),
                repeatMode = RepeatMode.Reverse
            ),
            label = "pulseAlpha"
        )
    }

    // Reduce Motion also disables morphing — the ring stays perfectly circular (#492).
    val reduceMotion = isReduceMotionEnabled()
    val actualMorph = if (reduceMotion) 0f else morphProgress

    Canvas(modifier = modifier) {
        val diameter = size.minDimension
        val inset = strokeWidthPx / 2f
        val arcSize = Size(diameter - strokeWidthPx, diameter - strokeWidthPx)
        val topLeft = Offset(inset, inset)

        // Display floor: when the session is running but progress is ~0 (count-up modes
        // such as Flow and Chrono start empty), draw a minimum 2% sweep so the ring never
        // reads as idle. Mirrors the iOS "ensure count-up ring reads active" fix.
        val displayProgress = if (isRunning && progress < 0.02f) 0.02f else progress

        // When morphProgress > 0, the ring is a rounded rectangle inscribed in the canvas.
        // cornerRadius interpolates from diameter/2 (a perfect circle inscribed in the canvas)
        // down to ~0.22·diameter (a perceptible squircle). Going below the inscribed-circle
        // radius is what produces the visible corner flattening of the squircle.
        if (actualMorph > 0.01f) {
            // Linear interpolation: start + (end - start) * amount.
            // circleRadius (inscribed circle) → squircleRadius as actualMorph goes 0 → 1.
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

            // Track (full ring).
            drawPath(
                path = ringPath,
                color = trackColor,
                style = Stroke(width = strokeWidthPx, cap = StrokeCap.Round),
            )

            // Dashed overlay for count-up idle — follows the same morphed path.
            if (showDashedOverlay) {
                drawPath(
                    path = ringPath,
                    color = ringColor.copy(alpha = 0.30f),
                    style = Stroke(
                        width = strokeWidthPx,
                        cap = StrokeCap.Butt,
                        pathEffect = PathEffect.dashPathEffect(floatArrayOf(dashPx, gapPx), 0f)
                    ),
                )
            }

            // Subtle pulse glow behind the progress arc.
            if (isRunning && displayProgress > 0f && displayProgress < 1f) {
                drawPath(
                    path = ringPath,
                    color = ringColor.copy(alpha = pulseAlpha * 0.4f),
                    style = Stroke(width = strokeWidthPx * 1.4f, cap = StrokeCap.Round),
                )
            }

            // Progress arc: trace only the fraction of the ring path corresponding to displayProgress.
            if (displayProgress > 0f) {
                val fraction = displayProgress.coerceIn(0f, 1f)
                val progressPath = Path()
                val measure = PathMeasure().apply { setPath(ringPath, false) }
                
                // Align squircle origin with circle (12 o'clock) (#510).
                // addRoundRect starts at the top-left corner's start (x+radius, y).
                // 12 o'clock is at (x+width/2, y).
                val startOffset = (arcSize.width / 2f) - cornerRadius
                measure.getSegment(startOffset, startOffset + measure.length * fraction, progressPath, true)
                drawPath(
                    path = progressPath,
                    color = ringColor,
                    style = Stroke(width = strokeWidthPx, cap = StrokeCap.Round),
                )
            }
        } else {
            // Pure-circle path — the original drawArc logic, unchanged (Flow/Chrono/idle/reduce-motion).
            // Track (full circle, subtle)
            drawArc(
                color = trackColor,
                startAngle = -90f,
                sweepAngle = 360f,
                useCenter = false,
                topLeft = topLeft,
                size = arcSize,
                style = Stroke(width = strokeWidthPx, cap = StrokeCap.Round),
            )

            // Dashed track overlay for count-up idle mode
            if (showDashedOverlay) {
                drawArc(
                    color = ringColor.copy(alpha = 0.30f),
                    startAngle = -90f,
                    sweepAngle = 360f,
                    useCenter = false,
                    topLeft = topLeft,
                    size = arcSize,
                    style = Stroke(
                        width = strokeWidthPx,
                        cap = StrokeCap.Butt,
                        pathEffect = PathEffect.dashPathEffect(floatArrayOf(dashPx, gapPx), 0f)
                    ),
                )
            }

            // Subtle pulse glow behind the progress arc
            if (isRunning && displayProgress > 0f && displayProgress < 1f) {
                drawArc(
                    color = ringColor.copy(alpha = pulseAlpha * 0.4f),
                    startAngle = -90f,
                    sweepAngle = 360f * displayProgress.coerceIn(0f, 1f),
                    useCenter = false,
                    topLeft = topLeft,
                    size = arcSize,
                    style = Stroke(width = strokeWidthPx * 1.4f, cap = StrokeCap.Round),
                )
            }

            // Progress arc
            if (displayProgress > 0f) {
                drawArc(
                    color = ringColor,
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

// ─────────────────────────── Previews (Sprint 6 #492) ─────────────────────

@Preview(showBackground = true, name = "morphProgress = 0f (circle)")
@Composable
private fun CircularTimerRingPreviewCircle() {
    PepinilloTheme {
        CanvasPreviewHost(morphProgress = 0f, progress = 0.9f)
    }
}

@Preview(showBackground = true, name = "morphProgress = 0.5f")
@Composable
private fun CircularTimerRingPreviewHalf() {
    PepinilloTheme {
        CanvasPreviewHost(morphProgress = 0.5f, progress = 0.9f)
    }
}

@Preview(showBackground = true, name = "morphProgress = 1f (squircle)")
@Composable
private fun CircularTimerRingPreviewSquircle() {
    PepinilloTheme {
        CanvasPreviewHost(morphProgress = 1f, progress = 0.9f)
    }
}

/** Shared host so the three previews differ only by morphProgress — visualises the interpolation. */
@Composable
private fun CanvasPreviewHost(morphProgress: Float, progress: Float) {
    CircularTimerRing(
        progress = progress,
        ringColor = Color(0xFF6750A4),
        trackColor = Color(0xFFCAC4D0),
        strokeWidth = 13.dp,
        modifier = Modifier
            .size(200.dp),
        isRunning = true,
        morphProgress = morphProgress,
    )
}
