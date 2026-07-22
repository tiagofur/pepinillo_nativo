package dev.creapolis.pepinillo.data.local.preferences

import android.content.Context
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.MutablePreferences
import androidx.datastore.preferences.core.Preferences
import dev.creapolis.pepinillo.data.local.dao.PreferenceSyncDao
import dev.creapolis.pepinillo.data.local.entity.PreferenceSyncEntity
import io.mockk.coEvery
import io.mockk.coVerify
import io.mockk.mockk
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.test.runTest
import org.junit.Before
import org.junit.Test

class UserPreferencesRepositoryTest {

    private lateinit var context: Context
    private lateinit var dataStore: DataStore<Preferences>
    private lateinit var preferenceSyncDao: PreferenceSyncDao
    private lateinit var repository: UserPreferencesRepository

    @Before
    fun setUp() {
        context = mockk(relaxed = true)
        dataStore = mockk(relaxed = true)
        preferenceSyncDao = mockk(relaxed = true)

        val prefsMock: Preferences = mockk(relaxed = true)
        coEvery { dataStore.data } returns flowOf(prefsMock)
        coEvery { dataStore.updateData(any()) } returns prefsMock

        repository = UserPreferencesRepository(context, preferenceSyncDao, dataStore)
    }

    @Test
    fun `updateFromSync upserts PreferenceSyncEntity with isDirty false and server timestamp`() = runTest {
        val serverTimestamp = 1750000000000L

        repository.updateFromSync("pomodoro_minutes", "35", serverTimestamp)

        coVerify {
            preferenceSyncDao.upsert(
                PreferenceSyncEntity(
                    key = "pomodoro_minutes",
                    updatedAt = serverTimestamp,
                    isDirty = false,
                )
            )
        }
    }

    @Test
    fun `updatePomodoroMinutes upserts PreferenceSyncEntity with isDirty true`() = runTest {
        repository.updatePomodoroMinutes(30)

        coVerify {
            preferenceSyncDao.upsert(
                match { entity ->
                    entity.key == "pomodoro_minutes" &&
                        entity.isDirty &&
                        entity.updatedAt > 0L
                }
            )
        }
    }
}
