package dev.creapolis.pepinillo

import android.app.Application
import androidx.hilt.work.HiltWorkerFactory
import androidx.work.Configuration
import com.revenuecat.purchases.Purchases
import com.revenuecat.purchases.PurchasesConfiguration
import dagger.hilt.android.HiltAndroidApp
import dev.creapolis.pepinillo.data.sync.SyncWorker
import dev.creapolis.pepinillo.data.sync.WidgetRefreshWorker
import javax.inject.Inject

private const val REVENUECAT_API_KEY = "goog_ITPYSPEdubAzAeoNGxezZuZJELT"

@HiltAndroidApp
class PepinilloApplication : Application(), Configuration.Provider {

    @Inject
    lateinit var workerFactory: HiltWorkerFactory

    override val workManagerConfiguration: Configuration
        get() = Configuration.Builder()
            .setWorkerFactory(workerFactory)
            .build()

    override fun onCreate() {
        super.onCreate()

        // Initialize RevenueCat
        Purchases.configure(PurchasesConfiguration.Builder(this, REVENUECAT_API_KEY).build())

        SyncWorker.schedule(this)
        WidgetRefreshWorker.schedule(this)
    }
}
