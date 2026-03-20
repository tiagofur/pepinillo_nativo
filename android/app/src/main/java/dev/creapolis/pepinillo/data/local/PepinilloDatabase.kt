package dev.creapolis.pepinillo.data.local

import androidx.room.Database
import androidx.room.RoomDatabase
import androidx.room.migration.Migration
import androidx.sqlite.db.SupportSQLiteDatabase
import dev.creapolis.pepinillo.data.local.dao.DailyStatsDao
import dev.creapolis.pepinillo.data.local.dao.FocusSessionDao
import dev.creapolis.pepinillo.data.local.dao.ProductivityReportDao
import dev.creapolis.pepinillo.data.local.dao.SubtaskDao
import dev.creapolis.pepinillo.data.local.dao.TaskDao
import dev.creapolis.pepinillo.data.local.entity.DailyStatsEntity
import dev.creapolis.pepinillo.data.local.entity.FocusSessionEntity
import dev.creapolis.pepinillo.data.local.entity.ProductivityReportEntity
import dev.creapolis.pepinillo.data.local.entity.SubtaskEntity
import dev.creapolis.pepinillo.data.local.entity.TaskEntity

@Database(
    entities = [
        TaskEntity::class,
        FocusSessionEntity::class,
        DailyStatsEntity::class,
        SubtaskEntity::class,
        ProductivityReportEntity::class,
    ],
    version = 5,
    exportSchema = false,
)
abstract class PepinilloDatabase : RoomDatabase() {
    abstract fun taskDao(): TaskDao
    abstract fun focusSessionDao(): FocusSessionDao
    abstract fun dailyStatsDao(): DailyStatsDao
    abstract fun subtaskDao(): SubtaskDao
    abstract fun productivityReportDao(): ProductivityReportDao

    companion object {
        val MIGRATION_4_5 = object : Migration(4, 5) {
            override fun migrate(db: SupportSQLiteDatabase) {
                db.execSQL("""
                    CREATE TABLE IF NOT EXISTS productivity_reports (
                        id TEXT NOT NULL PRIMARY KEY,
                        period TEXT NOT NULL,
                        period_start INTEGER NOT NULL,
                        period_end INTEGER NOT NULL,
                        generated_at INTEGER NOT NULL,
                        title TEXT NOT NULL,
                        highlights TEXT NOT NULL,
                        insights TEXT NOT NULL,
                        recommendations TEXT NOT NULL,
                        raw_payload TEXT NOT NULL
                    )
                """.trimIndent())
            }
        }

        val MIGRATION_3_4 = object : Migration(3, 4) {
            override fun migrate(db: SupportSQLiteDatabase) {
                db.execSQL("ALTER TABLE focus_sessions ADD COLUMN was_completed INTEGER NOT NULL DEFAULT 1")
                db.execSQL("ALTER TABLE focus_sessions ADD COLUMN interruptions INTEGER NOT NULL DEFAULT 0")
                db.execSQL("ALTER TABLE focus_sessions ADD COLUMN pause_count INTEGER NOT NULL DEFAULT 0")
                db.execSQL("ALTER TABLE focus_sessions ADD COLUMN total_pause_millis INTEGER NOT NULL DEFAULT 0")
                db.execSQL("ALTER TABLE focus_sessions ADD COLUMN pomodoro_number INTEGER DEFAULT NULL")
                db.execSQL("ALTER TABLE focus_sessions ADD COLUMN journal_note TEXT DEFAULT NULL")
                db.execSQL("ALTER TABLE focus_sessions ADD COLUMN satisfaction_rating INTEGER DEFAULT NULL")
                db.execSQL("ALTER TABLE focus_sessions ADD COLUMN target_duration_millis INTEGER DEFAULT NULL")
            }
        }

        val MIGRATION_2_3 = object : Migration(2, 3) {
            override fun migrate(db: SupportSQLiteDatabase) {
                db.execSQL("ALTER TABLE tasks ADD COLUMN due_date INTEGER DEFAULT NULL")
                db.execSQL("ALTER TABLE tasks ADD COLUMN scheduled_for_today INTEGER NOT NULL DEFAULT 0")
                db.execSQL("ALTER TABLE tasks ADD COLUMN recurrence_rule TEXT DEFAULT NULL")
                db.execSQL("ALTER TABLE tasks ADD COLUMN next_occurrence INTEGER DEFAULT NULL")
                db.execSQL("ALTER TABLE tasks ADD COLUMN is_recurring_template INTEGER NOT NULL DEFAULT 0")
                db.execSQL("ALTER TABLE tasks ADD COLUMN recurring_template_id TEXT DEFAULT NULL")
            }
        }

        val MIGRATION_1_2 = object : Migration(1, 2) {
            override fun migrate(db: SupportSQLiteDatabase) {
                // Add sync columns to tasks
                db.execSQL("ALTER TABLE tasks ADD COLUMN server_id INTEGER DEFAULT NULL")
                db.execSQL("ALTER TABLE tasks ADD COLUMN is_dirty INTEGER NOT NULL DEFAULT 1")
                db.execSQL("ALTER TABLE tasks ADD COLUMN is_deleted INTEGER NOT NULL DEFAULT 0")
                db.execSQL("ALTER TABLE tasks ADD COLUMN synced_at INTEGER DEFAULT NULL")

                // Add sync columns to focus_sessions
                db.execSQL("ALTER TABLE focus_sessions ADD COLUMN is_dirty INTEGER NOT NULL DEFAULT 1")
                db.execSQL("ALTER TABLE focus_sessions ADD COLUMN synced_at INTEGER DEFAULT NULL")

                // Create subtasks table
                db.execSQL("""
                    CREATE TABLE IF NOT EXISTS subtasks (
                        id TEXT NOT NULL PRIMARY KEY,
                        task_id TEXT NOT NULL,
                        title TEXT NOT NULL,
                        is_completed INTEGER NOT NULL DEFAULT 0,
                        sort_order INTEGER NOT NULL DEFAULT 0,
                        is_dirty INTEGER NOT NULL DEFAULT 1,
                        FOREIGN KEY (task_id) REFERENCES tasks(id) ON DELETE CASCADE
                    )
                """.trimIndent())
                db.execSQL("CREATE INDEX IF NOT EXISTS index_subtasks_task_id ON subtasks(task_id)")
            }
        }
    }
}
