package dev.creapolis.pepinillo.complication

import androidx.wear.watchface.complications.data.ComplicationData
import androidx.wear.watchface.complications.data.ComplicationType
import androidx.wear.watchface.complications.data.LongTextComplicationData
import androidx.wear.watchface.complications.data.PlainComplicationText
import androidx.wear.watchface.complications.data.RangedValueComplicationData
import androidx.wear.watchface.complications.data.ShortTextComplicationData
import androidx.wear.watchface.complications.datasource.ComplicationRequest
import androidx.wear.watchface.complications.datasource.SuspendingComplicationDataSourceService
import dev.creapolis.pepinillo.data.WearSnapshotStore

class FocusComplicationDataSource : SuspendingComplicationDataSourceService() {

    override fun getPreviewData(type: ComplicationType): ComplicationData? =
        buildData(type, displayTime = "25:00", mode = "Pomodoro", progress = 1f)

    override suspend fun onComplicationRequest(request: ComplicationRequest): ComplicationData? {
        if (!WearSnapshotStore.readIsPro(this)) {
            return buildLockedData(request.complicationType)
        }

        val state = WearSnapshotStore.readTimerState(this)

        // When running, recalculate from the stored end epoch for a live countdown
        val (liveDisplayTime, liveProgress) = if (
            state.status == "Running" && state.phaseEndEpochMs > 0 && state.totalDurationMs > 0
        ) {
            val now = System.currentTimeMillis()
            val remainingMs = (state.phaseEndEpochMs - now).coerceAtLeast(0L)
            val totalSec = (remainingMs + 999) / 1000
            val mins = totalSec / 60
            val secs = totalSec % 60
            val display = "%02d:%02d".format(mins, secs)
            // #502: REMAINING polarity — 1f at start, 0f at the end (phone/widget match).
            val prog = (remainingMs.toFloat() / state.totalDurationMs.toFloat()).coerceIn(0f, 1f)
            display to prog
        } else {
            state.displayTime to state.progress.coerceIn(0f, 1f)
        }

        return buildData(
            type = request.complicationType,
            displayTime = liveDisplayTime,
            mode = state.mode,
            progress = liveProgress,
        )
    }

    private fun buildLockedData(type: ComplicationType): ComplicationData? {
        val description = PlainComplicationText.Builder(getString(dev.creapolis.pepinillo.R.string.comp_locked_desc)).build()
        return when (type) {
            ComplicationType.SHORT_TEXT ->
                ShortTextComplicationData.Builder(
                    text = PlainComplicationText.Builder(getString(dev.creapolis.pepinillo.R.string.comp_locked_text)).build(),
                    contentDescription = description,
                )
                    .setTitle(PlainComplicationText.Builder(getString(dev.creapolis.pepinillo.R.string.comp_locked_title)).build())
                    .build()

            ComplicationType.LONG_TEXT ->
                LongTextComplicationData.Builder(
                    text = PlainComplicationText.Builder(getString(dev.creapolis.pepinillo.R.string.comp_locked_desc)).build(),
                    contentDescription = description,
                ).build()

            ComplicationType.RANGED_VALUE ->
                RangedValueComplicationData.Builder(
                    value = 0f,
                    min = 0f,
                    max = 1f,
                    contentDescription = description,
                )
                    .setText(PlainComplicationText.Builder(getString(dev.creapolis.pepinillo.R.string.comp_locked_text)).build())
                    .build()

            else -> null
        }
    }

    private fun buildData(
        type: ComplicationType,
        displayTime: String,
        mode: String,
        progress: Float,
    ): ComplicationData? {
        val description = PlainComplicationText.Builder(getString(dev.creapolis.pepinillo.R.string.comp_timer_desc)).build()
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
