package dev.creapolis.pepinillo.ui.components

import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import dev.creapolis.pepinillo.ui.theme.MotionScheme
import dev.creapolis.pepinillo.ui.theme.PepinilloShapeTokens
import dev.creapolis.pepinillo.ui.theme.isReduceMotionEnabled

@Composable
fun shimmerBrush(): Brush {
    val colorLow = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.4f)
    val colorHigh = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.8f)

    // When reduce-motion is enabled, return a static gradient instead of animating (#401).
    if (isReduceMotionEnabled()) {
        return SolidColor(colorHigh)
    }

    val transition = rememberInfiniteTransition(label = "shimmer")
    val translateAnim by transition.animateFloat(
        initialValue = 0f,
        targetValue = 1000f,
        animationSpec = infiniteRepeatable(
            animation = tween(durationMillis = MotionScheme.DURATION_SHIMMER, easing = FastOutSlowInEasing),
            repeatMode = RepeatMode.Restart,
        ),
        label = "shimmerTranslate",
    )

    return Brush.linearGradient(
        colors = listOf(colorLow, colorHigh, colorLow),
        start = Offset(translateAnim - 200f, 0f),
        end = Offset(translateAnim + 200f, 0f),
    )
}

@Composable
fun ShimmerBox(
    modifier: Modifier = Modifier,
    width: Dp? = null,
    height: Dp = 16.dp,
    shape: Shape = PepinilloShapeTokens.badge,
) {
    val brush = shimmerBrush()
    Box(
        modifier = modifier
            .then(if (width != null) Modifier.width(width) else Modifier)
            .height(height)
            .clip(shape)
            .background(brush),
    )
}

/** A single skeleton task row: circle + two rectangles stacked. */
@Composable
fun TaskSkeletonItem(modifier: Modifier = Modifier) {
    val brush = shimmerBrush()
    Row(
        modifier = modifier
            .fillMaxWidth()
            .height(56.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        // Checkbox circle placeholder
        Box(
            modifier = Modifier
                .size(24.dp)
                .clip(CircleShape)
                .background(brush),
        )
        Spacer(modifier = Modifier.width(16.dp))
        Column(
            verticalArrangement = Arrangement.Center,
        ) {
            // Title rectangle
            Box(
                modifier = Modifier
                    .fillMaxWidth(0.6f)
                    .height(16.dp)
                    .clip(PepinilloShapeTokens.badge)
                    .background(brush),
            )
            Spacer(modifier = Modifier.height(6.dp))
            // Metadata rectangle
            Box(
                modifier = Modifier
                    .fillMaxWidth(0.4f)
                    .height(12.dp)
                    .clip(MaterialTheme.shapes.extraSmall)
                    .background(brush),
            )
        }
    }
}

/** 5 skeleton task items for the tasks loading state. */
@Composable
fun TasksListSkeleton(modifier: Modifier = Modifier) {
    Column(
        modifier = modifier,
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        repeat(5) {
            TaskSkeletonItem()
        }
    }
}

/** Dashboard loading skeleton: 3 summary cards + chart + 2 pattern cards. */
@Composable
fun DashboardSkeleton(modifier: Modifier = Modifier) {
    val brush = shimmerBrush()

    Column(modifier = modifier) {
        // 3 summary card placeholders
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            repeat(3) {
                Box(
                    modifier = Modifier
                        .weight(1f)
                        .height(96.dp)
                        .clip(PepinilloShapeTokens.card)
                        .background(brush),
                )
            }
        }

        Spacer(modifier = Modifier.height(28.dp))

        // Chart placeholder
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(120.dp)
                .clip(MaterialTheme.shapes.large)
                .background(brush),
        )

        Spacer(modifier = Modifier.height(28.dp))

        // 2 pattern card placeholders
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            repeat(2) {
                Box(
                    modifier = Modifier
                        .weight(1f)
                        .height(80.dp)
                        .clip(PepinilloShapeTokens.card)
                        .background(brush),
                )
            }
        }
    }
}
