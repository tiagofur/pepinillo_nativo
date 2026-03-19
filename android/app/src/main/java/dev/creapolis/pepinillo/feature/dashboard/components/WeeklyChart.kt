package dev.creapolis.pepinillo.feature.dashboard.components

import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
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
    onBarSelected: ((Int?) -> Unit)? = null,
) {
    val maxMinutes = (data.maxOfOrNull { it.minutes } ?: 1).coerceAtLeast(1)
    val trackColor = accentColor.copy(alpha = 0.12f)

    var selectedIndex by remember { mutableStateOf<Int?>(null) }

    val scrollable = data.size > 12

    Column(modifier = modifier) {
        // Detail banner shown when a bar is selected
        if (selectedIndex != null) {
            val selected = data.getOrNull(selectedIndex!!)
            if (selected != null) {
                SelectedDayDetail(
                    dayLabel = selected.dayLabel,
                    minutes = selected.minutes,
                    accentColor = accentColor,
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(bottom = 8.dp),
                )
            }
        }

        val content: @Composable () -> Unit = {
            Row(
                modifier = if (scrollable) Modifier else Modifier.fillMaxWidth(),
                horizontalArrangement = if (scrollable) Arrangement.spacedBy(4.dp) else Arrangement.SpaceEvenly,
                verticalAlignment = Alignment.Bottom,
            ) {
                data.forEachIndexed { index, day ->
                    val fraction = day.minutes.toFloat() / maxMinutes
                    val showLabel = showAllLabels || (data.size > 12 && index % 5 == 0)
                    val isSelected = selectedIndex == index
                    val hasSelection = selectedIndex != null

                    // Dim unselected bars when a selection is active
                    val targetBarColor by animateColorAsState(
                        targetValue = when {
                            !hasSelection -> accentColor
                            isSelected -> accentColor
                            else -> accentColor.copy(alpha = 0.35f)
                        },
                        animationSpec = tween(durationMillis = 200),
                        label = "barColor",
                    )

                    val targetTrackColor by animateColorAsState(
                        targetValue = when {
                            isSelected -> accentColor.copy(alpha = 0.22f)
                            else -> trackColor
                        },
                        animationSpec = tween(durationMillis = 200),
                        label = "trackColor",
                    )

                    val barScale by animateFloatAsState(
                        targetValue = if (isSelected) 1.06f else 1f,
                        animationSpec = tween(durationMillis = 200),
                        label = "barScale",
                    )

                    Column(
                        horizontalAlignment = Alignment.CenterHorizontally,
                        verticalArrangement = Arrangement.spacedBy(4.dp),
                        modifier = Modifier.clickable(
                            interactionSource = remember { MutableInteractionSource() },
                            indication = null,
                        ) {
                            val newIndex = if (selectedIndex == index) null else index
                            selectedIndex = newIndex
                            onBarSelected?.invoke(newIndex)
                        },
                    ) {
                        // Tooltip above the selected bar
                        if (isSelected) {
                            Surface(
                                color = accentColor,
                                shape = RoundedCornerShape(6.dp),
                                tonalElevation = 2.dp,
                                shadowElevation = 2.dp,
                            ) {
                                Text(
                                    text = "${day.minutes}m",
                                    style = MaterialTheme.typography.labelSmall,
                                    color = Color.White,
                                    modifier = Modifier.padding(horizontal = 6.dp, vertical = 2.dp),
                                )
                            }
                        } else {
                            // Reserve space so layout doesn't jump
                            Box(modifier = Modifier.height(0.dp))
                        }

                        Canvas(
                            modifier = Modifier
                                .width(barWidth * barScale)
                                .height(chartHeight),
                        ) {
                            val bw = size.width
                            val bh = size.height
                            val radius = CornerRadius(bw / 2, bw / 2)

                            drawRoundRect(
                                color = targetTrackColor,
                                topLeft = Offset.Zero,
                                size = Size(bw, bh),
                                cornerRadius = radius,
                            )

                            if (fraction > 0f) {
                                val filledHeight = bh * fraction
                                drawRoundRect(
                                    color = targetBarColor,
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
                                color = if (isSelected) {
                                    accentColor
                                } else {
                                    MaterialTheme.colorScheme.onSurfaceVariant
                                },
                            )
                        }
                    }
                }
            }
        }

        if (scrollable) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .horizontalScroll(rememberScrollState()),
            ) {
                content()
            }
        } else {
            content()
        }
    }
}

@Composable
private fun SelectedDayDetail(
    dayLabel: String,
    minutes: Int,
    accentColor: Color,
    modifier: Modifier = Modifier,
) {
    Row(
        modifier = modifier,
        horizontalArrangement = Arrangement.Center,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            text = dayLabel,
            style = MaterialTheme.typography.titleSmall,
            color = accentColor,
        )
        Text(
            text = "  \u2022  ",
            style = MaterialTheme.typography.titleSmall,
            color = accentColor.copy(alpha = 0.5f),
        )
        Text(
            text = "${minutes}min focused",
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurface,
        )
    }
}
