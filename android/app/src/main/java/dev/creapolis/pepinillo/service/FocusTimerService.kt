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
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import androidx.glance.appwidget.updateAll
import dagger.hilt.android.AndroidEntryPoint
import dev.creapolis.pepinillo.MainActivity
import dev.creapolis.pepinillo.R
import dev.creapolis.pepinillo.core.billing.FeatureGate
import dev.creapolis.pepinillo.data.repository.SessionRepository
import dev.creapolis.pepinillo.domain.streak.StreakProtectionService
import dev.creapolis.pepinillo.domain.timer.FocusEngine
import dev.creapolis.pepinillo.domain.timer.FocusPhase
import dev.creapolis.pepinillo.domain.timer.FocusTimerState
import dev.creapolis.pepinillo.domain.timer.TimerStatus
import dev.creapolis.pepinillo.domain.timer.displayTime
import dev.creapolis.pepinillo.domain.timer.phaseLabelRes
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
import dev.creapolis.pepinillo.widget.FocusTimerWidgetLogic
import dev.creapolis.pepinillo.widget.updateWidgetState
import dev.creapolis.pepinillo.data.local.preferences.UserPreferencesRepository
import dev.creapolis.pepinillo.data.local.preferences.UserPreferences
import dev.creapolis.pepinillo.data.local.entity.DailyStatsEntity
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.launch
import javax.inject.Inject

private data class TimerWidgetUpdateData(
    val state: dev.creapolis.pepinillo.domain.timer.FocusTimerState,
    val streak: Int,
    val sessionsToday: Int,
    val themeId: String,
    val themeMode: String,
)

@AndroidEntryPoint
class FocusTimerService : Service() {

    @Inject lateinit var focusEngine: FocusEngine
    @Inject lateinit var sessionRepository: SessionRepository
    @Inject lateinit var taskRepository: dev.creapolis.pepinillo.data.repository.TaskRepository
    @Inject lateinit var userPreferencesRepository: UserPreferencesRepository
    @Inject lateinit var featureGate: FeatureGate

    private val serviceScope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
    private var isCollecting = false
    private var sessionsBeforeLongBreak = 4
    private var dayChangeReceiver: BroadcastReceiver? = null

    companion object {
        const val CHANNEL_ID = "focus_timer_channel"
        const val NOTIFICATION_ID = 1
        const val ACTION_PAUSE = "dev.creapolis.pepinillo.PAUSE"
        const val ACTION_RESUME = "dev.creapolis.pepinillo.RESUME"
        const val ACTION_STOP = "dev.creapolis.pepinillo.STOP"
        const val ACTION_START_MODE = "dev.creapolis.pepinillo.START_MODE"
        const val ACTION_SELECT_MODE = "dev.creapolis.pepinillo.SELECT_MODE"
        const val ACTION_RECOVER = "dev.creapolis.pepinillo.RECOVER"
        const val EXTRA_MODE = "mode"

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
        private const val KEY_R_ELAPSED = "r_elapsed"
        private const val KEY_R_LINKED_TASK_ID = "linked_task_id"
        private const val KEY_R_POMODORO_NUMBER = "r_pomodoro_number"
        private const val KEY_R_PAUSE_COUNT = "r_pause_count"
        private const val KEY_R_TOTAL_PAUSE_MILLIS = "r_total_pause_millis"

        fun start(context: Context) {
            context.startForegroundService(Intent(context, FocusTimerService::class.java))
        }

        fun stop(context: Context) {
            context.stopService(Intent(context, FocusTimerService::class.java))
        }

        fun saveRecoveryState(context: Context, state: FocusTimerState) {
            // W-8: persist linkedTaskId so restored sessions keep the task link.
            // putString(key, null) removes the key, which reads back as the null default.
            context.getSharedPreferences(RECOVERY_PREFS, Context.MODE_PRIVATE).edit()
                .putString(KEY_R_MODE, state.mode.name)
                .putString(KEY_R_PHASE, state.phase.name)
                .putLong(KEY_R_START, state.sessionStartTime)
                .putLong(KEY_R_ELAPSED, state.elapsedMillis)
                .putLong(KEY_R_TOTAL, state.totalMillis)
                .putInt(KEY_R_COMPLETED, state.completedSessions)
                .putString(KEY_R_STATUS, state.status.name)
                .putString(KEY_R_LINKED_TASK_ID, state.linkedTaskId)
                .putBoolean(KEY_R_ACTIVE, true)
                .putLong(KEY_R_DAY_START, SessionRepository.startOfDay(System.currentTimeMillis()))
                .putInt(KEY_R_POMODORO_NUMBER, state.completedSessions + 1)
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
                elapsedMillis = prefs.getLong(KEY_R_ELAPSED, 0L),
                totalMillis = prefs.getLong(KEY_R_TOTAL, 0L),
                completedSessions = prefs.getInt(KEY_R_COMPLETED, 0),
                linkedTaskId = prefs.getString(KEY_R_LINKED_TASK_ID, null),
                savedDayStart = prefs.getLong(KEY_R_DAY_START, 0L),
                pomodoroNumber = prefs.getInt(KEY_R_POMODORO_NUMBER, 1),
                pauseCount = prefs.getInt(KEY_R_PAUSE_COUNT, 0),
                totalPauseMillis = prefs.getLong(KEY_R_TOTAL_PAUSE_MILLIS, 0L),
            )
        }
    }

    data class RecoveryState(
        val mode: FocusMode,
        val phase: FocusPhase,
        val status: TimerStatus = TimerStatus.Running,
        val sessionStartTime: Long,
        val elapsedMillis: Long = 0L,
        val totalMillis: Long,
        val completedSessions: Int,
        val linkedTaskId: String? = null,
        val savedDayStart: Long = 0L,
        val pomodoroNumber: Int = 1,
        val pauseCount: Int = 0,
        val totalPauseMillis: Long = 0L,
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
        ContextCompat.registerReceiver(this, dayChangeReceiver, filter, ContextCompat.RECEIVER_NOT_EXPORTED)
    }

    private fun startForegroundCompat(notification: Notification) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        // null intent = START_STICKY restart after process death — attempt recovery
        if (intent == null || intent.action == ACTION_RECOVER) {
            startForegroundCompat(buildNotification(focusEngine.state.value))
            val recovery = readRecoveryState(this)
            if (recovery != null) {
                serviceScope.launch {
                    val elapsed = if (recovery.status == TimerStatus.WaitingForNext) 0L
                    else recovery.elapsedMillis
                    focusEngine.restoreState(
                        mode = recovery.mode,
                        phase = recovery.phase,
                        elapsedMillis = elapsed,
                        totalMillis = recovery.totalMillis,
                        completedSessions = recovery.completedSessions,
                        sessionStartTime = recovery.sessionStartTime,
                        status = recovery.status,
                        savedDayStart = recovery.savedDayStart,
                        linkedTaskId = recovery.linkedTaskId,
                        pomodoroNumber = recovery.pomodoroNumber,
                        pauseCount = recovery.pauseCount,
                        totalPauseMillis = recovery.totalPauseMillis,
                    )
                }
            } else {
                if (intent?.action == ACTION_RECOVER) {
                    // Cold start with stale widget — recovery already cleared by bootstrap.
                    stopSelf()
                    return START_NOT_STICKY
                }
                // Nothing to restore — stop the service
                stopSelf()
                return START_NOT_STICKY
            }
            startCollectingIfNeeded()
            return START_STICKY
        }

        // A-C10/B-Cat5: Always call startForeground BEFORE any action-specific branching.
        // ACTION_PAUSE and ACTION_STOP can be delivered to a freshly-(re)created service
        // (system reclaimed it, or a Wear/widget click re-launches it after stopSelf). On
        // Android 12+ startForeground MUST be invoked within 5s of the service starting
        // regardless of which action triggered it, otherwise the system throws
        // ForegroundServiceDidNotStartInTimeException. Calling it here once up-front makes
        // every entry path compliant. stopForeground/stopSelf later in the same invocation
        // is still legal after startForeground has run.
        startForegroundCompat(buildNotification(focusEngine.state.value))

        when (intent.action) {
            ACTION_PAUSE -> focusEngine.pause()
            ACTION_RESUME -> {
                focusEngine.start()
            }
            ACTION_STOP -> {
                // Capture the current mode before triggering the async stop coroutine,
                // then push the idle reset values immediately using the default display time
                // for that mode. This prevents the watch UI from freezing on the last
                // running timer value while focusEngine.stop() completes asynchronously.
                val currentMode = focusEngine.state.value.mode
                focusEngine.stop()
                clearRecoveryState(this)
                WearDataLayerHelper.pushIdleState(
                    context = this,
                    mode = currentMode.name,
                    displayTime = "", // Empty string signals idle; watch resets display to full duration
                )
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
                startCollectingIfNeeded()
                serviceScope.launch { focusEngine.selectMode(mode) }
                return START_STICKY
            }
        }

        startCollectingIfNeeded()

        return START_STICKY
    }

    private fun startCollectingIfNeeded() {
        if (isCollecting) return
        isCollecting = true

        // Collect timer state — update notification + widget
        serviceScope.launch {
            var lastWidgetUpdate = 0L
            var previousStatus: TimerStatus? = null
            var previousPhase: FocusPhase? = null
            var previousMode: dev.creapolis.pepinillo.feature.focus.FocusMode? = null
            var previousThemeId: String? = null
            // Recovery-write throttle: persist only on status/phase change or once per second.
            var lastRecoveryWriteMs = 0L
            var recoveryStatus: TimerStatus? = null
            var recoveryPhase: dev.creapolis.pepinillo.domain.timer.FocusPhase? = null

            combine(
                focusEngine.state,
                sessionRepository.getTodayStats(),
                sessionRepository.getAllDaysWithSessions(),
                userPreferencesRepository.preferences,
            ) { timerState: dev.creapolis.pepinillo.domain.timer.FocusTimerState, stats: DailyStatsEntity?, allDays: List<DailyStatsEntity>, userPrefs: UserPreferences ->
                val streak = StreakProtectionService.computeProtectedStreak(
                    history = allDays,
                    isPro = featureGate.isPro,
                ).days
                val sessionsToday = stats?.sessionsCompleted ?: 0
                val themeId = userPrefs.selectedTheme
                val themeMode = userPrefs.themeMode.name
                
                this@FocusTimerService.sessionsBeforeLongBreak = userPrefs.sessionsBeforeLongBreak
                TimerWidgetUpdateData(timerState, streak, sessionsToday, themeId, themeMode)
            }.collect { info: TimerWidgetUpdateData ->
                val state = info.state
                val streak = info.streak
                val sessionsToday = info.sessionsToday
                val themeId = info.themeId
                try {
                    // Resolve linked task title
                    val taskTitle = if (state.linkedTaskId != null) {
                        taskRepository.getTaskTitle(state.linkedTaskId)
                    } else null

                    // Detect changes to bypass throttle
                    val now = System.currentTimeMillis()
                    val statusChanged = state.status != previousStatus
                    val phaseChanged = state.phase != previousPhase
                    val modeChanged = state.mode != previousMode
                    val themeChanged = themeId != previousThemeId

                    // Update notification on status/phase/mode changes or widget throttle,
                    // relying on standard Chronometer countdown for smooth 1Hz ticks without 4Hz binder spam
                    val shouldUpdateNotification = statusChanged || phaseChanged || modeChanged || themeChanged
                    if (shouldUpdateNotification) {
                        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
                            ContextCompat.checkSelfPermission(this@FocusTimerService, Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED) {
                            getSystemService(NotificationManager::class.java)
                                .notify(NOTIFICATION_ID, buildNotification(state))
                        }
                    }

                    val phaseCompletedForWaiting = previousStatus == TimerStatus.Running &&
                        state.status == TimerStatus.WaitingForNext &&
                        previousPhase != null
                    val phaseChangedWhileRunning = previousStatus == TimerStatus.Running &&
                        state.status == TimerStatus.Running &&
                        previousPhase != null &&
                        state.phase != previousPhase
                    if (phaseCompletedForWaiting || phaseChangedWhileRunning) {
                        WearDataLayerHelper.pushPhaseComplete(
                            context = this@FocusTimerService,
                            mode = state.mode.name,
                            completedPhase = previousPhase!!.name,
                            scope = serviceScope,
                        )
                    }
                    
                    val throttleMs = FocusTimerWidgetLogic.widgetUpdateThrottleMs(state.status)
                    val shouldUpdateWidget = statusChanged || modeChanged || themeChanged ||
                        (now - lastWidgetUpdate >= throttleMs)
                    
                    previousStatus = state.status
                    previousPhase = state.phase
                    previousMode = state.mode
                    previousThemeId = themeId
                    
                    // Persist recovery state when relevant state changes (status/phase transition)
                    // or at most once per second — cuts write rate ~99% while keeping fidelity
                    // within 1s of process death. Clear only on the first Idle emission.
                    if (state.status == TimerStatus.Running || state.status == TimerStatus.Paused || state.status == TimerStatus.WaitingForNext) {
                        val recoveryStatusChanged = state.status != recoveryStatus
                        val recoveryPhaseChanged = state.phase != recoveryPhase
                        val throttleElapsed = (now - lastRecoveryWriteMs) >= 1_000L
                        if (recoveryStatusChanged || recoveryPhaseChanged || throttleElapsed) {
                            saveRecoveryState(this@FocusTimerService, state)
                            lastRecoveryWriteMs = now
                            recoveryStatus = state.status
                            recoveryPhase = state.phase
                        }
                    } else if (state.status == TimerStatus.Idle && recoveryStatus != TimerStatus.Idle) {
                        // Clear once on transition to Idle, not on every subsequent Idle emission.
                        clearRecoveryState(this@FocusTimerService)
                        recoveryStatus = TimerStatus.Idle
                        recoveryPhase = null
                    }

                    if (shouldUpdateWidget) {
                        lastWidgetUpdate = now

                        val finishTimestamp = if (state.status == TimerStatus.Running &&
                            state.mode != FocusMode.Flow && state.mode != FocusMode.Chrono && state.totalMillis > 0L) {
                            val remainingMillis = (state.totalMillis - state.elapsedMillis).coerceAtLeast(0L)
                            System.currentTimeMillis() + remainingMillis
                        } else null

                        val widgetState = TimerWidgetState(
                            mode = state.mode,
                            selectedMode = state.mode,
                            displayTime = state.displayTime,
                            finishTimestamp = finishTimestamp,
                            phaseLabel = if (state.mode == FocusMode.Pomodoro && state.phase == FocusPhase.Work) {
                                this@FocusTimerService.getString(state.phaseLabelRes, state.completedSessions + 1)
                            } else {
                                this@FocusTimerService.getString(state.phaseLabelRes)
                            },
                            status = state.status,
                            progress = state.progress,
                            linkedTaskName = state.linkedTaskId,
                            linkedTaskTitle = taskTitle,
                            elapsedMillis = state.elapsedMillis,
                            streak = streak,
                            sessionsToday = sessionsToday,
                            themeId = themeId,
                            phase = state.phase,
                            themeMode = info.themeMode,
                        )
                        updateWidgetState(this@FocusTimerService, widgetState)
                        FocusTimerWidget().updateAll(context = this@FocusTimerService)

                        // Keep tasks widget in sync with linked task highlight
                        WidgetTaskStateManager.updateLinkedTaskId(this@FocusTimerService, state.linkedTaskId)
                        WearDataLayerHelper.pushTimer(this@FocusTimerService, state, taskTitle)
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
                    streak = StreakProtectionService.computeProtectedStreak(
                        history = allDays,
                        isPro = featureGate.isPro,
                    ).days,
                    completedTasksToday = completedToday,
                )
            }
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        if (::focusEngine.isInitialized) {
            val state = focusEngine.state.value
            // If the timer is idle when destroyed, push idle state so the watch UI resets.
            // Otherwise push the current state (e.g. paused/waiting) for continuity.
            if (state.status == TimerStatus.Idle) {
                WearDataLayerHelper.pushIdleState(
                    context = this,
                    mode = state.mode.name,
                    displayTime = state.displayTime,
                )
            } else {
                WearDataLayerHelper.pushTimer(this, state, null)
            }
        }
        isCollecting = false
        serviceScope.cancel()
        dayChangeReceiver?.let { unregisterReceiver(it) }
        super.onDestroy()
    }

    private fun createNotificationChannel() {
        val channel = NotificationChannel(
            CHANNEL_ID, getString(R.string.notification_channel_name), NotificationManager.IMPORTANCE_LOW,
        ).apply {
            description = getString(R.string.notification_channel_description)
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

        val phaseLabel = if (state.mode == FocusMode.Pomodoro &&
            state.phase == dev.creapolis.pepinillo.domain.timer.FocusPhase.Work &&
            (state.status == TimerStatus.Running || state.status == TimerStatus.Paused ||
                state.status == TimerStatus.WaitingForNext)) {
            val focusWord = getString(R.string.phase_focus)
            "$focusWord ${state.completedSessions + 1}/$sessionsBeforeLongBreak"
        } else {
            getString(state.phaseLabelRes)
        }

        val builder = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle("${getString(state.mode.labelRes)} \u2014 $phaseLabel")
            .setContentText(state.displayTime)
            .setContentIntent(openApp)
            .setOngoing(true)
            .setSilent(true)
            .setCategory(NotificationCompat.CATEGORY_PROGRESS)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)

        // Native countdown chronometer for timed phases (Pomodoro/breaks) while running.
        // Avoids rewriting the notification text every tick and renders a live countdown on the lock screen.
        if (state.status == TimerStatus.Running &&
            state.mode != FocusMode.Flow &&
            state.mode != FocusMode.Chrono &&
            state.totalMillis > 0L
        ) {
            val remainingMs = (state.totalMillis - state.elapsedMillis).coerceAtLeast(0L)
            builder.setUsesChronometer(true)
            builder.setChronometerCountDown(true)
            builder.setWhen(System.currentTimeMillis() + remainingMs)
        }

        when (state.status) {
            TimerStatus.Running -> builder.addAction(0, getString(R.string.btn_pause), servicePending(1, ACTION_PAUSE))
            TimerStatus.Paused -> builder.addAction(0, getString(R.string.btn_resume), servicePending(2, ACTION_RESUME))
            TimerStatus.WaitingForNext -> {
                val actionLabel = when (state.phase) {
                    dev.creapolis.pepinillo.domain.timer.FocusPhase.ShortBreak -> getString(R.string.btn_start_break)
                    dev.creapolis.pepinillo.domain.timer.FocusPhase.LongBreak -> getString(R.string.btn_start_long_break)
                    else -> getString(R.string.btn_start_focus)
                }
                builder.addAction(0, actionLabel, servicePending(2, ACTION_RESUME))
            }
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
