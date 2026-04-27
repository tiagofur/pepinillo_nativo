package dev.creapolis.pepinillo.tile

import androidx.concurrent.futures.CallbackToFutureAdapter
import androidx.wear.protolayout.ActionBuilders
import androidx.wear.protolayout.ColorBuilders
import androidx.wear.protolayout.DimensionBuilders
import androidx.wear.protolayout.LayoutElementBuilders
import androidx.wear.protolayout.LayoutElementBuilders.FONT_WEIGHT_BOLD
import androidx.wear.protolayout.LayoutElementBuilders.HORIZONTAL_ALIGN_CENTER
import androidx.wear.protolayout.LayoutElementBuilders.HORIZONTAL_ALIGN_START
import androidx.wear.protolayout.LayoutElementBuilders.VERTICAL_ALIGN_CENTER
import androidx.wear.protolayout.ModifiersBuilders
import androidx.wear.protolayout.TimelineBuilders
import androidx.wear.tiles.RequestBuilders
import androidx.wear.tiles.ResourceBuilders
import androidx.wear.tiles.TileBuilders
import androidx.wear.tiles.TileService
import com.google.common.util.concurrent.ListenableFuture
import dev.creapolis.pepinillo.data.WearSnapshotStore
import dev.creapolis.pepinillo.data.WearTask

class TasksTileService : TileService() {

    companion object {
        private const val RESOURCES_VERSION = "1"
        private const val REFRESH_MS = 60_000L
        private const val MAX_VISIBLE_TASKS = 4
        private const val MAX_TITLE_LENGTH = 15
    }

    override fun onTileRequest(
        requestParams: RequestBuilders.TileRequest,
    ): ListenableFuture<TileBuilders.Tile> =
        CallbackToFutureAdapter.getFuture<TileBuilders.Tile> { completer ->
            completer.set(buildTile())
            "TasksTileService.onTileRequest"
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
            "TasksTileService.onResourcesRequest"
        }

    private fun buildTile(): TileBuilders.Tile {
        val tasks = WearSnapshotStore.readTasks(this)
        val stats = WearSnapshotStore.readStats(this)
        val isPro = WearSnapshotStore.readIsPro(this)
        val root = if (isPro) {
            buildLayout(tasks, stats.completedTasks, tasks.size)
        } else {
            buildLockedLayout()
        }

        return TileBuilders.Tile.Builder()
            .setResourcesVersion(RESOURCES_VERSION)
            .setFreshnessIntervalMillis(REFRESH_MS)
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

    private fun buildLayout(
        tasks: List<WearTask>,
        completedCount: Int,
        totalCount: Int,
    ): LayoutElementBuilders.LayoutElement {
        val titleText = "Tasks ($completedCount/$totalCount done)"

        val column = LayoutElementBuilders.Column.Builder()
            .setHorizontalAlignment(HORIZONTAL_ALIGN_CENTER)
            .addContent(text(titleText, 16f, bold = true))
            .addContent(spacer(6f))

        if (tasks.isEmpty()) {
            column.addContent(spacer(8f))
            column.addContent(text("No tasks", 14f, color = 0xFF888888.toInt()))
        } else {
            val visible = tasks.take(MAX_VISIBLE_TASKS)
            for (task in visible) {
                column.addContent(buildTaskRow(task))
                column.addContent(spacer(4f))
            }
        }

        return LayoutElementBuilders.Box.Builder()
            .setWidth(DimensionBuilders.expand())
            .setHeight(DimensionBuilders.expand())
            .setVerticalAlignment(VERTICAL_ALIGN_CENTER)
            .setHorizontalAlignment(HORIZONTAL_ALIGN_CENTER)
            .setModifiers(clickableModifiers())
            .addContent(column.build())
            .build()
    }

    private fun buildTaskRow(task: WearTask): LayoutElementBuilders.LayoutElement {
        val emoji = task.energyEmoji.ifEmpty { "\u2022" }
        val title = if (task.title.length > MAX_TITLE_LENGTH) {
            task.title.take(MAX_TITLE_LENGTH) + "\u2026"
        } else {
            task.title
        }
        val progress = task.pomodoroProgress.ifEmpty { "" }
        val rowText = if (progress.isNotEmpty()) "$emoji $title  $progress" else "$emoji $title"

        return LayoutElementBuilders.Row.Builder()
            .addContent(text(rowText, 13f, color = 0xFFCCCCCC.toInt()))
            .build()
    }

    private fun buildLockedLayout(): LayoutElementBuilders.LayoutElement =
        LayoutElementBuilders.Box.Builder()
            .setWidth(DimensionBuilders.expand())
            .setHeight(DimensionBuilders.expand())
            .setVerticalAlignment(VERTICAL_ALIGN_CENTER)
            .setHorizontalAlignment(HORIZONTAL_ALIGN_CENTER)
            .setModifiers(clickableModifiers())
            .addContent(
                LayoutElementBuilders.Column.Builder()
                    .setHorizontalAlignment(HORIZONTAL_ALIGN_CENTER)
                    .addContent(text("Pepinillo+", 18f, bold = true))
                    .addContent(spacer(6f))
                    .addContent(text("Unlock Tasks tile", 14f, color = 0xFFCCCCCC.toInt()))
                    .addContent(spacer(6f))
                    .addContent(text("Upgrade in the app", 13f, color = 0xFF888888.toInt()))
                    .build(),
            )
            .build()
}
