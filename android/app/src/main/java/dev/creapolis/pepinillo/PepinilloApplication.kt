package dev.creapolis.pepinillo

import android.app.Application
import androidx.hilt.work.HiltWorkerFactory
import androidx.work.Configuration
import dagger.hilt.android.HiltAndroidApp
import dev.creapolis.pepinillo.data.sync.SyncWorker
import dev.creapolis.pepinillo.data.sync.WidgetRefreshWorker
import javax.inject.Inject

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
        SyncWorker.schedule(this)
        WidgetRefreshWorker.schedule(this)
    }
}
