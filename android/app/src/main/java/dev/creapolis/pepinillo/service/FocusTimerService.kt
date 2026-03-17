package dev.creapolis.pepinillo.service

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.os.IBinder
import androidx.core.app.NotificationCompat
import androidx.glance.appwidget.updateAll
import dagger.hilt.android.AndroidEntryPoint
import dev.creapolis.pepinillo.MainActivity
import dev.creapolis.pepinillo.R
import dev.creapolis.pepinillo.data.repository.SessionRepository
import dev.creapolis.pepinillo.domain.timer.FocusEngine
import dev.creapolis.pepinillo.domain.timer.FocusPhase
import dev.creapolis.pepinillo.domain.timer.FocusTimerState
import dev.creapolis.pepinillo.domain.timer.TimerStatus
import dev.creapolis.pepinillo.domain.timer.displayTime
import dev.creapolis.pepinillo.domain.timer.phaseLabel
import dev.creapolis.pepinillo.domain.timer.progress
import dev.creapolis.pepinillo.feature.focus.FocusMode
import dev.creapolis.pepinillo.widget.FocusTimerWidget
import dev.creapolis.pepinillo.widget.TimerWidgetState
import dev.creapolis.pepinillo.widget.WidgetStateManager
import dev.creapolis.pepinillo.widget.updateWidgetState
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.launch
import javax.inject.Inject

@AndroidEntryPoint
class FocusTimerService : Service() {

    @Inject lateinit var focusEngine: FocusEngine
    @Inject lateinit var sessionRepository: SessionRepository

    private val serviceScope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
    private var isCollecting = false

    companion object {
        const val CHANNEL_ID = "focus_timer_channel"
        const val NOTIFICATION_ID = 1
        const val ACTION_PAUSE = "dev.creapolis.pepinillo.PAUSE"
        const val ACTION_RESUME = "dev.creapolis.pepinillo.RESUME"
        const val ACTION_STOP = "dev.creapolis.pepinillo.STOP"
        const val ACTION_START_MODE = "dev.creapolis.pepinillo.START_MODE"
        const val ACTION_SELECT_MODE = "dev.creapolis.pepinillo.SELECT_MODE"

        // Recovery SharedPrefs keys
        private const val RECOVERY_PREFS = "focus_timer_recovery"
        private const val KEY_R_MODE = "r_mode"
        private const val KEY_R_PHASE = "r_phase"
        private const val KEY_R_START = "r_start"
        private const val KEY_R_TOTAL = "r_total"
        private const val KEY_R_COMPLETED = "r_completed"
        private const val KEY_R_ACTIVE = "r_active"

        fun start(context: Context) {
            context.startForegroundService(Intent(context, FocusTimerService::class.java))
        }

        fun stop(context: Context) {
            context.stopService(Intent(context, FocusTimerService::class.java))
        }

        fun saveRecoveryState(context: Context, state: FocusTimerState) {
            context.getSharedPreferences(RECOVERY_PREFS, Context.MODE_PRIVATE).edit()
                .putString(KEY_R_MODE, state.mode.name)
                .putString(KEY_R_PHASE, state.phase.name)
                .putLong(KEY_R_START, state.sessionStartTime)
                .putLong(KEY_R_TOTAL, state.totalMillis)
                .putInt(KEY_R_COMPLETED, state.completedSessions)
                .putBoolean(KEY_R_ACTIVE, true)
                .apply()
        }

        fun clearRecoveryState(context: Context) {
            context.getSharedPreferences(RECOVERY_PREFS, Context.MODE_PRIVATE).edit().clear().apply()
        }

        fun readRecoveryState(context: Context): RecoveryState? {
            val prefs = context.getSharedPreferences(RECOVERY_PREFS, Context.MODE_PRIVATE)
            if (!prefs.getBoolean(KEY_R_ACTIVE, false)) return null
            val modeName = prefs.getString(KEY_R_MODE, null) ?: return null
            val phaseName = prefs.getString(KEY_R_PHASE, FocusPhase.Work.name) ?: FocusPhase.Work.name
            val startTime = prefs.getLong(KEY_R_START, 0L)
            if (startTime == 0L) return null
            return RecoveryState(
                mode = FocusMode.entries.find { it.name == modeName } ?: return null,
                phase = FocusPhase.entries.find { it.name == phaseName } ?: FocusPhase.Work,
                sessionStartTime = startTime,
                totalMillis = prefs.getLong(KEY_R_TOTAL, 0L),
                completedSessions = prefs.getInt(KEY_R_COMPLETED, 0),
            )
        }
    }

    data class RecoveryState(
        val mode: FocusMode,
        val phase: FocusPhase,
        val sessionStartTime: Long,
        val totalMillis: Long,
        val completedSessions: Int,
    )

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        // null intent = START_STICKY restart after process death — attempt recovery
        if (intent == null) {
            startForeground(NOTIFICATION_ID, buildNotification(focusEngine.state.value))
            val recovery = readRecoveryState(this)
            if (recovery != null) {
                serviceScope.launch {
                    val elapsed = (System.currentTimeMillis() - recovery.sessionStartTime)
                        .coerceAtLeast(0L)
                    focusEngine.restoreState(
                        mode = recovery.mode,
                        phase = recovery.phase,
                        elapsedMillis = elapsed,
                        totalMillis = recovery.totalMillis,
                        completedSessions = recovery.completedSessions,
                        sessionStartTime = recovery.sessionStartTime,
                    )
                }
            } else {
                // Nothing to restore — stop the service
                stopSelf()
                return START_NOT_STICKY
            }
            startCollectingIfNeeded()
            return START_STICKY
        }

        when (intent.action) {
            ACTION_PAUSE -> focusEngine.pause()
            ACTION_RESUME -> focusEngine.start()
            ACTION_STOP -> {
                focusEngine.stop()
                clearRecoveryState(this)
                stopSelf()
                return START_NOT_STICKY
            }
            ACTION_START_MODE -> {
                val modeName = intent.getStringExtra("mode") ?: "Pomodoro"
                val mode = FocusMode.entries.find { it.name == modeName } ?: FocusMode.Pomodoro
                // startForeground BEFORE the suspend call to satisfy Android's 5-second requirement
                startForeground(NOTIFICATION_ID, buildNotification(focusEngine.state.value))
                startCollectingIfNeeded()
                serviceScope.launch {
                    focusEngine.selectMode(mode)
                    focusEngine.start()
                }
                return START_STICKY
            }
            ACTION_SELECT_MODE -> {
                val modeName = intent.getStringExtra("mode") ?: "Pomodoro"
                val mode = FocusMode.entries.find { it.name == modeName } ?: FocusMode.Pomodoro
                startForeground(NOTIFICATION_ID, buildNotification(focusEngine.state.value))
                startCollectingIfNeeded()
                serviceScope.launch { focusEngine.selectMode(mode) }
                return START_STICKY
            }
        }

        startForeground(NOTIFICATION_ID, buildNotification(focusEngine.state.value))
        startCollectingIfNeeded()

        return START_STICKY
    }

    private fun startCollectingIfNeeded() {
        if (isCollecting) return
        isCollecting = true

        // Collect timer state — update notification + widget
        serviceScope.launch {
            var lastWidgetUpdate = 0L
            focusEngine.state.collect { state ->
                // Update notification every tick
                getSystemService(NotificationManager::class.java)
                    .notify(NOTIFICATION_ID, buildNotification(state))

                // Update widget max once per second to avoid battery drain
                val now = System.currentTimeMillis()
                if (now - lastWidgetUpdate >= 1000) {
                    lastWidgetUpdate = now
                    val widgetState = TimerWidgetState(
                        mode = state.mode,
                        selectedMode = state.mode,
                        displayTime = state.displayTime,
                        phaseLabel = state.phaseLabel,
                        status = state.status,
                        progress = state.progress,
                    )
                    updateWidgetState(this@FocusTimerService, widgetState)
                    FocusTimerWidget().updateAll(context = this@FocusTimerService)

                    // Persist recovery state while running so we can restore after process death
                    if (state.status == TimerStatus.Running) {
                        saveRecoveryState(this@FocusTimerService, state)
                    } else if (state.status == TimerStatus.Idle) {
                        clearRecoveryState(this@FocusTimerService)
                    }
                }

                if (state.status == TimerStatus.Idle) {
                    stopSelf()
                }
            }
        }

        // Collect daily stats for stats widget
        serviceScope.launch {
            combine(
                sessionRepository.getTodayStats(),
                sessionRepository.getAllDaysWithSessions(),
            ) { stats, allDays ->
                Pair(stats, allDays)
            }.collect { (stats, allDays) ->
                WidgetStateManager.updateDailyStats(
                    context = this@FocusTimerService,
                    totalMinutes = stats?.totalMinutes ?: 0,
                    sessions = stats?.sessionsCompleted ?: 0,
                    streak = sessionRepository.calculateCurrentStreak(allDays),
                )
            }
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        isCollecting = false
        serviceScope.cancel()
        super.onDestroy()
    }

    private fun createNotificationChannel() {
        val channel = NotificationChannel(
            CHANNEL_ID, "Focus Timer", NotificationManager.IMPORTANCE_LOW,
        ).apply {
            description = "Shows the active focus timer"
            setShowBadge(false)
        }
        getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
    }

    private fun buildNotification(state: dev.creapolis.pepinillo.domain.timer.FocusTimerState): Notification {
        val openApp = PendingIntent.getActivity(
            this, 0,
            Intent(this, MainActivity::class.java).apply { flags = Intent.FLAG_ACTIVITY_SINGLE_TOP },
            PendingIntent.FLAG_IMMUTABLE,
        )

        val builder = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle("${state.mode.label} — ${state.phaseLabel}")
            .setContentText(state.displayTime)
            .setContentIntent(openApp)
            .setOngoing(true)
            .setSilent(true)
            .setCategory(NotificationCompat.CATEGORY_PROGRESS)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)

        if (state.status == TimerStatus.Running) {
            builder.addAction(0, "Pause", servicePending(1, ACTION_PAUSE))
        } else if (state.status == TimerStatus.Paused) {
            builder.addAction(0, "Resume", servicePending(2, ACTION_RESUME))
        }
        builder.addAction(0, "Stop", servicePending(3, ACTION_STOP))

        return builder.build()
    }

    private fun servicePending(code: Int, action: String): PendingIntent =
        PendingIntent.getService(
            this, code,
            Intent(this, FocusTimerService::class.java).apply { this.action = action },
            PendingIntent.FLAG_IMMUTABLE,
        )
}
