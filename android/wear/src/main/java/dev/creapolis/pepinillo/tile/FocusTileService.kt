package dev.creapolis.pepinillo.tile

import androidx.concurrent.futures.CallbackToFutureAdapter
import androidx.wear.protolayout.ActionBuilders
import androidx.wear.protolayout.ColorBuilders
import androidx.wear.protolayout.DimensionBuilders
import androidx.wear.protolayout.LayoutElementBuilders
import androidx.wear.protolayout.ModifiersBuilders
import androidx.wear.protolayout.TimelineBuilders
import androidx.wear.protolayout.LayoutElementBuilders.ARC_ANCHOR_START
import androidx.wear.protolayout.LayoutElementBuilders.FONT_WEIGHT_BOLD
import androidx.wear.protolayout.LayoutElementBuilders.HORIZONTAL_ALIGN_CENTER
import androidx.wear.protolayout.LayoutElementBuilders.VERTICAL_ALIGN_CENTER
import androidx.wear.tiles.RequestBuilders
import androidx.wear.tiles.ResourceBuilders
import androidx.wear.tiles.TileBuilders
import androidx.wear.tiles.TileService
import com.google.common.util.concurrent.ListenableFuture
import dev.creapolis.pepinillo.data.WearSnapshotStore
import dev.creapolis.pepinillo.data.WearTimerState
import dev.creapolis.pepinillo.data.WearThemeColors

class FocusTileService : TileService() {

    companion object {
        private const val RESOURCES_VERSION = "1"
        private const val REFRESH_IDLE_MS = 60_000L
        private const val REFRESH_ACTIVE_MS = 1_000L
    }

    override fun onTileRequest(
        requestParams: RequestBuilders.TileRequest,
    ): ListenableFuture<TileBuilders.Tile> =
        CallbackToFutureAdapter.getFuture<TileBuilders.Tile> { completer ->
            completer.set(buildTile())
            "FocusTileService.onTileRequest"
        }

    override fun onResourcesRequest(
        requestParams: RequestBuilders.ResourcesRequest,
    ): ListenableFuture<ResourceBuilders.Resources> =
        CallbackToFutureAdapter.getFuture<ResourceBuilders.Resources> { completer ->
            completer.set(
                ResourceBuilders.Resources.Builder()
                    .setVersion(RESOURCES_VERSION)
                    .build(),
            )
            "FocusTileService.onResourcesRequest"
        }

    private fun buildTile(): TileBuilders.Tile {
        val state = WearSnapshotStore.readTimerState(this)
        val stats = WearSnapshotStore.readStats(this)
        val colors = WearSnapshotStore.readThemeColors(this)
        val isPro = WearSnapshotStore.readIsPro(this)

        // When running, recalculate displayTime and progress from the end epoch
        val liveState = if (state.status == "Running" && state.phaseEndEpochMs > 0 && state.totalDurationMs > 0) {
            val now = System.currentTimeMillis()
            val remainingMs = (state.phaseEndEpochMs - now).coerceAtLeast(0L)
            val totalSec = (remainingMs + 999) / 1000 // ceiling so we don't show 0:00 prematurely
            val mins = totalSec / 60
            val secs = totalSec % 60
            val liveDisplayTime = "%02d:%02d".format(mins, secs)
            val elapsedMs = (state.totalDurationMs - remainingMs).coerceAtLeast(0L)
            val liveProgress = if (state.totalDurationMs > 0) {
                (elapsedMs.toFloat() / state.totalDurationMs.toFloat()).coerceIn(0f, 1f)
            } else {
                state.progress
            }
            state.copy(displayTime = liveDisplayTime, progress = liveProgress)
        } else {
            state
        }

        val isActive = liveState.status == "Running"
        val refreshMs = if (isActive) REFRESH_ACTIVE_MS else REFRESH_IDLE_MS

        val root = if (!isPro) {
            buildLockedLayout(modeColor(liveState.mode, colors).toInt())
        } else {
            when (liveState.status) {
                "Running" -> buildRunningLayout(liveState, colors)
                "Paused" -> buildPausedLayout(liveState, colors)
                else -> buildIdleLayout(liveState, stats, colors)
            }
        }

        return TileBuilders.Tile.Builder()
            .setResourcesVersion(RESOURCES_VERSION)
            .setFreshnessIntervalMillis(refreshMs)
            .setTileTimeline(
                TimelineBuilders.Timeline.Builder()
                    .addTimelineEntry(
                        TimelineBuilders.TimelineEntry.Builder()
                            .setLayout(
                                LayoutElementBuilders.Layout.Builder()
                                    .setRoot(root)
                                    .build(),
                            )
                            .build(),
                    )
                    .build(),
            )
            .build()
    }

    private fun modeColor(mode: String, colors: WearThemeColors): Long = when (mode) {
        "Pomodoro" -> colors.pomodoroColor
        "Flowtime" -> colors.flowtimeColor
        "TimeBlock" -> colors.timeBlockColor
        "Stopwatch" -> colors.stopwatchColor
        else -> 0xFFE84D3D
    }

    private fun modeEmoji(mode: String): String = when (mode) {
        "Pomodoro" -> "\uD83C\uDF45"
        "Flowtime" -> "\uD83C\uDF0A"
        "TimeBlock" -> "\u23F3"
        "Stopwatch" -> "\u23F1\uFE0F"
        else -> "\uD83C\uDF45"
    }

    private fun launchAction(): ActionBuilders.LaunchAction =
        ActionBuilders.LaunchAction.Builder()
            .setAndroidActivity(
                ActionBuilders.AndroidActivity.Builder()
                    .setPackageName(packageName)
                    .setClassName("dev.creapolis.pepinillo.presentation.MainActivity")
                    .build(),
            ).build()

    private fun clickableModifiers(): ModifiersBuilders.Modifiers =
        ModifiersBuilders.Modifiers.Builder()
            .setClickable(
                ModifiersBuilders.Clickable.Builder()
                    .setId("launch_app")
                    .setOnClick(launchAction())
                    .build(),
            ).build()

    private fun text(value: String, sizeSp: Float, bold: Boolean = false, color: Int? = null): LayoutElementBuilders.Text {
        val fontBuilder = LayoutElementBuilders.FontStyle.Builder()
            .setSize(DimensionBuilders.SpProp.Builder().setValue(sizeSp).build())
        if (bold) fontBuilder.setWeight(FONT_WEIGHT_BOLD)
        if (color != null) fontBuilder.setColor(ColorBuilders.argb(color))
        return LayoutElementBuilders.Text.Builder()
            .setText(value)
            .setFontStyle(fontBuilder.build())
            .build()
    }

    private fun spacer(heightDp: Float): LayoutElementBuilders.Spacer =
        LayoutElementBuilders.Spacer.Builder()
            .setHeight(DimensionBuilders.dp(heightDp))
            .setWidth(DimensionBuilders.dp(0f))
            .build()

    private fun buildIdleLayout(
        state: WearTimerState,
        stats: dev.creapolis.pepinillo.data.WearStatsState,
        colors: WearThemeColors,
    ): LayoutElementBuilders.LayoutElement {
        val emoji = modeEmoji(state.mode)
        val statsText = "${stats.totalMinutes} min \u00b7 \uD83D\uDD25 ${stats.streak}d"

        return LayoutElementBuilders.Box.Builder()
            .setWidth(DimensionBuilders.expand())
            .setHeight(DimensionBuilders.expand())
            .setVerticalAlignment(VERTICAL_ALIGN_CENTER)
            .setHorizontalAlignment(HORIZONTAL_ALIGN_CENTER)
            .setModifiers(clickableModifiers())
            .addContent(
                LayoutElementBuilders.Column.Builder()
                    .setHorizontalAlignment(HORIZONTAL_ALIGN_CENTER)
                    .addContent(text("$emoji Pepinillo", 20f, bold = true))
                    .addContent(spacer(6f))
                    .addContent(text(statsText, 14f, color = 0xFFAAAAAA.toInt()))
                    .addContent(spacer(8f))
                    .addContent(text(getString(dev.creapolis.pepinillo.R.string.tile_tap_to_focus), 14f, color = modeColor(state.mode, colors).toInt()))
                    .build(),
            )
            .build()
    }

    private fun buildLockedLayout(
        accentColor: Int,
    ): LayoutElementBuilders.LayoutElement =
        LayoutElementBuilders.Box.Builder()
            .setWidth(DimensionBuilders.expand())
            .setHeight(DimensionBuilders.expand())
            .setVerticalAlignment(VERTICAL_ALIGN_CENTER)
            .setHorizontalAlignment(HORIZONTAL_ALIGN_CENTER)
            .setModifiers(clickableModifiers())
            .addContent(
                LayoutElementBuilders.Column.Builder()
                    .setHorizontalAlignment(HORIZONTAL_ALIGN_CENTER)
                    .addContent(text("Pepinillo+", 20f, bold = true, color = accentColor))
                    .addContent(spacer(6f))
                    .addContent(text(getString(dev.creapolis.pepinillo.R.string.tile_locked_focus), 14f, color = 0xFFCCCCCC.toInt()))
                    .addContent(spacer(6f))
                    .addContent(text(getString(dev.creapolis.pepinillo.R.string.tile_upgrade_app), 13f, color = 0xFF888888.toInt()))
                    .build(),
            )
            .build()

    private fun buildRunningLayout(
        state: WearTimerState,
        colors: WearThemeColors,
    ): LayoutElementBuilders.LayoutElement {
        val color = modeColor(state.mode, colors)
        val sessionLabel = "${state.phaseLabel} \u00b7 ${state.completedSessions + 1}/4"

        return LayoutElementBuilders.Box.Builder()
            .setWidth(DimensionBuilders.expand())
            .setHeight(DimensionBuilders.expand())
            .setVerticalAlignment(VERTICAL_ALIGN_CENTER)
            .setHorizontalAlignment(HORIZONTAL_ALIGN_CENTER)
            .setModifiers(clickableModifiers())
            .addContent(progressArc(state.progress, color))
            .addContent(
                LayoutElementBuilders.Column.Builder()
                    .setHorizontalAlignment(HORIZONTAL_ALIGN_CENTER)
                    .addContent(text(state.displayTime, 28f, bold = true))
                    .addContent(spacer(4f))
                    .addContent(text(sessionLabel, 14f, color = 0xFFAAAAAA.toInt()))
                    .apply {
                        val taskName = state.linkedTaskName
                        if (!taskName.isNullOrEmpty()) {
                            addContent(spacer(4f))
                            addContent(text(taskName.take(20), 14f, color = 0xFF888888.toInt()))
                        }
                    }
                    .build(),
            )
            .build()
    }

    private fun buildPausedLayout(
        state: WearTimerState,
        colors: WearThemeColors,
    ): LayoutElementBuilders.LayoutElement {
        val color = modeColor(state.mode, colors)
        val dimmedColor = (color and 0x00FFFFFFL) or 0x80000000L

        return LayoutElementBuilders.Box.Builder()
            .setWidth(DimensionBuilders.expand())
            .setHeight(DimensionBuilders.expand())
            .setVerticalAlignment(VERTICAL_ALIGN_CENTER)
            .setHorizontalAlignment(HORIZONTAL_ALIGN_CENTER)
            .setModifiers(clickableModifiers())
            .addContent(progressArc(state.progress, dimmedColor))
            .addContent(
                LayoutElementBuilders.Column.Builder()
                    .setHorizontalAlignment(HORIZONTAL_ALIGN_CENTER)
                    .addContent(text(state.displayTime, 28f, bold = true))
                    .addContent(spacer(4f))
                    .addContent(text("\u23F8 " + getString(dev.creapolis.pepinillo.R.string.tile_paused), 14f, color = 0xFFAAAAAA.toInt()))
                    .build(),
            )
            .build()
    }

    private fun progressArc(progress: Float, color: Long): LayoutElementBuilders.Arc =
        LayoutElementBuilders.Arc.Builder()
            .setAnchorAngle(DimensionBuilders.DegreesProp.Builder(0f).build())
            .setAnchorType(ARC_ANCHOR_START)
            .addContent(
                LayoutElementBuilders.ArcLine.Builder()
                    .setLength(DimensionBuilders.DegreesProp.Builder(progress * 360f).build())
                    .setThickness(DimensionBuilders.dp(8f))
                    .setColor(ColorBuilders.argb(color.toInt()))
                    .build(),
            )
            .build()
}
