package dev.creapolis.pepinillo.di

import android.content.Context
import androidx.room.Room
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.android.qualifiers.ApplicationContext
import dagger.hilt.components.SingletonComponent
import dev.creapolis.pepinillo.data.local.PepinilloDatabase
import dev.creapolis.pepinillo.data.local.dao.DailyStatsDao
import dev.creapolis.pepinillo.data.local.dao.FocusSessionDao
import dev.creapolis.pepinillo.data.local.dao.ProductivityReportDao
import dev.creapolis.pepinillo.data.local.dao.SubtaskDao
import dev.creapolis.pepinillo.data.local.dao.TaskDao
import javax.inject.Singleton

@Module
@InstallIn(SingletonComponent::class)
object DatabaseModule {

    @Provides
    @Singleton
    fun provideDatabase(@ApplicationContext context: Context): PepinilloDatabase {
        return Room.databaseBuilder(
            context,
            PepinilloDatabase::class.java,
            "pepinillo.db",
        )
            .addMigrations(
                PepinilloDatabase.MIGRATION_1_2,
                PepinilloDatabase.MIGRATION_2_3,
                PepinilloDatabase.MIGRATION_3_4,
                PepinilloDatabase.MIGRATION_4_5,
            )
            .build()
    }

    @Provides
    fun provideTaskDao(db: PepinilloDatabase): TaskDao = db.taskDao()

    @Provides
    fun provideFocusSessionDao(db: PepinilloDatabase): FocusSessionDao = db.focusSessionDao()

    @Provides
    fun provideDailyStatsDao(db: PepinilloDatabase): DailyStatsDao = db.dailyStatsDao()

    @Provides
    fun provideSubtaskDao(db: PepinilloDatabase): SubtaskDao = db.subtaskDao()

    @Provides
    fun provideProductivityReportDao(db: PepinilloDatabase): ProductivityReportDao = db.productivityReportDao()
}
