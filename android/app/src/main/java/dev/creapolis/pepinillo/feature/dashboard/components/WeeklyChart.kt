package dev.creapolis.pepinillo.feature.dashboard.components

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.width
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import dev.creapolis.pepinillo.feature.dashboard.model.DailyFocus

@Composable
fun WeeklyChart(
    data: List<DailyFocus>,
    accentColor: Color,
    modifier: Modifier = Modifier,
) {
    val maxMinutes = (data.maxOfOrNull { it.minutes } ?: 1).coerceAtLeast(1)
    val trackColor = accentColor.copy(alpha = 0.12f)

    Row(
        modifier = modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceEvenly,
        verticalAlignment = Alignment.Bottom,
    ) {
        data.forEach { day ->
            val fraction = day.minutes.toFloat() / maxMinutes

            Column(
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(6.dp),
            ) {
                // Bar
                Canvas(
                    modifier = Modifier
                        .width(28.dp)
                        .height(120.dp),
                ) {
                    val barWidth = size.width
                    val barHeight = size.height
                    val radius = CornerRadius(barWidth / 2, barWidth / 2)

                    // Track (full height, subtle)
                    drawRoundRect(
                        color = trackColor,
                        topLeft = Offset.Zero,
                        size = Size(barWidth, barHeight),
                        cornerRadius = radius,
                    )

                    // Filled portion
                    if (fraction > 0f) {
                        val filledHeight = barHeight * fraction
                        drawRoundRect(
                            color = accentColor,
                            topLeft = Offset(0f, barHeight - filledHeight),
                            size = Size(barWidth, filledHeight),
                            cornerRadius = radius,
                        )
                    }
                }

                // Day label
                Text(
                    text = day.dayLabel,
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        }
    }
}
