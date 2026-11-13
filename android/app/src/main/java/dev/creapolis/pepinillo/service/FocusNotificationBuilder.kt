package dev.creapolis.pepinillo.service

import android.app.Notification
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.SystemClock
import android.view.View
import android.widget.RemoteViews
import androidx.core.app.NotificationCompat
import dev.creapolis.pepinillo.MainActivity
import dev.creapolis.pepinillo.R
import dev.creapolis.pepinillo.domain.timer.FocusPhase
import dev.creapolis.pepinillo.domain.timer.FocusTimerState
import dev.creapolis.pepinillo.domain.timer.TimerStatus
import dev.creapolis.pepinillo.domain.timer.displayTime
import dev.creapolis.pepinillo.domain.timer.phaseLabelRes
import dev.creapolis.pepinillo.domain.timer.progress
import dev.creapolis.pepinillo.feature.focus.FocusMode

data class FocusNotificationSpec(
    val title: String,
    val subtitle: String,
    val fallbackContentText: String,
    val isChronometerRunning: Boolean,
    val isCountDown: Boolean,
    val chronometerBaseElapsedRealtime: Long,
    val staticTimeText: String,
    val showWhenInHeader: Boolean,
    val showProgress: Boolean,
    val progressPerMil: Int,
)

object FocusNotificationBuilder {

    fun buildSpec(
        state: FocusTimerState,
        modeLabel: String,
        phaseLabel: String,
        statusLabel: String,
        taskTitle: String?,
        nowElapsedRealtime: Long = SystemClock.elapsedRealtime(),
    ): FocusNotificationSpec {
        val cleanTask = taskTitle?.trim()?.takeIf { it.isNotEmpty() }
        val subtitle = when {
            cleanTask == null -> statusLabel
            state.status == TimerStatus.Running -> cleanTask
            else -> "$statusLabel \u00b7 $cleanTask"
        }
        val fallbackContentText = cleanTask ?: statusLabel
        val isRunning = state.status == TimerStatus.Running
        val isCountdownMode = state.mode != FocusMode.Flow &&
            state.mode != FocusMode.Chrono &&
            state.totalMillis > 0L
        val chronometerBase = if (isCountdownMode) {
            val remainingMs = (state.totalMillis - state.elapsedMillis).coerceAtLeast(0L)
            nowElapsedRealtime + remainingMs
        } else {
            nowElapsedRealtime - state.elapsedMillis
        }

        return FocusNotificationSpec(
            title = "$modeLabel \u2014 $phaseLabel",
            subtitle = subtitle,
            fallbackContentText = fallbackContentText,
            isChronometerRunning = isRunning,
            isCountDown = isCountdownMode,
            chronometerBaseElapsedRealtime = chronometerBase,
            staticTimeText = state.displayTime,
            showWhenInHeader = false,
            showProgress = isCountdownMode,
            progressPerMil = (state.progress * 1000).toInt().coerceIn(0, 1000),
        )
    }

    fun buildNotification(
        context: Context,
        state: FocusTimerState,
        sessionsBeforeLongBreak: Int,
        taskTitle: String? = null,
    ): Notification {
        val openApp = PendingIntent.getActivity(
            context,
            0,
            Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_SINGLE_TOP
            },
            PendingIntent.FLAG_IMMUTABLE,
        )

        val phaseLabel = if (state.mode == FocusMode.Pomodoro &&
            state.phase == FocusPhase.Work &&
            (state.status == TimerStatus.Running ||
                state.status == TimerStatus.Paused ||
                state.status == TimerStatus.WaitingForNext)
        ) {
            val focusWord = context.getString(R.string.phase_focus)
            "$focusWord ${state.completedSessions + 1}/$sessionsBeforeLongBreak"
        } else {
            context.getString(state.phaseLabelRes)
        }

        val statusLabel = when (state.status) {
            TimerStatus.Paused -> context.getString(R.string.notification_status_paused)
            TimerStatus.WaitingForNext -> context.getString(R.string.notification_status_waiting)
            else -> context.getString(R.string.notification_status_running)
        }

        val spec = buildSpec(
            state = state,
            modeLabel = context.getString(state.mode.labelRes),
            phaseLabel = phaseLabel,
            statusLabel = statusLabel,
            taskTitle = taskTitle,
        )

        val collapsedRv = populateRemoteViews(
            RemoteViews(context.packageName, R.layout.notification_focus_timer_collapsed),
            spec = spec,
            includeProgressBar = false,
        )
        val expandedRv = populateRemoteViews(
            RemoteViews(context.packageName, R.layout.notification_focus_timer_expanded),
            spec = spec,
            includeProgressBar = true,
        )

        val builder = NotificationCompat.Builder(context, FocusTimerService.CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle(spec.title)
            .setContentText(spec.fallbackContentText)
            .setShowWhen(spec.showWhenInHeader)
            .setUsesChronometer(false)
            .setStyle(NotificationCompat.DecoratedCustomViewStyle())
            .setCustomContentView(collapsedRv)
            .setCustomBigContentView(expandedRv)
            .setCustomHeadsUpContentView(collapsedRv)
            .setContentIntent(openApp)
            .setOngoing(true)
            .setSilent(true)
            .setOnlyAlertOnce(true)
            .setCategory(NotificationCompat.CATEGORY_PROGRESS)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)

        when (state.status) {
            TimerStatus.Running -> builder.addAction(
                0,
                context.getString(R.string.btn_pause),
                servicePending(context, 1, FocusTimerService.ACTION_PAUSE),
            )
            TimerStatus.Paused -> builder.addAction(
                0,
                context.getString(R.string.btn_resume),
                servicePending(context, 2, FocusTimerService.ACTION_RESUME),
            )
            TimerStatus.WaitingForNext -> {
                val actionLabel = when (state.phase) {
                    FocusPhase.ShortBreak -> context.getString(R.string.btn_start_break)
                    FocusPhase.LongBreak -> context.getString(R.string.btn_start_long_break)
                    else -> context.getString(R.string.btn_start_focus)
                }
                builder.addAction(
                    0,
                    actionLabel,
                    servicePending(context, 2, FocusTimerService.ACTION_RESUME),
                )
            }
            else -> Unit
        }
        builder.addAction(
            0,
            context.getString(R.string.btn_stop),
            servicePending(context, 3, FocusTimerService.ACTION_STOP),
        )

        return builder.build()
    }

    private fun populateRemoteViews(
        rv: RemoteViews,
        spec: FocusNotificationSpec,
        includeProgressBar: Boolean,
    ): RemoteViews {
        rv.setTextViewText(R.id.notif_phase_title, spec.title)
        rv.setTextViewText(R.id.notif_task_subtitle, spec.subtitle)

        if (spec.isChronometerRunning) {
            rv.setViewVisibility(R.id.notif_chronometer, View.VISIBLE)
            rv.setViewVisibility(R.id.notif_static_time, View.GONE)
            rv.setChronometerCountDown(R.id.notif_chronometer, spec.isCountDown)
            rv.setChronometer(
                R.id.notif_chronometer,
                spec.chronometerBaseElapsedRealtime,
                null,
                true,
            )
        } else {
            rv.setViewVisibility(R.id.notif_chronometer, View.GONE)
            rv.setViewVisibility(R.id.notif_static_time, View.VISIBLE)
            rv.setTextViewText(R.id.notif_static_time, spec.staticTimeText)
        }

        if (includeProgressBar) {
            rv.setViewVisibility(
                R.id.notif_progress_bar,
                if (spec.showProgress) View.VISIBLE else View.GONE,
            )
            if (spec.showProgress) {
                rv.setProgressBar(R.id.notif_progress_bar, 1000, spec.progressPerMil, false)
            }
        }

        return rv
    }

    private fun servicePending(context: Context, code: Int, action: String): PendingIntent =
        PendingIntent.getService(
            context,
            code,
            Intent(context, FocusTimerService::class.java).apply { this.action = action },
            PendingIntent.FLAG_IMMUTABLE,
        )
}
