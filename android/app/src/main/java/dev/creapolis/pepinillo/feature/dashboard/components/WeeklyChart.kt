package dev.creapolis.pepinillo.feature.dashboard.components

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.rememberScrollState
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import dev.creapolis.pepinillo.feature.dashboard.model.DailyFocus

@Composable
fun FocusChart(
    data: List<DailyFocus>,
    accentColor: Color,
    modifier: Modifier = Modifier,
    barWidth: Dp = when {
        data.size <= 7 -> 28.dp
        data.size <= 12 -> 24.dp
        else -> 8.dp
    },
    chartHeight: Dp = when {
        data.size > 12 -> 100.dp
        else -> 120.dp
    },
    showAllLabels: Boolean = data.size <= 12,
) {
    val maxMinutes = (data.maxOfOrNull { it.minutes } ?: 1).coerceAtLeast(1)
    val trackColor = accentColor.copy(alpha = 0.12f)

    val scrollable = data.size > 12
    val content: @Composable () -> Unit = {
        Row(
            modifier = if (scrollable) Modifier else Modifier.fillMaxWidth(),
            horizontalArrangement = if (scrollable) Arrangement.spacedBy(4.dp) else Arrangement.SpaceEvenly,
            verticalAlignment = Alignment.Bottom,
        ) {
            data.forEachIndexed { index, day ->
                val fraction = day.minutes.toFloat() / maxMinutes
                val showLabel = showAllLabels || (data.size > 12 && index % 5 == 0)

                Column(
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(6.dp),
                ) {
                    Canvas(
                        modifier = Modifier
                            .width(barWidth)
                            .height(chartHeight),
                    ) {
                        val bw = size.width
                        val bh = size.height
                        val radius = CornerRadius(bw / 2, bw / 2)

                        drawRoundRect(
                            color = trackColor,
                            topLeft = Offset.Zero,
                            size = Size(bw, bh),
                            cornerRadius = radius,
                        )

                        if (fraction > 0f) {
                            val filledHeight = bh * fraction
                            drawRoundRect(
                                color = accentColor,
                                topLeft = Offset(0f, bh - filledHeight),
                                size = Size(bw, filledHeight),
                                cornerRadius = radius,
                            )
                        }
                    }

                    if (showLabel) {
                        Text(
                            text = day.dayLabel,
                            style = MaterialTheme.typography.labelSmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                }
            }
        }
    }

    if (scrollable) {
        Row(
            modifier = modifier
                .fillMaxWidth()
                .horizontalScroll(rememberScrollState()),
        ) {
            content()
        }
    } else {
        content()
    }
}
