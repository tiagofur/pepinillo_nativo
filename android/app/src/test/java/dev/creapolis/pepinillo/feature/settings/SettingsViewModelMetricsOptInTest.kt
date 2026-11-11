package dev.creapolis.pepinillo.feature.settings

import android.content.Context
import dev.creapolis.pepinillo.core.auth.AuthStore
import dev.creapolis.pepinillo.core.billing.FeatureGate
import dev.creapolis.pepinillo.core.billing.SubscriptionState
import dev.creapolis.pepinillo.core.network.NetworkModule
import dev.creapolis.pepinillo.core.network.NetworkResult
import dev.creapolis.pepinillo.core.network.PepinilloApiClient
import dev.creapolis.pepinillo.core.network.UpdateProfileRequest
import dev.creapolis.pepinillo.core.network.UserDto
import dev.creapolis.pepinillo.data.local.dao.UserDao
import dev.creapolis.pepinillo.data.local.preferences.UserPreferences
import dev.creapolis.pepinillo.data.local.preferences.UserPreferencesRepository
import dev.creapolis.pepinillo.data.repository.SessionRepository
import dev.creapolis.pepinillo.data.repository.UserRepository
import dev.creapolis.pepinillo.data.sync.SyncState
import dev.creapolis.pepinillo.data.sync.SyncStatusManager
import io.mockk.coEvery
import io.mockk.coVerify
import io.mockk.every
import io.mockk.mockk
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import kotlinx.serialization.encodeToString
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class SettingsViewModelMetricsOptInTest {

    private lateinit var context: Context
    private lateinit var prefsRepo: UserPreferencesRepository
    private lateinit var sessionRepository: SessionRepository
    private lateinit var featureGate: FeatureGate
    private lateinit var syncStatusManager: SyncStatusManager
    private lateinit var authStore: AuthStore
    private lateinit var userDao: UserDao
    private lateinit var apiClient: PepinilloApiClient
    private lateinit var userRepository: UserRepository

    private val isLoggedInFlow = MutableStateFlow(false)
    private val testDispatcher = UnconfinedTestDispatcher()

    @Before
    fun setUp() {
        Dispatchers.setMain(testDispatcher)
        context = mockk(relaxed = true)
        prefsRepo = mockk(relaxed = true)
        sessionRepository = mockk(relaxed = true)
        featureGate = mockk(relaxed = true)
        syncStatusManager = mockk(relaxed = true)
        authStore = mockk(relaxed = true)
        userDao = mockk(relaxed = true)
        apiClient = mockk(relaxed = true)

        every { prefsRepo.preferences } returns flowOf(UserPreferences())
        every { sessionRepository.getAllDaysWithSessions() } returns flowOf(emptyList())
        every { featureGate.subscriptionState } returns MutableStateFlow(SubscriptionState())
        every { syncStatusManager.isOnline } returns MutableStateFlow(true)
        every { syncStatusManager.syncState } returns MutableStateFlow(SyncState.Idle)
        every { syncStatusManager.lastSyncAt } returns MutableStateFlow(null)
        every { syncStatusManager.pendingChangesCount } returns MutableStateFlow(0)
        every { authStore.isLoggedIn } returns isLoggedInFlow

        userRepository = UserRepository(
            userDao = userDao,
            apiClient = apiClient,
            authStore = authStore,
        )
    }

    @After
    fun tearDown() {
        Dispatchers.resetMain()
    }

    private fun createViewModel(): SettingsViewModel = SettingsViewModel(
        context = context,
        prefsRepo = prefsRepo,
        sessionRepository = sessionRepository,
        featureGate = featureGate,
        syncStatusManager = syncStatusManager,
        authStore = authStore,
        userRepository = userRepository,
    )

    @Test
    fun `default metricsOptIn is false when logged out and loads server value when logged in`() = runTest {
        coEvery { apiClient.getMe() } returns NetworkResult.Success(
            UserDto(
                id = "user-1",
                email = "ada@example.com",
                name = "Ada",
                metricsOptIn = true,
            ),
        )

        val viewModel = createViewModel()
        assertFalse(viewModel.uiState.value.metricsOptIn)

        isLoggedInFlow.value = true
        testDispatcher.scheduler.advanceUntilIdle()

        assertTrue(viewModel.uiState.value.metricsOptIn)
        coVerify(exactly = 1) { apiClient.getMe() }
    }

    @Test
    fun `setMetricsOptIn true optimistically updates and persists via PUT users me`() = runTest {
        coEvery { apiClient.getMe() } returns NetworkResult.Success(
            UserDto(
                id = "user-1",
                email = "ada@example.com",
                name = "Ada",
                metricsOptIn = false,
            ),
        )
        val gate = CompletableDeferred<NetworkResult<UserDto>>()
        coEvery { apiClient.updateMe(UpdateProfileRequest(metricsOptIn = true)) } coAnswers {
            gate.await()
        }

        isLoggedInFlow.value = true
        val viewModel = createViewModel()
        assertFalse(viewModel.uiState.value.metricsOptIn)

        viewModel.setMetricsOptIn(true)
        // Optimistic state while request is in-flight
        assertTrue(viewModel.uiState.value.metricsOptIn)
        assertTrue(viewModel.uiState.value.isUpdatingMetricsOptIn)
        assertNull(viewModel.uiState.value.metricsOptInError)

        gate.complete(
            NetworkResult.Success(
                UserDto(
                    id = "user-1",
                    email = "ada@example.com",
                    name = "Ada",
                    metricsOptIn = true,
                ),
            ),
        )
        testDispatcher.scheduler.advanceUntilIdle()

        assertTrue(viewModel.uiState.value.metricsOptIn)
        assertFalse(viewModel.uiState.value.isUpdatingMetricsOptIn)
        assertNull(viewModel.uiState.value.metricsOptInError)
        coVerify(exactly = 1) { apiClient.updateMe(UpdateProfileRequest(metricsOptIn = true)) }
    }

    @Test
    fun `setMetricsOptIn reverts optimistic value and populates error when updateProfile fails`() = runTest {
        coEvery { apiClient.getMe() } returns NetworkResult.Success(
            UserDto(
                id = "user-1",
                email = "ada@example.com",
                name = "Ada",
                metricsOptIn = false,
            ),
        )
        coEvery {
            apiClient.updateMe(UpdateProfileRequest(metricsOptIn = true))
        } returns NetworkResult.Error(500, "internal_error")

        isLoggedInFlow.value = true
        val viewModel = createViewModel()
        assertFalse(viewModel.uiState.value.metricsOptIn)

        viewModel.setMetricsOptIn(true)
        testDispatcher.scheduler.advanceUntilIdle()

        assertFalse(viewModel.uiState.value.metricsOptIn)
        assertFalse(viewModel.uiState.value.isUpdatingMetricsOptIn)
        assertNotNull(viewModel.uiState.value.metricsOptInError)
    }

    @Test
    fun `setMetricsOptIn is a no-op when user is not logged in`() = runTest {
        isLoggedInFlow.value = false
        val viewModel = createViewModel()

        viewModel.setMetricsOptIn(true)
        testDispatcher.scheduler.advanceUntilIdle()

        assertFalse(viewModel.uiState.value.metricsOptIn)
        coVerify(exactly = 0) { apiClient.updateMe(any()) }
    }

    @Test
    fun `routine UpdateProfileRequest omits metricsOptIn while explicit toggle serializes it`() {
        val json = NetworkModule.provideJson()

        val routineEncoded = json.encodeToString(
            UpdateProfileRequest(name = "Ada", imageUrl = "https://example.com/a.png"),
        )
        assertFalse(
            "Routine profile update must NOT include metricsOptIn: $routineEncoded",
            routineEncoded.contains("metricsOptIn"),
        )

        val optInEncoded = json.encodeToString(UpdateProfileRequest(metricsOptIn = true))
        assertEquals("""{"metricsOptIn":true}""", optInEncoded)

        val optOutEncoded = json.encodeToString(UpdateProfileRequest(metricsOptIn = false))
        assertEquals("""{"metricsOptIn":false}""", optOutEncoded)
    }
}
