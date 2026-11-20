package dev.creapolis.pepinillo.feature.auth

import dev.creapolis.pepinillo.R
import dev.creapolis.pepinillo.core.billing.SubscriptionManager
import dev.creapolis.pepinillo.core.network.NetworkResult
import dev.creapolis.pepinillo.core.network.PepinilloApiClient
import dev.creapolis.pepinillo.core.network.RcLinkRequest
import dev.creapolis.pepinillo.core.network.RcLinkResponse
import io.mockk.coEvery
import io.mockk.coVerify
import io.mockk.mockk
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

/**
 * #953 RC license bridge ViewModel: claim success + identity handover,
 * 404/409 error mapping, short-code guard, empty app_user_id pre-check.
 */
@OptIn(ExperimentalCoroutinesApi::class)
class RcLinkViewModelTest {

    private val apiClient: PepinilloApiClient = mockk(relaxed = true)
    private val subscriptionManager: SubscriptionManager = mockk(relaxed = true)
    private val dispatcher = StandardTestDispatcher()

    @Before
    fun setUp() {
        Dispatchers.setMain(dispatcher)
        coEvery { subscriptionManager.currentAppUserId() } returns "\$RCAnonymousID:abc"
    }

    @After
    fun tearDown() {
        Dispatchers.resetMain()
    }

    private fun viewModel(): RcLinkViewModel = RcLinkViewModel(apiClient, subscriptionManager)

    private fun response(
        userId: String = "11111111-1111-1111-1111-111111111111",
        email: String = "t***@gmail.com",
    ) = RcLinkResponse(userId = userId, tier = "pepinillo_plus", email = email)

    @Test
    fun `code sanitizes digits and caps at six`() = runTest(dispatcher) {
        val vm = viewModel()
        vm.onCodeChange("12a3 45-6789")
        assertEquals("123456", vm.uiState.value.code)
    }

    @Test
    fun `successful claim shows confirmation and continue links identity`() = runTest(dispatcher) {
        var captured: RcLinkRequest? = null
        coEvery { apiClient.rcLink(any()) } answers { captured = firstArg(); NetworkResult.Success(response()) }

        val vm = viewModel()
        vm.onCodeChange("123456")
        vm.claim()
        dispatcher.scheduler.advanceUntilIdle()

        val state = vm.uiState.value
        assertTrue(state.isLinked)
        assertEquals("t***@gmail.com", state.successEmail)
        assertEquals("11111111-1111-1111-1111-111111111111", state.successUserId)
        assertFalse(state.isLoading)

        coEvery { subscriptionManager.logIn(any()) } returns Unit
        vm.onContinue()
        dispatcher.scheduler.advanceUntilIdle()

        coVerify {
            apiClient.rcLink(any())
            subscriptionManager.logIn("11111111-1111-1111-1111-111111111111")
        }
        assertEquals("\$RCAnonymousID:abc", captured?.appUserId)
        assertEquals("android", captured?.platform)
    }

    @Test
    fun `not claimable maps to invalid message`() = runTest(dispatcher) {
        coEvery { apiClient.rcLink(any()) } returns NetworkResult.Error(404, "rc_link_not_claimable")

        val vm = viewModel()
        vm.onCodeChange("999999")
        vm.claim()
        dispatcher.scheduler.advanceUntilIdle()

        assertEquals(R.string.rc_link_error_invalid, vm.uiState.value.errorMessageRes)
        assertFalse(vm.uiState.value.isLinked)
    }

    @Test
    fun `already bound maps to bound message`() = runTest(dispatcher) {
        coEvery { apiClient.rcLink(any()) } returns NetworkResult.Error(409, "rc_link_already_bound")

        val vm = viewModel()
        vm.onCodeChange("123456")
        vm.claim()
        dispatcher.scheduler.advanceUntilIdle()

        assertEquals(R.string.rc_link_error_bound, vm.uiState.value.errorMessageRes)
    }

    @Test
    fun `unknown backend error maps to generic message`() = runTest(dispatcher) {
        coEvery { apiClient.rcLink(any()) } returns NetworkResult.Error(400, "invalid_request_body")

        val vm = viewModel()
        vm.onCodeChange("123456")
        vm.claim()
        dispatcher.scheduler.advanceUntilIdle()

        assertEquals(R.string.rc_link_error_generic, vm.uiState.value.errorMessageRes)
    }

    @Test
    fun `network error maps to generic message`() = runTest(dispatcher) {
        coEvery { apiClient.rcLink(any()) } returns NetworkResult.NetworkError(RuntimeException("offline"))

        val vm = viewModel()
        vm.onCodeChange("123456")
        vm.claim()
        dispatcher.scheduler.advanceUntilIdle()

        assertEquals(R.string.rc_link_error_generic, vm.uiState.value.errorMessageRes)
    }

    @Test
    fun `short code blocks the claim without calling the API`() = runTest(dispatcher) {
        val vm = viewModel()
        vm.onCodeChange("123")
        vm.claim()
        dispatcher.scheduler.advanceUntilIdle()

        assertEquals(R.string.rc_link_error_short_code, vm.uiState.value.errorMessageRes)
        coVerify(exactly = 0) { apiClient.rcLink(any()) }
    }

    @Test
    fun `logIn failure after successful claim still navigates back`() = runTest(dispatcher) {
        // Judge A PR-4 round 1: the non-fatal design ("logIn failure keeps
        // the backend bind") must not strand the user on the success screen.
        coEvery { apiClient.rcLink(any()) } returns NetworkResult.Success(response())
        coEvery { subscriptionManager.logIn(any()) } throws RuntimeException("rc down")

        val vm = viewModel()
        vm.onCodeChange("123456")
        vm.claim()
        dispatcher.scheduler.advanceUntilIdle()
        assertTrue(vm.uiState.value.isLinked)

        vm.onContinue()
        dispatcher.scheduler.advanceUntilIdle()

        assertTrue(vm.events.first() is RcLinkEvent.NavigateBack)
    }

    @Test
    fun `continue emits NavigateBack on the happy path too`() = runTest(dispatcher) {
        coEvery { apiClient.rcLink(any()) } returns NetworkResult.Success(response())

        val vm = viewModel()
        vm.onCodeChange("123456")
        vm.claim()
        dispatcher.scheduler.advanceUntilIdle()

        vm.onContinue()
        dispatcher.scheduler.advanceUntilIdle()
        assertTrue(vm.events.first() is RcLinkEvent.NavigateBack)
    }

    @Test
    fun `empty app user id fails up front without calling the API`() = runTest(dispatcher) {
        coEvery { subscriptionManager.currentAppUserId() } returns ""

        val vm = viewModel()
        vm.onCodeChange("123456")
        vm.claim()
        dispatcher.scheduler.advanceUntilIdle()

        assertEquals(R.string.rc_link_error_generic, vm.uiState.value.errorMessageRes)
        coVerify(exactly = 0) { apiClient.rcLink(any()) }
    }
}
