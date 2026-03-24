package dev.creapolis.pepinillo.data.local.dao

import androidx.room.Dao
import androidx.room.Query
import androidx.room.Upsert
import dev.creapolis.pepinillo.data.local.entity.PreferenceSyncEntity

@Dao
interface PreferenceSyncDao {

    @Query("SELECT * FROM preference_sync_metadata WHERE is_dirty = 1")
    suspend fun getDirtyPreferences(): List<PreferenceSyncEntity>

    @Upsert
    suspend fun upsert(entity: PreferenceSyncEntity)

    @Upsert
    suspend fun upsertAll(entities: List<PreferenceSyncEntity>)

    @Query("UPDATE preference_sync_metadata SET is_dirty = 0 WHERE key = :key")
    suspend fun markSynced(key: String)

    @Query("UPDATE preference_sync_metadata SET is_dirty = 0")
    suspend fun markAllSynced()

    @Query("SELECT * FROM preference_sync_metadata WHERE key = :key")
    suspend fun getByKey(key: String): PreferenceSyncEntity?
}
