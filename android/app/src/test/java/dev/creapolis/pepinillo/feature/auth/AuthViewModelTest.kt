package dev.creapolis.pepinillo.feature.auth

import android.content.Context
import dev.creapolis.pepinillo.R
import dev.creapolis.pepinillo.core.auth.AuthStore
import dev.creapolis.pepinillo.core.auth.PostAuthFlowResult
import dev.creapolis.pepinillo.core.auth.SessionManager
import dev.creapolis.pepinillo.core.identity.IdentityManager
import dev.creapolis.pepinillo.core.network.AuthResponse
import dev.creapolis.pepinillo.core.network.NetworkResult
import dev.creapolis.pepinillo.core.network.PepinilloApiClient
import dev.creapolis.pepinillo.core.network.TokensDto
import dev.creapolis.pepinillo.core.network.UserDto
import io.mockk.coEvery
import io.mockk.coVerify
import io.mockk.every
import io.mockk.mockk
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class AuthViewModelTest {

    private lateinit var context: Context
    private lateinit var apiClient: PepinilloApiClient
    private lateinit var authStore: AuthStore
    private lateinit var identityManager: IdentityManager
    private lateinit var sessionManager: SessionManager
    private lateinit var viewModel: AuthViewModel

    private val testDispatcher = UnconfinedTestDispatcher()

    @Before
    fun setUp() {
        Dispatchers.setMain(testDispatcher)
        context = mockk(relaxed = true)
        apiClient = mockk(relaxed = true)
        authStore = mockk(relaxed = true)
        identityManager = mockk(relaxed = true)
        sessionManager = mockk(relaxed = true)

        // Default string mock — returns the key name so assertions are predictable
        every { context.getString(any()) } answers {
            val resId = firstArg<Int>()
            "string_$resId"
        }
        every { context.getString(any(), *anyVararg()) } answers {
            val resId = firstArg<Int>()
            "string_$resId"
        }
        every { authStore.getAccessToken() } returns null

        viewModel = AuthViewModel(
            context = context,
            apiClient = apiClient,
            authStore = authStore,
            identityManager = identityManager,
            sessionManager = sessionManager,
        )
    }

    @After
    fun tearDown() {
        Dispatchers.resetMain()
    }

    // -----------------------------------------------------------------------
    // Double-submit guard (#341)
    // -----------------------------------------------------------------------

    @Test
    fun `login while already loading does not fire second request`() = runTest {
        // Simulate an in-flight login that hasn't returned yet: the VM should set
        // isLoading=true synchronously before launching, and a second login() must
        // be a no-op while loading.
        val gate = kotlinx.coroutines.CompletableDeferred<Unit>()
        coEvery { apiClient.login(any(), any()) } coAnswers {
            gate.await() // hold the call open until we release it
            NetworkResult.Error(401, "invalid_credentials")
        }

        viewModel.login("a@b.com", "password")
        // The first login is now in-flight and isLoading is true.
        assertTrue(viewModel.uiState.value.isLoading)

        // Second call while loading — must be rejected by the synchronous guard.
        viewModel.login("a@b.com", "password")

        // Release the gate so the first call can complete.
        gate.complete(Unit)
        testDispatcher.scheduler.advanceUntilIdle()

        // Only ONE api call should have been made
        coVerify(exactly = 1) { apiClient.login(any(), any()) }
    }

    @Test
    fun `register while already loading does not fire second request`() = runTest {
        val gate = kotlinx.coroutines.CompletableDeferred<Unit>()
        coEvery { apiClient.register(any(), any(), any()) } coAnswers {
            gate.await()
            NetworkResult.Error(401, "err")
        }

        viewModel.register("Name", "a@b.com", "Password1")
        assertTrue(viewModel.uiState.value.isLoading)

        viewModel.register("Name", "a@b.com", "Password1")

        gate.complete(Unit)
        testDispatcher.scheduler.advanceUntilIdle()

        coVerify(exactly = 1) { apiClient.register(any(), any(), any()) }
    }

    // -----------------------------------------------------------------------
    // Verified vs unverified login (#336)
    // -----------------------------------------------------------------------

    @Test
    fun `verified login sets isAuthenticated true`() = runTest {
        val response = authResponse(emailVerified = true)
        coEvery { apiClient.login(any(), any()) } returns NetworkResult.Success(response)
        coEvery { sessionManager.completeAuthSuccess(response) } returns PostAuthFlowResult.Completed

        viewModel.login("a@b.com", "password")
        testDispatcher.scheduler.advanceUntilIdle()

        assertTrue(viewModel.uiState.value.isAuthenticated)
        assertNull(viewModel.uiState.value.emailVerificationRequired)
    }

    @Test
    fun `unverified login sets emailVerificationRequired and NOT isAuthenticated`() = runTest {
        val response = authResponse(emailVerified = false)
        coEvery { apiClient.login(any(), any()) } returns NetworkResult.Success(response)
        coEvery { sessionManager.completeAuthSuccess(response) } returns PostAuthFlowResult.Completed

        viewModel.login("a@b.com", "password")
        testDispatcher.scheduler.advanceUntilIdle()

        assertFalse(viewModel.uiState.value.isAuthenticated)
        assertEquals("test@test.com", viewModel.uiState.value.emailVerificationRequired)
    }

    // -----------------------------------------------------------------------
    // Verify path runs data pipeline (#335)
    // -----------------------------------------------------------------------

    @Test
    fun `verifyEmail delegates to completeAuthSuccessFromVerify which runs data pipeline`() = runTest {
        val verifyResponse = verifyEmailResponse()
        coEvery { apiClient.verifyEmail(any(), any()) } returns NetworkResult.Success(verifyResponse)
        coEvery {
            sessionManager.completeAuthSuccessFromVerify(any(), any())
        } returns PostAuthFlowResult.Completed

        viewModel.restoreEmailVerificationState("test@test.com")
        viewModel.verifyEmail("123456")
        testDispatcher.scheduler.advanceUntilIdle()

        // The key assertion for #335: SessionManager.completeAuthSuccessFromVerify IS called
        coVerify { sessionManager.completeAuthSuccessFromVerify(any(), any()) }
        assertTrue(viewModel.uiState.value.isAuthenticated)
    }

    // -----------------------------------------------------------------------
    // mapAuthError does not surface raw server messages (#342)
    // -----------------------------------------------------------------------

    @Test
    fun `mapAuthError on unknown error does not include raw server message`() = runTest {
        val rawMessage = "INTERNAL_DATABASE_EXPLOSION_QUERY_FAILED_SQLITE_ERROR"
        coEvery { apiClient.login(any(), any()) } returns NetworkResult.Error(500, rawMessage)

        viewModel.login("a@b.com", "password")
        testDispatcher.scheduler.advanceUntilIdle()

        val error = viewModel.uiState.value.error
        // The generic error string should NOT contain the raw backend message
        assertFalse("Error must not contain raw server message", error!!.contains(rawMessage))
    }

    // -----------------------------------------------------------------------
    // Resend cooldown (#344)
    // -----------------------------------------------------------------------

    @Test
    fun `resend sets cooldown after success and blocks second resend`() = runTest {
        coEvery { apiClient.resendVerificationEmail(any()) } returns NetworkResult.Success(Unit)

        viewModel.restoreEmailVerificationState("test@test.com")
        viewModel.resendVerificationEmail()
        testDispatcher.scheduler.advanceUntilIdle()

        assertTrue(viewModel.uiState.value.resendCooldownUntil > 0)

        // Second resend within cooldown — should NOT call the API again
        viewModel.resendVerificationEmail()
        testDispatcher.scheduler.advanceUntilIdle()

        coVerify(exactly = 1) { apiClient.resendVerificationEmail(any()) }
    }

    // -----------------------------------------------------------------------
    // Logout delegates to SessionManager (#333, #351)
    // -----------------------------------------------------------------------

    @Test
    fun `logout delegates to sessionManager signOut`() = runTest {
        coEvery { sessionManager.signOut() } returns Unit

        viewModel.logout()
        testDispatcher.scheduler.advanceUntilIdle()

        coVerify { sessionManager.signOut() }
        assertFalse(viewModel.uiState.value.isAuthenticated)
    }

    // -----------------------------------------------------------------------
    // Empty-field validation
    // -----------------------------------------------------------------------

    @Test
    fun `login with blank fields shows error without calling API`() = runTest {
        viewModel.login("", "password")
        testDispatcher.scheduler.advanceUntilIdle()

        assertEquals("string_${R.string.auth_error_fill_all_fields}", viewModel.uiState.value.error)
        coVerify(exactly = 0) { apiClient.login(any(), any()) }
    }

    @Test
    fun `register with blank password shows error without calling API`() = runTest {
        viewModel.register("Name", "a@b.com", "")
        testDispatcher.scheduler.advanceUntilIdle()

        assertNotNull(viewModel.uiState.value.error)
        coVerify(exactly = 0) { apiClient.register(any(), any(), any()) }
    }

    // -----------------------------------------------------------------------
    // Helpers
    // -----------------------------------------------------------------------

    private fun assertNotNull(value: Any?) {
        org.junit.Assert.assertNotNull(value)
    }

    private fun authResponse(emailVerified: Boolean) = AuthResponse(
        user = userDto(emailVerified),
        tokens = TokensDto("access", "refresh"),
    )

    private fun userDto(emailVerified: Boolean) = UserDto(
        id = "user-1",
        email = "test@test.com",
        name = "Test",
        emailVerified = emailVerified,
    )

    private fun verifyEmailResponse() = dev.creapolis.pepinillo.core.network.VerifyEmailResponse(
        message = "verified",
        user = userDto(emailVerified = true),
        tokens = TokensDto("access", "refresh"),
    )
}
