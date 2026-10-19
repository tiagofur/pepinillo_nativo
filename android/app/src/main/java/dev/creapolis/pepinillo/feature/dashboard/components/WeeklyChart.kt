package dev.creapolis.pepinillo.feature.dashboard.components

import dev.creapolis.pepinillo.R
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.res.stringResource
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.unit.dp
import com.patrykandpatrick.vico.compose.cartesian.CartesianChartHost
import com.patrykandpatrick.vico.compose.cartesian.axis.rememberBottom
import com.patrykandpatrick.vico.compose.cartesian.axis.rememberStart
import com.patrykandpatrick.vico.compose.cartesian.layer.rememberColumnCartesianLayer
import com.patrykandpatrick.vico.compose.cartesian.marker.rememberDefaultCartesianMarker
import com.patrykandpatrick.vico.compose.cartesian.rememberCartesianChart
import com.patrykandpatrick.vico.compose.cartesian.rememberVicoZoomState
import com.patrykandpatrick.vico.compose.common.component.rememberLineComponent
import com.patrykandpatrick.vico.compose.common.component.rememberShapeComponent
import com.patrykandpatrick.vico.compose.common.component.rememberTextComponent
import com.patrykandpatrick.vico.compose.common.shape.dashedShape
import com.patrykandpatrick.vico.compose.common.shape.rounded
import com.patrykandpatrick.vico.core.cartesian.axis.HorizontalAxis
import com.patrykandpatrick.vico.core.cartesian.axis.VerticalAxis
import com.patrykandpatrick.vico.core.cartesian.data.CartesianChartModelProducer
import com.patrykandpatrick.vico.core.cartesian.data.CartesianValueFormatter
import com.patrykandpatrick.vico.core.cartesian.data.ColumnCartesianLayerModel
import com.patrykandpatrick.vico.core.cartesian.decoration.HorizontalLine
import com.patrykandpatrick.vico.core.cartesian.layer.ColumnCartesianLayer
import com.patrykandpatrick.vico.core.cartesian.marker.DefaultCartesianMarker
import com.patrykandpatrick.vico.core.common.Fill
import com.patrykandpatrick.vico.core.common.shape.CorneredShape
import dev.creapolis.pepinillo.feature.dashboard.model.DailyFocus

// ---------------------------------------------------------------------------
// Pure functions — testable without Compose
// ---------------------------------------------------------------------------

/** Computes the average minutes from a list of DailyFocus data. */
fun computeAverageMinutes(data: List<DailyFocus>): Double {
    if (data.isEmpty()) return 0.0
    return data.sumOf { it.minutes }.toDouble() / data.size
}

/** Simple data class for chart entry data mapping. */
data class ChartEntry(val x: Float, val y: Float)

/** Maps DailyFocus data to chart entries with x=index, y=minutes. */
fun mapToChartEntries(data: List<DailyFocus>): List<ChartEntry> {
    return data.mapIndexed { index, daily ->
        ChartEntry(index.toFloat(), daily.minutes.toFloat())
    }
}

/**
 * Formats a localized chart preview line like "1h 20m in 5 sessions" from pre-localized parts
 * (super-review P2k): [durationText] and [sessionWord] come from resources/plurals and
 * [pattern] is a `chart_preview_*` pattern such as "%1$s in %2$d %3$s".
 */
fun formatPreviewLine(durationText: String, sessions: Int, sessionWord: String, pattern: String): String =
    String.format(pattern, durationText, sessions, sessionWord)

// ---------------------------------------------------------------------------
// FocusChart composable — Vico-based implementation
// ---------------------------------------------------------------------------

@Composable
fun FocusChart(
    data: List<DailyFocus>,
    accentColor: Color,
    modifier: Modifier = Modifier,
) {
    if (data.isEmpty()) {
        EmptyChartPlaceholder(modifier = modifier)
        return
    }

    val modelProducer = remember { CartesianChartModelProducer() }
    val avgMinutes = computeAverageMinutes(data)
    val dayLabels = remember(data) { data.map { it.dayLabel } }
    val accentArgb = accentColor.toArgb()
    val avgArgb = accentColor.copy(alpha = 0.5f).toArgb()

    // Populate chart data
    LaunchedEffect(data) {
        val yValues = data.map { it.minutes }
        modelProducer.runTransaction {
            add(ColumnCartesianLayerModel.partial { series(yValues) })
        }
    }

    // Column layer with rounded corners and accent color
    val columnLayer = rememberColumnCartesianLayer(
        columnProvider = ColumnCartesianLayer.ColumnProvider.series(
            listOf(
                rememberLineComponent(
                    fill = Fill(accentArgb),
                    thickness = 16.dp,
                    shape = CorneredShape.rounded(4.dp),
                ),
            ),
        ),
    )

    // Y-axis with localized minute suffix (super-review P2k: "45m" was hardcoded English).
    val minutesPattern = stringResource(R.string.chart_minutes_compact)
    val yFormatter = remember(minutesPattern) {
        CartesianValueFormatter { _, value, _ -> String.format(minutesPattern, value.toInt()) }
    }
    val startAxis = VerticalAxis.rememberStart(
        valueFormatter = yFormatter,
        itemPlacer = VerticalAxis.ItemPlacer.count({ 5 }),
    )

    // X-axis with day labels
    val bottomAxis = HorizontalAxis.rememberBottom(
        itemPlacer = HorizontalAxis.ItemPlacer.segmented(),
        valueFormatter = CartesianValueFormatter { _, x, _ ->
            val index = x.toInt()
            if (index in dayLabels.indices) dayLabels[index] else ""
        },
    )

    // Marker tooltip showing "{minutes}m" on bar tap
    val markerLabel = rememberTextComponent(
        background = rememberShapeComponent(
            fill = Fill(accentArgb),
            shape = CorneredShape.rounded(4.dp),
        ),
    )
    val marker = rememberDefaultCartesianMarker(
        label = markerLabel,
        valueFormatter = DefaultCartesianMarker.ValueFormatter { _, targets ->
            val x = targets.firstOrNull()?.x ?: return@ValueFormatter ""
            val index = x.toInt()
            if (index in data.indices) String.format(minutesPattern, data[index].minutes) else ""
        },
    )

    // Threshold line at average (dashed); label is the localized "avg" string (P2k).
    val avgLineShape = dashedShape(
        shape = CorneredShape.rounded(0.dp),
        dashLength = 5.dp,
        gapLength = 5.dp,
    )
    val avgLabelComponent = rememberTextComponent(
        color = accentColor.copy(alpha = 0.7f),
    )
    val avgLabel = stringResource(R.string.chart_avg)
    val avgLine = remember(avgMinutes, avgLabel) {
        HorizontalLine(
            y = { avgMinutes },
            line = com.patrykandpatrick.vico.core.common.component.LineComponent(
                Fill(avgArgb),
                1f,
                avgLineShape,
            ),
            labelComponent = avgLabelComponent,
            label = { avgLabel },
        )
    }

    CartesianChartHost(
        chart = rememberCartesianChart(
            columnLayer,
            startAxis = startAxis,
            bottomAxis = bottomAxis,
            marker = marker,
            decorations = listOf(avgLine),
        ),
        modelProducer = modelProducer,
        modifier = modifier
            .fillMaxWidth()
            .height(200.dp),
        zoomState = rememberVicoZoomState(zoomEnabled = false),
    )
}

@Composable
private fun EmptyChartPlaceholder(modifier: Modifier = Modifier) {
    Text(
        text = stringResource(R.string.chart_no_data),
        style = MaterialTheme.typography.bodyMedium,
        color = MaterialTheme.colorScheme.onSurfaceVariant,
        modifier = modifier
            .fillMaxWidth()
            .padding(vertical = 32.dp),
    )
}
