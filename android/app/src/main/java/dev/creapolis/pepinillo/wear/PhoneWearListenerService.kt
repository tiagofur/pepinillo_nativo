package dev.creapolis.pepinillo.wear

import android.content.Intent
import android.util.Log
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.workDataOf
import com.google.android.gms.wearable.MessageEvent
import com.google.android.gms.wearable.WearableListenerService
import dev.creapolis.pepinillo.service.FocusTimerService
import dev.creapolis.pepinillo.widget.CompleteTaskWorker
import java.nio.charset.StandardCharsets

private const val TAG = "PhoneWearListener"

class PhoneWearListenerService : WearableListenerService() {

    override fun onMessageReceived(messageEvent: MessageEvent) {
        when (messageEvent.path) {
            WearDataLayerHelper.CMD_TIMER_START -> {
                val mode = messageEvent.data.toString(StandardCharsets.UTF_8).ifBlank { "Pomodoro" }
                startForegroundService(
                    Intent(this, FocusTimerService::class.java).apply {
                        action = FocusTimerService.ACTION_START_MODE
                        putExtra("mode", mode)
                    },
                )
            }

            WearDataLayerHelper.CMD_TIMER_PAUSE -> {
                startService(
                    Intent(this, FocusTimerService::class.java).apply {
                        action = FocusTimerService.ACTION_PAUSE
                    },
                )
            }

            WearDataLayerHelper.CMD_TIMER_RESUME -> {
                startForegroundService(
                    Intent(this, FocusTimerService::class.java).apply {
                        action = FocusTimerService.ACTION_RESUME
                    },
                )
            }

            WearDataLayerHelper.CMD_TIMER_STOP -> {
                startService(
                    Intent(this, FocusTimerService::class.java).apply {
                        action = FocusTimerService.ACTION_STOP
                    },
                )
            }

            WearDataLayerHelper.CMD_TASK_COMPLETE -> {
                val taskId = messageEvent.data.toString(StandardCharsets.UTF_8)
                if (taskId.isNotBlank()) {
                    WorkManager.getInstance(this).enqueue(
                        OneTimeWorkRequestBuilder<CompleteTaskWorker>()
                            .setInputData(workDataOf(CompleteTaskWorker.KEY_TASK_ID to taskId))
                            .build(),
                    )
                }
            }

            else -> {
                Log.d(TAG, "Ignored path: ${messageEvent.path}")
            }
        }
    }
}
