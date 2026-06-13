package dev.creapolis.pepinillo.service

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import androidx.wear.ongoing.OngoingActivity
import androidx.wear.ongoing.Status
import dev.creapolis.pepinillo.R
import dev.creapolis.pepinillo.data.WearDataStore
import dev.creapolis.pepinillo.data.WearTimerState
import dev.creapolis.pepinillo.presentation.MainActivity
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.flow.launchIn
import kotlinx.coroutines.flow.onEach

class WearFocusService : Service() {
    private val serviceScope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
    private var isStarted = false

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (!isStarted) {
            isStarted = true
            startForegroundWithNotification()
            observeTimerState()
        }
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val name = "Focus Timer"
            val descriptionText = "Displays the active focus timer countdown"
            val importance = NotificationManager.IMPORTANCE_LOW
            val channel = NotificationChannel(CHANNEL_ID, name, importance).apply {
                description = descriptionText
            }
            val notificationManager = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
        }
    }

    private fun startForegroundWithNotification() {
        val notification = buildNotification(WearDataStore.timerState.value)
        startForeground(NOTIFICATION_ID, notification)
    }

    private fun observeTimerState() {
        WearDataStore.timerState
            .onEach { timerState ->
                if (timerState.status != "Running" && timerState.status != "Paused") {
                    stopSelf()
                } else {
                    val notification = buildNotification(timerState)
                    val notificationManager = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
                    notificationManager.notify(NOTIFICATION_ID, notification)
                }
            }
            .launchIn(serviceScope)
    }

    private fun buildNotification(state: WearTimerState): android.app.Notification {
        val title = when (state.phase) {
            "Work" -> getString(R.string.phase_focus)
            "ShortBreak", "LongBreak" -> getString(R.string.phase_break)
            else -> state.phaseLabel
        }
        val text = if (state.linkedTaskName != null) {
            "${state.linkedTaskName} • ${state.displayTime}"
        } else {
            state.displayTime
        }

        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val notificationBuilder = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(title)
            .setContentText(text)
            .setSmallIcon(dev.creapolis.pepinillo.R.mipmap.ic_launcher)
            .setOngoing(true)
            .setCategory(NotificationCompat.CATEGORY_STATUS)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setContentIntent(pendingIntent)

        // Build OngoingActivity Status
        val statusBuilder = Status.Builder()
        if (state.status == "Running" && state.phaseEndEpochMs > 0L) {
            val now = System.currentTimeMillis()
            val remainingMs = state.phaseEndEpochMs - now
            if (remainingMs > 0) {
                statusBuilder.addTemplate("#time# • $title")
                statusBuilder.addPart("time", Status.TimerPart(state.phaseEndEpochMs))
            } else {
                statusBuilder.addTemplate(title)
            }
        } else {
            val pausedLabel = if (state.status == "Paused") getString(R.string.state_paused_suffix) else ""
            statusBuilder.addTemplate("$title$pausedLabel")
        }

        val ongoingActivity = OngoingActivity.Builder(applicationContext, NOTIFICATION_ID, notificationBuilder)
            .setStaticIcon(dev.creapolis.pepinillo.R.mipmap.ic_launcher)
            .setTouchIntent(pendingIntent)
            .setStatus(statusBuilder.build())
            .build()

        ongoingActivity.apply(applicationContext)

        return notificationBuilder.build()
    }

    override fun onDestroy() {
        serviceScope.cancel()
        super.onDestroy()
    }

    companion object {
        private const val NOTIFICATION_ID = 4201
        private const val CHANNEL_ID = "wear_focus_timer_channel"

        fun start(context: Context) {
            val intent = Intent(context, WearFocusService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stop(context: Context) {
            val intent = Intent(context, WearFocusService::class.java)
            context.stopService(intent)
        }
    }
}
