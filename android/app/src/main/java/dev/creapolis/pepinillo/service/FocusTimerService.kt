package dev.creapolis.pepinillo.service

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.SharedPreferences
import android.content.pm.PackageManager
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
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
import dev.creapolis.pepinillo.data.sync.WidgetRefreshWorker
import dev.creapolis.pepinillo.feature.focus.FocusMode
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager
import dev.creapolis.pepinillo.wear.WearDataLayerHelper
import dev.creapolis.pepinillo.widget.FocusTimerWidget
import dev.creapolis.pepinillo.widget.TimerWidgetState
import dev.creapolis.pepinillo.widget.WidgetStateManager
import dev.creapolis.pepinillo.widget.WidgetTaskStateManager
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
    @Inject lateinit var taskRepository: dev.creapolis.pepinillo.data.repository.TaskRepository

    private val serviceScope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
    private var isCollecting = false
    private var dayChangeReceiver: BroadcastReceiver? = null

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
        private const val KEY_R_STATUS = "r_status"
        private const val KEY_R_DAY_START = "r_day_start"

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
                .putString(KEY_R_STATUS, state.status.name)
                .putBoolean(KEY_R_ACTIVE, true)
                .putLong(KEY_R_DAY_START, SessionRepository.startOfDay(System.currentTimeMillis()))
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
            val statusName = prefs.getString(KEY_R_STATUS, TimerStatus.Running.name) ?: TimerStatus.Running.name
            val status = TimerStatus.entries.find { it.name == statusName } ?: TimerStatus.Running
            val startTime = prefs.getLong(KEY_R_START, 0L)
            // Allow startTime == 0 for WaitingForNext (timer not ticking)
            if (startTime == 0L && status != TimerStatus.WaitingForNext) return null
            return RecoveryState(
                mode = FocusMode.entries.find { it.name == modeName } ?: return null,
                phase = FocusPhase.entries.find { it.name == phaseName } ?: FocusPhase.Work,
                status = status,
                sessionStartTime = startTime,
                totalMillis = prefs.getLong(KEY_R_TOTAL, 0L),
                completedSessions = prefs.getInt(KEY_R_COMPLETED, 0),
                savedDayStart = prefs.getLong(KEY_R_DAY_START, 0L),
            )
        }
    }

    data class RecoveryState(
        val mode: FocusMode,
        val phase: FocusPhase,
        val status: TimerStatus = TimerStatus.Running,
        val sessionStartTime: Long,
        val totalMillis: Long,
        val completedSessions: Int,
        val savedDayStart: Long = 0L,
    )

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        registerDayChangeReceiver()
    }

    private fun registerDayChangeReceiver() {
        dayChangeReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context, intent: Intent) {
                focusEngine.onDayChanged()
            }
        }
        val filter = IntentFilter().apply {
            addAction(Intent.ACTION_DATE_CHANGED)
            addAction(Intent.ACTION_TIME_CHANGED)
            addAction(Intent.ACTION_TIMEZONE_CHANGED)
        }
        registerReceiver(dayChangeReceiver, filter)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        // null intent = START_STICKY restart after process death — attempt recovery
        if (intent == null) {
            startForeground(NOTIFICATION_ID, buildNotification(focusEngine.state.value))
            val recovery = readRecoveryState(this)
            if (recovery != null) {
                serviceScope.launch {
                    val elapsed = if (recovery.status == TimerStatus.WaitingForNext) 0L
                    else (System.currentTimeMillis() - recovery.sessionStartTime).coerceAtLeast(0L)
                    focusEngine.restoreState(
                        mode = recovery.mode,
                        phase = recovery.phase,
                        elapsedMillis = elapsed,
                        totalMillis = recovery.totalMillis,
                        completedSessions = recovery.completedSessions,
                        sessionStartTime = recovery.sessionStartTime,
                        status = recovery.status,
                        savedDayStart = recovery.savedDayStart,
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
            ACTION_RESUME -> {
                startForeground(NOTIFICATION_ID, buildNotification(focusEngine.state.value))
                focusEngine.start()
            }
            ACTION_STOP -> {
                focusEngine.stop()
                clearRecoveryState(this)
                // Clear linked task highlight from tasks widget
                serviceScope.launch { WidgetTaskStateManager.updateLinkedTaskId(this@FocusTimerService, null) }
                // Refresh tasks+stats on watch after session ends
                WorkManager.getInstance(this).enqueue(
                    OneTimeWorkRequestBuilder<WidgetRefreshWorker>().build()
                )
                stopForeground(STOP_FOREGROUND_REMOVE)
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
                // Push tasks+stats to watch immediately
                WorkManager.getInstance(this).enqueue(
                    OneTimeWorkRequestBuilder<WidgetRefreshWorker>().build()
                )
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
            var cachedLinkedTaskId: String? = null
            var cachedLinkedTaskName: String? = null
            var previousPhase: dev.creapolis.pepinillo.domain.timer.FocusPhase? = null
            var previousStatus: TimerStatus? = null
            focusEngine.state.collect { state ->
                try {
                    // Detect phase change → notify watch to vibrate
                    val phaseChanged = previousPhase != null && state.phase != previousPhase
                    if (phaseChanged && state.status != TimerStatus.Idle) {
                        WearDataLayerHelper.pushPhaseComplete(this@FocusTimerService, state.mode.name, previousPhase!!.name)
                    }
                    previousPhase = state.phase

                    // Detect status change to bypass throttle (ensures final idle push is never skipped)
                    val statusChanged = previousStatus != null && state.status != previousStatus
                    previousStatus = state.status

                    // Update notification every tick
                    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
                        ContextCompat.checkSelfPermission(this@FocusTimerService, Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED) {
                        getSystemService(NotificationManager::class.java)
                            .notify(NOTIFICATION_ID, buildNotification(state))
                    }

                    // Resolve linked task name (only re-query when task changes)
                    if (state.linkedTaskId != cachedLinkedTaskId) {
                        cachedLinkedTaskId = state.linkedTaskId
                        cachedLinkedTaskName = state.linkedTaskId?.let {
                            taskRepository.getTaskById(it)?.title
                        }
                    }

                    // Update widget max once per second to avoid battery drain
                    // Bypass throttle on status/phase transitions so recovery and watch stay in sync
                    val now = System.currentTimeMillis()
                    if (now - lastWidgetUpdate >= 1000 || statusChanged || phaseChanged) {
                        lastWidgetUpdate = now
                        val widgetState = TimerWidgetState(
                            mode = state.mode,
                            selectedMode = state.mode,
                            displayTime = state.displayTime,
                            phaseLabel = state.phaseLabel,
                            status = state.status,
                            progress = state.progress,
                            linkedTaskName = cachedLinkedTaskName,
                        )
                        updateWidgetState(this@FocusTimerService, widgetState)
                        FocusTimerWidget().updateAll(context = this@FocusTimerService)
                        // Keep tasks widget in sync with linked task highlight
                        WidgetTaskStateManager.updateLinkedTaskId(this@FocusTimerService, state.linkedTaskId)
                        WearDataLayerHelper.pushTimer(this@FocusTimerService, state, cachedLinkedTaskName)

                        // Persist recovery state while running/waiting so we can restore after process death
                        if (state.status == TimerStatus.Running || state.status == TimerStatus.Paused || state.status == TimerStatus.WaitingForNext) {
                            saveRecoveryState(this@FocusTimerService, state)
                        } else if (state.status == TimerStatus.Idle) {
                            clearRecoveryState(this@FocusTimerService)
                        }
                    }

                    if (state.status == TimerStatus.Idle) {
                        stopForeground(STOP_FOREGROUND_REMOVE)
                        stopSelf()
                    }
                } catch (e: Exception) {
                    android.util.Log.e("FocusTimerService", "Error in state collector", e)
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
                val startOfDay = java.util.Calendar.getInstance().apply {
                    set(java.util.Calendar.HOUR_OF_DAY, 0)
                    set(java.util.Calendar.MINUTE, 0)
                    set(java.util.Calendar.SECOND, 0)
                    set(java.util.Calendar.MILLISECOND, 0)
                }.timeInMillis
                val completedToday = runCatching { taskRepository.getCompletedTodayCount(startOfDay) }.getOrDefault(0)
                WidgetStateManager.updateDailyStats(
                    context = this@FocusTimerService,
                    totalMinutes = stats?.totalMinutes ?: 0,
                    sessions = stats?.sessionsCompleted ?: 0,
                    streak = sessionRepository.calculateCurrentStreak(allDays),
                    completedTasksToday = completedToday,
                )
            }
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        isCollecting = false
        serviceScope.cancel()
        dayChangeReceiver?.let { unregisterReceiver(it) }
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

        when (state.status) {
            TimerStatus.Running -> builder.addAction(0, getString(R.string.btn_pause), servicePending(1, ACTION_PAUSE))
            TimerStatus.Paused -> builder.addAction(0, getString(R.string.btn_resume), servicePending(2, ACTION_RESUME))
            TimerStatus.WaitingForNext -> builder.addAction(0, getString(R.string.btn_start_focus), servicePending(2, ACTION_RESUME))
            else -> {}
        }
        builder.addAction(0, getString(R.string.btn_stop), servicePending(3, ACTION_STOP))

        return builder.build()
    }

    private fun servicePending(code: Int, action: String): PendingIntent =
        PendingIntent.getService(
            this, code,
            Intent(this, FocusTimerService::class.java).apply { this.action = action },
            PendingIntent.FLAG_IMMUTABLE,
        )
}
