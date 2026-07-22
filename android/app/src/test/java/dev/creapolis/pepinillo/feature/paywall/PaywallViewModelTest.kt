package dev.creapolis.pepinillo.feature.paywall

import android.app.Activity
import dev.creapolis.pepinillo.R
import dev.creapolis.pepinillo.core.auth.AuthStore
import dev.creapolis.pepinillo.core.billing.ProductInfo
import dev.creapolis.pepinillo.core.billing.PurchaseFlowResult
import dev.creapolis.pepinillo.core.billing.RestoreFlowResult
import dev.creapolis.pepinillo.core.billing.SubscriptionManager
import dev.creapolis.pepinillo.core.billing.SubscriptionState
import dev.creapolis.pepinillo.core.network.PepinilloApiClient
import dev.creapolis.pepinillo.data.repository.UserRepository
import io.mockk.coEvery
import io.mockk.coVerify
import io.mockk.every
import io.mockk.mockk
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class PaywallViewModelTest {

    private val testDispatcher = StandardTestDispatcher()
    private val subscriptionManager: SubscriptionManager = mockk(relaxed = true)
    private val apiClient: PepinilloApiClient = mockk(relaxed = true)
    private val authStore: AuthStore = mockk(relaxed = true)
    private val userRepository: UserRepository = mockk(relaxed = true)

    private val productsFlow = MutableStateFlow<List<ProductInfo>>(emptyList())
    private val subscriptionStateFlow = MutableStateFlow(SubscriptionState())

    private lateinit var viewModel: PaywallViewModel

    @Before
    fun setUp() {
        Dispatchers.setMain(testDispatcher)
        every { subscriptionManager.products } returns productsFlow
        every { subscriptionManager.subscriptionState } returns subscriptionStateFlow

        viewModel = PaywallViewModel(
            subscriptionManager = subscriptionManager,
            apiClient = apiClient,
            authStore = authStore,
            userRepository = userRepository,
        )
    }

    @After
    fun tearDown() {
        Dispatchers.resetMain()
    }

    @Test
    fun `purchase maps Pending result to paywall_purchase_pending error string`() = runTest {
        val product = mockk<ProductInfo>(relaxed = true) {
            every { productId } returns "com.pepinillo.app.pro.annual"
        }
        productsFlow.value = listOf(product)
        testDispatcher.scheduler.advanceUntilIdle()

        viewModel.selectProduct("com.pepinillo.app.pro.annual")
        coEvery { subscriptionManager.launchPurchaseFlow(any(), any()) } returns PurchaseFlowResult.Pending

        val activity = mockk<Activity>(relaxed = true)
        viewModel.purchase(activity)
        testDispatcher.scheduler.advanceUntilIdle()

        assertEquals(R.string.paywall_purchase_pending, viewModel.uiState.value.errorRes)
        assertFalse(viewModel.uiState.value.isPurchasing)
    }

    @Test
    fun `purchase returns early if operation is already purchasing`() = runTest {
        val product = mockk<ProductInfo>(relaxed = true) {
            every { productId } returns "com.pepinillo.app.pro.annual"
        }
        productsFlow.value = listOf(product)
        testDispatcher.scheduler.advanceUntilIdle()

        viewModel.selectProduct("com.pepinillo.app.pro.annual")

        // First purchase call stays in progress
        coEvery { subscriptionManager.launchPurchaseFlow(any(), any()) } coAnswers {
            kotlinx.coroutines.delay(1000)
            PurchaseFlowResult.Cancelled
        }

        val activity = mockk<Activity>(relaxed = true)
        viewModel.purchase(activity)
        testDispatcher.scheduler.runCurrent()

        assertTrue(viewModel.uiState.value.isPurchasing)

        // Second purchase call while purchasing
        viewModel.purchase(activity)

        // Second restore call while purchasing
        viewModel.restorePurchases()

        testDispatcher.scheduler.advanceUntilIdle()

        coVerify(exactly = 1) { subscriptionManager.launchPurchaseFlow(any(), any()) }
        coVerify(exactly = 0) { subscriptionManager.restorePurchases() }
    }

    @Test
    fun `restorePurchases returns early if purchase is already in progress`() = runTest {
        coEvery { subscriptionManager.restorePurchases() } coAnswers {
            kotlinx.coroutines.delay(1000)
            RestoreFlowResult.Failed("Network error")
        }

        viewModel.restorePurchases()
        testDispatcher.scheduler.runCurrent()

        assertTrue(viewModel.uiState.value.isPurchasing)

        // Second restore call attempt
        viewModel.restorePurchases()

        testDispatcher.scheduler.advanceUntilIdle()

        coVerify(exactly = 1) { subscriptionManager.restorePurchases() }
        assertEquals(R.string.paywall_restore_failed, viewModel.uiState.value.errorRes)
    }
}
