package dev.creapolis.pepinillo.feature.focus.components

import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp

@Composable
fun CircularTimerRing(
    progress: Float,
    ringColor: Color,
    trackColor: Color,
    strokeWidth: Dp = 12.dp,
    modifier: Modifier = Modifier,
    isRunning: Boolean = false,
) {
    val strokeWidthPx = with(LocalDensity.current) { strokeWidth.toPx() }
    
    val infiniteTransition = rememberInfiniteTransition(label = "ringPulse")
    val pulseAlpha by infiniteTransition.animateFloat(
        initialValue = 0.3f,
        targetValue = 0.7f,
        animationSpec = infiniteRepeatable(
            animation = tween(1500, easing = LinearEasing),
            repeatMode = RepeatMode.Reverse
        ),
        label = "pulseAlpha"
    )

    Canvas(modifier = modifier) {
        val diameter = size.minDimension
        val inset = strokeWidthPx / 2f
        val arcSize = Size(diameter - strokeWidthPx, diameter - strokeWidthPx)
        val topLeft = Offset(inset, inset)

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
        
        // Subtle pulse glow behind the progress arc
        if (isRunning && progress > 0f && progress < 1f) {
            drawArc(
                color = ringColor.copy(alpha = pulseAlpha * 0.4f),
                startAngle = -90f,
                sweepAngle = 360f * progress.coerceIn(0f, 1f),
                useCenter = false,
                topLeft = topLeft,
                size = arcSize,
                style = Stroke(width = strokeWidthPx * 1.4f, cap = StrokeCap.Round),
            )
        }

        // Progress arc
        if (progress > 0f) {
            drawArc(
                color = ringColor,
                startAngle = -90f,
                sweepAngle = 360f * progress.coerceIn(0f, 1f),
                useCenter = false,
                topLeft = topLeft,
                size = arcSize,
                style = Stroke(width = strokeWidthPx, cap = StrokeCap.Round),
            )
        }
    }
}
