package dev.creapolis.pepinillo.data.sync

import dev.creapolis.pepinillo.core.network.NetworkResult
import dev.creapolis.pepinillo.core.network.PepinilloApiClient
import dev.creapolis.pepinillo.core.network.PreferenceSyncItem
import dev.creapolis.pepinillo.core.network.PreferenceSyncResponse
import dev.creapolis.pepinillo.data.local.dao.PreferenceSyncDao
import dev.creapolis.pepinillo.data.local.entity.PreferenceSyncEntity
import dev.creapolis.pepinillo.data.local.preferences.UserPreferences
import dev.creapolis.pepinillo.data.local.preferences.UserPreferencesRepository
import io.mockk.coEvery
import io.mockk.coVerify
import io.mockk.every
import io.mockk.mockk
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

class SettingsSyncEngineTest {

    private lateinit var preferenceSyncDao: PreferenceSyncDao
    private lateinit var userPreferencesRepository: UserPreferencesRepository
    private lateinit var apiClient: PepinilloApiClient
    private lateinit var syncLock: SyncLock
    private lateinit var engine: SettingsSyncEngine

    @Before
    fun setUp() {
        preferenceSyncDao = mockk(relaxed = true)
        userPreferencesRepository = mockk(relaxed = true)
        apiClient = mockk(relaxed = true)
        syncLock = SyncLock()

        every { userPreferencesRepository.preferences } returns flowOf(UserPreferences())

        engine = SettingsSyncEngine(
            preferenceSyncDao = preferenceSyncDao,
            userPreferencesRepository = userPreferencesRepository,
            apiClient = apiClient,
            syncLock = syncLock,
        )
    }

    // -----------------------------------------------------------------------
    // syncableKeys filtering
    // -----------------------------------------------------------------------

    @Test
    fun `only syncable keys are pushed, device-specific excluded`() = runTest {
        // Dirty prefs include both syncable and device-specific keys
        val dirtyPrefs = listOf(
            PreferenceSyncEntity(key = "pomodoro_minutes", updatedAt = 1000L, isDirty = true),
            PreferenceSyncEntity(key = "onboarding_completed", updatedAt = 1000L, isDirty = true),
            PreferenceSyncEntity(key = "daily_reminder_enabled", updatedAt = 1000L, isDirty = true),
        )
        coEvery { preferenceSyncDao.getDirtyPreferences() } returns dirtyPrefs

        val serverResponse = PreferenceSyncResponse(
            preferences = emptyList(),
            serverTimestamp = "2025-01-01T00:00:00Z",
        )
        coEvery { apiClient.upsertPreferences(any()) } returns NetworkResult.Success(serverResponse)

        val result = engine.syncSettings()
        assertTrue(result.isSuccess)

        // Verify upsertPreferences was called with only the syncable key
        coVerify {
            apiClient.upsertPreferences(match { request ->
                request.preferences.size == 1 &&
                    request.preferences[0].key == "pomodoro_minutes"
            })
        }
    }

    // -----------------------------------------------------------------------
    // dirty preferences collected and sent
    // -----------------------------------------------------------------------

    @Test
    fun `dirty preferences are collected and sent`() = runTest {
        val dirtyPrefs = listOf(
            PreferenceSyncEntity(key = "pomodoro_minutes", updatedAt = 1000L, isDirty = true),
            PreferenceSyncEntity(key = "sound_enabled", updatedAt = 2000L, isDirty = true),
        )
        coEvery { preferenceSyncDao.getDirtyPreferences() } returns dirtyPrefs

        val serverResponse = PreferenceSyncResponse(
            preferences = emptyList(),
            serverTimestamp = "2025-01-01T00:00:00Z",
        )
        coEvery { apiClient.upsertPreferences(any()) } returns NetworkResult.Success(serverResponse)

        val result = engine.syncSettings()
        assertTrue(result.isSuccess)

        coVerify {
            apiClient.upsertPreferences(match { request ->
                request.preferences.size == 2 &&
                    request.preferences.any { it.key == "pomodoro_minutes" && it.value == "25" } &&
                    request.preferences.any { it.key == "sound_enabled" && it.value == "true" }
            })
        }
    }

    // -----------------------------------------------------------------------
    // applyServerPreferences -- newer values update local
    // -----------------------------------------------------------------------

    @Test
    fun `server response with newer values updates local preferences`() = runTest {
        val serverPrefs = listOf(
            PreferenceSyncItem(
                key = "pomodoro_minutes",
                value = "30",
                updatedAt = "2025-06-15T12:00:00Z",
            ),
        )

        // Local record is older
        coEvery { preferenceSyncDao.getByKey("pomodoro_minutes") } returns
            PreferenceSyncEntity(key = "pomodoro_minutes", updatedAt = 1000L, isDirty = false)

        engine.applyServerPreferences(serverPrefs)

        coVerify { userPreferencesRepository.updateFromSync("pomodoro_minutes", "30", any()) }
    }

    // -----------------------------------------------------------------------
    // applyServerPreferences -- older values don't overwrite local
    // -----------------------------------------------------------------------

    @Test
    fun `server response with older values does not overwrite local`() = runTest {
        val serverPrefs = listOf(
            PreferenceSyncItem(
                key = "pomodoro_minutes",
                value = "30",
                updatedAt = "2020-01-01T00:00:00Z", // very old
            ),
        )

        // Local record is much newer
        coEvery { preferenceSyncDao.getByKey("pomodoro_minutes") } returns
            PreferenceSyncEntity(
                key = "pomodoro_minutes",
                updatedAt = System.currentTimeMillis(),
                isDirty = false,
            )

        engine.applyServerPreferences(serverPrefs)

        coVerify(exactly = 0) { userPreferencesRepository.updateFromSync(any(), any(), any()) }
    }

    // -----------------------------------------------------------------------
    // markSyncedIfUnchanged after success
    // -----------------------------------------------------------------------

    @Test
    fun `pushed preferences marked synced if unchanged after successful sync`() = runTest {
        val dirtyPrefs = listOf(
            PreferenceSyncEntity(key = "pomodoro_minutes", updatedAt = 1000L, isDirty = true),
        )
        coEvery { preferenceSyncDao.getDirtyPreferences() } returns dirtyPrefs

        val serverResponse = PreferenceSyncResponse(
            preferences = emptyList(),
            serverTimestamp = "2025-01-01T00:00:00Z",
        )
        coEvery { apiClient.upsertPreferences(any()) } returns NetworkResult.Success(serverResponse)

        engine.syncSettings()

        coVerify { preferenceSyncDao.markSyncedIfUnchanged("pomodoro_minutes", 1000L) }
    }

    // -----------------------------------------------------------------------
    // auth failure propagation
    // -----------------------------------------------------------------------

    @Test
    fun `auth failure propagated correctly`() = runTest {
        val dirtyPrefs = listOf(
            PreferenceSyncEntity(key = "pomodoro_minutes", updatedAt = 1000L, isDirty = true),
        )
        coEvery { preferenceSyncDao.getDirtyPreferences() } returns dirtyPrefs
        coEvery { apiClient.upsertPreferences(any()) } returns NetworkResult.Error(401, "Unauthorized")

        val result = engine.syncSettings()
        assertTrue(result.isFailure)
        assertTrue(result.exceptionOrNull() is AuthenticationException)
    }

    // -----------------------------------------------------------------------
    // no dirty preferences pulls from server
    // -----------------------------------------------------------------------

    @Test
    fun `no dirty preferences triggers pull from server`() = runTest {
        coEvery { preferenceSyncDao.getDirtyPreferences() } returns emptyList()

        val serverResponse = PreferenceSyncResponse(
            preferences = listOf(
                PreferenceSyncItem(
                    key = "pomodoro_minutes",
                    value = "30",
                    updatedAt = "2025-06-15T12:00:00Z",
                ),
            ),
            serverTimestamp = "2025-06-15T12:00:00Z",
        )
        coEvery { apiClient.getPreferences() } returns NetworkResult.Success(serverResponse)
        coEvery { preferenceSyncDao.getByKey(any()) } returns null

        val result = engine.syncSettings()
        assertTrue(result.isSuccess)

        coVerify { apiClient.getPreferences() }
        coVerify { userPreferencesRepository.updateFromSync("pomodoro_minutes", "30", any()) }
    }

    @Test
    fun `applyServerPreferences applies preference when server updatedAt is unparseable and local is not dirty`() = runTest {
        val localPref = PreferenceSyncEntity(
            key = "pomodoro_minutes",
            updatedAt = 1000L,
            isDirty = false,
        )
        coEvery { preferenceSyncDao.getByKey("pomodoro_minutes") } returns localPref

        val serverItem = PreferenceSyncItem(
            key = "pomodoro_minutes",
            value = "45",
            updatedAt = "malformed-date",
        )

        engine.applyServerPreferences(listOf(serverItem))

        coVerify { userPreferencesRepository.updateFromSync("pomodoro_minutes", "45", any()) }
    }

    @Test
    fun `non syncable dirty preference only marks that key synced if unchanged without calling markAllSynced`() = runTest {
        val dirtyPrefs = listOf(
            PreferenceSyncEntity(key = "onboarding_completed", updatedAt = 1500L, isDirty = true),
        )
        coEvery { preferenceSyncDao.getDirtyPreferences() } returns dirtyPrefs

        val result = engine.syncSettings()
        assertTrue(result.isSuccess)

        coVerify { preferenceSyncDao.markSyncedIfUnchanged("onboarding_completed", 1500L) }
        coVerify(exactly = 0) { preferenceSyncDao.markAllSynced() }
        coVerify(exactly = 0) { apiClient.upsertPreferences(any()) }
    }

    @Test
    fun `multiple dirty preferences mark only pushed keys with their respective snapshot timestamps`() = runTest {
        val dirtyPrefs = listOf(
            PreferenceSyncEntity(key = "pomodoro_minutes", updatedAt = 1000L, isDirty = true),
            PreferenceSyncEntity(key = "sound_enabled", updatedAt = 2000L, isDirty = true),
        )
        coEvery { preferenceSyncDao.getDirtyPreferences() } returns dirtyPrefs

        val serverResponse = PreferenceSyncResponse(
            preferences = emptyList(),
            serverTimestamp = "2025-01-01T00:00:00Z",
        )
        coEvery { apiClient.upsertPreferences(any()) } returns NetworkResult.Success(serverResponse)

        engine.syncSettings()

        coVerify { preferenceSyncDao.markSyncedIfUnchanged("pomodoro_minutes", 1000L) }
        coVerify { preferenceSyncDao.markSyncedIfUnchanged("sound_enabled", 2000L) }
        coVerify(exactly = 0) { preferenceSyncDao.markAllSynced() }
    }
}
