package dev.creapolis.pepinillo

import android.app.Application
import androidx.hilt.work.HiltWorkerFactory
import androidx.lifecycle.ProcessLifecycleOwner
import androidx.work.Configuration
import com.revenuecat.purchases.Purchases
import com.revenuecat.purchases.PurchasesConfiguration
import dagger.hilt.android.HiltAndroidApp
import dev.creapolis.pepinillo.data.sync.SyncLifecycleObserver
import dev.creapolis.pepinillo.data.sync.SyncWorker
import dev.creapolis.pepinillo.data.sync.WidgetRefreshWorker
import javax.inject.Inject

@HiltAndroidApp
class PepinilloApplication : Application(), Configuration.Provider {

    @Inject
    lateinit var workerFactory: HiltWorkerFactory

    @Inject
    lateinit var syncLifecycleObserver: SyncLifecycleObserver

    override val workManagerConfiguration: Configuration
        get() = Configuration.Builder()
            .setWorkerFactory(workerFactory)
            .build()

    override fun onCreate() {
        super.onCreate()

        // Initialize RevenueCat
        Purchases.configure(PurchasesConfiguration.Builder(this, BuildConfig.REVENUECAT_API_KEY).build())

        // Register lifecycle observer for WebSocket connect/disconnect
        ProcessLifecycleOwner.get().lifecycle.addObserver(syncLifecycleObserver)

        SyncWorker.schedule(this)
        WidgetRefreshWorker.schedule(this)
    }
}
