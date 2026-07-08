package dev.creapolis.pepinillo

import android.app.Application
import androidx.hilt.work.HiltWorkerFactory
import androidx.lifecycle.ProcessLifecycleOwner
import androidx.work.Configuration
import com.revenuecat.purchases.Purchases
import com.revenuecat.purchases.PurchasesConfiguration
import dagger.hilt.android.HiltAndroidApp
import dev.creapolis.pepinillo.data.local.preferences.UserPreferencesRepository
import dev.creapolis.pepinillo.data.sync.SyncLifecycleObserver
import dev.creapolis.pepinillo.data.sync.SyncWorker
import dev.creapolis.pepinillo.data.sync.WidgetRefreshWorker
import dev.creapolis.pepinillo.ui.theme.ThemeController
import dev.creapolis.pepinillo.ui.theme.ThemeMode
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch
import kotlinx.coroutines.withTimeoutOrNull
import javax.inject.Inject

@HiltAndroidApp
class PepinilloApplication : Application(), Configuration.Provider {

    private companion object {
        /** Upper bound on how long the launch splash waits for persisted theme prefs. */
        const val THEME_SEED_TIMEOUT_MS = 1500L
    }

    @Inject
    lateinit var workerFactory: HiltWorkerFactory

    @Inject
    lateinit var syncLifecycleObserver: SyncLifecycleObserver

    @Inject
    lateinit var prefsRepository: UserPreferencesRepository

    private val appScope = CoroutineScope(SupervisorJob() + Dispatchers.Default)

    override val workManagerConfiguration: Configuration
        get() = Configuration.Builder()
            .setWorkerFactory(workerFactory)
            .build()

    override fun onCreate() {
        super.onCreate()

        // Initialize RevenueCat
        Purchases.configure(PurchasesConfiguration.Builder(this, BuildConfig.REVENUECAT_API_KEY).build())

        // Seed theme state from persisted preferences BEFORE MainActivity applies it,
        // so users with a non-default theme don't see a flash of the default scheme on cold start.
        // MainActivity keeps the splash on-screen until ThemeController.isSeeded is true.
        appScope.launch {
            // Time-bounded: even if DataStore is slow/unavailable, never leave the splash
            // stuck — fall back to defaults (isSeeded flips either way).
            val prefs = runCatching {
                withTimeoutOrNull(THEME_SEED_TIMEOUT_MS) { prefsRepository.preferences.first() }
            }.getOrNull()
            ThemeController.seedFrom(
                mode = prefs?.themeMode ?: ThemeMode.System,
                dynamic = prefs?.dynamicColor ?: true,
                themeId = prefs?.selectedTheme ?: "materialYou",
            )
        }

        // Register lifecycle observer for WebSocket connect/disconnect
        ProcessLifecycleOwner.get().lifecycle.addObserver(syncLifecycleObserver)

        SyncWorker.schedule(this)
        WidgetRefreshWorker.schedule(this)
    }
}
