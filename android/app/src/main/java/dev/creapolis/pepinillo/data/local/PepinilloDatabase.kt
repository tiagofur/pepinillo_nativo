package dev.creapolis.pepinillo.data.local

import androidx.room.Database
import androidx.room.RoomDatabase
import dev.creapolis.pepinillo.data.local.dao.DailyStatsDao
import dev.creapolis.pepinillo.data.local.dao.FocusSessionDao
import dev.creapolis.pepinillo.data.local.dao.TaskDao
import dev.creapolis.pepinillo.data.local.entity.DailyStatsEntity
import dev.creapolis.pepinillo.data.local.entity.FocusSessionEntity
import dev.creapolis.pepinillo.data.local.entity.TaskEntity

@Database(
    entities = [
        TaskEntity::class,
        FocusSessionEntity::class,
        DailyStatsEntity::class,
    ],
    version = 1,
    exportSchema = false,
)
abstract class PepinilloDatabase : RoomDatabase() {
    abstract fun taskDao(): TaskDao
    abstract fun focusSessionDao(): FocusSessionDao
    abstract fun dailyStatsDao(): DailyStatsDao
}
