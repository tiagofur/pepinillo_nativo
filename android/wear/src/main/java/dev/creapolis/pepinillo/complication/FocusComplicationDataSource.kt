package dev.creapolis.pepinillo.complication

import androidx.wear.watchface.complications.data.ComplicationData
import androidx.wear.watchface.complications.data.ComplicationType
import androidx.wear.watchface.complications.data.LongTextComplicationData
import androidx.wear.watchface.complications.data.PlainComplicationText
import androidx.wear.watchface.complications.data.RangedValueComplicationData
import androidx.wear.watchface.complications.data.ShortTextComplicationData
import androidx.wear.watchface.complications.datasource.ComplicationRequest
import androidx.wear.watchface.complications.datasource.SuspendingComplicationDataSourceService
import dev.creapolis.pepinillo.data.WearDataStore

class FocusComplicationDataSource : SuspendingComplicationDataSourceService() {

    override fun getPreviewData(type: ComplicationType): ComplicationData? =
        buildData(type, displayTime = "25:00", mode = "Pomodoro", progress = 1f)

    override suspend fun onComplicationRequest(request: ComplicationRequest): ComplicationData? {
        val state = WearDataStore.timerState.value
        return buildData(
            type = request.complicationType,
            displayTime = state.displayTime,
            mode = state.mode,
            progress = state.progress.coerceIn(0f, 1f),
        )
    }

    private fun buildData(
        type: ComplicationType,
        displayTime: String,
        mode: String,
        progress: Float,
    ): ComplicationData? {
        val description = PlainComplicationText.Builder("Focus timer").build()
        return when (type) {
            ComplicationType.SHORT_TEXT ->
                ShortTextComplicationData.Builder(
                    text = PlainComplicationText.Builder(displayTime).build(),
                    contentDescription = description,
                )
                    .setTitle(PlainComplicationText.Builder(mode).build())
                    .build()

            ComplicationType.LONG_TEXT ->
                LongTextComplicationData.Builder(
                    text = PlainComplicationText.Builder("$mode \u00b7 $displayTime").build(),
                    contentDescription = description,
                ).build()

            ComplicationType.RANGED_VALUE ->
                RangedValueComplicationData.Builder(
                    value = progress,
                    min = 0f,
                    max = 1f,
                    contentDescription = description,
                )
                    .setText(PlainComplicationText.Builder(displayTime).build())
                    .build()

            else -> null
        }
    }
}
