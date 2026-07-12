package dev.creapolis.pepinillo.service

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import dagger.hilt.android.EntryPointAccessors
import dev.creapolis.pepinillo.data.sync.MidnightWidgetRefreshScheduler
import dev.creapolis.pepinillo.di.BootstrapEntryPoint
import dev.creapolis.pepinillo.widget.FocusTimerRecovery
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch

/**
 * Re-arms daily reminders and focus-timer recovery after reboot or app update.
 */
class BootCompletedReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED -> {
                val pendingResult = goAsync()
                CoroutineScope(Dispatchers.IO).launch {
                    try {
                        val entryPoint = EntryPointAccessors.fromApplication(
                            context.applicationContext,
                            BootstrapEntryPoint::class.java,
                        )
                        val prefs = entryPoint.userPreferencesRepository().preferences.first()
                        DailyReminderScheduler.restoreFromPreferences(context, prefs)
                        FocusTimerRecovery.restoreOnLaunch(context)
                        MidnightWidgetRefreshScheduler.schedule(context)
                    } finally {
                        pendingResult.finish()
                    }
                }
            }
        }
    }
}