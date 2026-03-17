package dev.creapolis.pepinillo.tile

import androidx.concurrent.futures.CallbackToFutureAdapter
import androidx.wear.protolayout.ActionBuilders
import androidx.wear.protolayout.DimensionBuilders
import androidx.wear.protolayout.LayoutElementBuilders
import androidx.wear.protolayout.ModifiersBuilders
import androidx.wear.protolayout.TimelineBuilders
import androidx.wear.tiles.RequestBuilders
import androidx.wear.tiles.ResourceBuilders
import androidx.wear.tiles.TileBuilders
import androidx.wear.tiles.TileService
import com.google.common.util.concurrent.ListenableFuture
import dev.creapolis.pepinillo.data.WearDataStore

class FocusTileService : TileService() {

    companion object {
        private const val RESOURCES_VERSION = "1"
        private const val REFRESH_MS = 60_000L
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
        val state = WearDataStore.timerState.value

        val displayText = when {
            state.status == "Running" || state.status == "Paused" -> state.displayTime
            else -> "Pepinillo"
        }
        val labelText = when (state.status) {
            "Running" -> "${state.mode} \u00b7 ${state.phaseLabel}"
            "Paused"  -> "En pausa"
            else      -> "Toca para enfocar"
        }

        val launchAction = ActionBuilders.LaunchAction.Builder()
            .setAndroidActivity(
                ActionBuilders.AndroidActivity.Builder()
                    .setPackageName(packageName)
                    .setClassName("dev.creapolis.pepinillo.presentation.MainActivity")
                    .build(),
            ).build()

        val root = LayoutElementBuilders.Box.Builder()
            .setWidth(DimensionBuilders.expand())
            .setHeight(DimensionBuilders.expand())
            .setVerticalAlignment(LayoutElementBuilders.VERTICAL_ALIGN_CENTER)
            .setHorizontalAlignment(LayoutElementBuilders.HORIZONTAL_ALIGN_CENTER)
            .setModifiers(
                ModifiersBuilders.Modifiers.Builder()
                    .setClickable(
                        ModifiersBuilders.Clickable.Builder()
                            .setId("launch_app")
                            .setOnClick(launchAction)
                            .build(),
                    ).build(),
            )
            .addContent(
                LayoutElementBuilders.Column.Builder()
                    .setHorizontalAlignment(LayoutElementBuilders.HORIZONTAL_ALIGN_CENTER)
                    .addContent(
                        LayoutElementBuilders.Text.Builder()
                            .setText(displayText)
                            .setFontStyle(
                                LayoutElementBuilders.FontStyle.Builder()
                                    .setSize(DimensionBuilders.SpProp.Builder().setValue(28f).build())
                                    .build(),
                            )
                            .build(),
                    )
                    .addContent(
                        LayoutElementBuilders.Text.Builder()
                            .setText(labelText)
                            .setFontStyle(
                                LayoutElementBuilders.FontStyle.Builder()
                                    .setSize(DimensionBuilders.SpProp.Builder().setValue(14f).build())
                                    .build(),
                            )
                            .build(),
                    )
                    .build(),
            )
            .build()

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
}
