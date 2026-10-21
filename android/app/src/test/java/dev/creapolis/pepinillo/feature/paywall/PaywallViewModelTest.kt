package dev.creapolis.pepinillo.feature.paywall

import android.app.Activity
import dev.creapolis.pepinillo.R
import dev.creapolis.pepinillo.core.auth.AuthStore
import dev.creapolis.pepinillo.core.billing.ProductInfo
import dev.creapolis.pepinillo.core.billing.PurchaseFlowResult
import dev.creapolis.pepinillo.core.billing.PurchaseVerificationTarget
import dev.creapolis.pepinillo.core.billing.RestoreFlowResult
import dev.creapolis.pepinillo.core.billing.SubscriptionManager
import dev.creapolis.pepinillo.core.billing.SubscriptionState
import dev.creapolis.pepinillo.core.billing.SubscriptionTier
import dev.creapolis.pepinillo.core.billing.mergeServerSubscription
import dev.creapolis.pepinillo.core.network.PepinilloApiClient
import dev.creapolis.pepinillo.data.local.entity.UserEntity
import dev.creapolis.pepinillo.data.repository.UserRepository
import io.mockk.coEvery
import io.mockk.coVerify
import io.mockk.every
import io.mockk.mockk
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.test.StandardTestDispatcher
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
class PaywallViewModelTest {

    private val testDispatcher = StandardTestDispatcher()
    private val subscriptionManager: SubscriptionManager = mockk(relaxed = true)
    private val apiClient: PepinilloApiClient = mockk(relaxed = true)
    private val authStore: AuthStore = mockk(relaxed = true)
    private val userRepository: UserRepository = mockk(relaxed = true)

    private val productsFlow = MutableStateFlow<List<ProductInfo>>(emptyList())
    private val subscriptionStateFlow = MutableStateFlow(SubscriptionState())

    private lateinit var viewModel: PaywallViewModel
    private lateinit var uiStateScope: CoroutineScope

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

        // uiState is stateIn(WhileSubscribed): without a subscriber it never leaves its
        // initial value, so tests asserting uiState.value must keep one active.
        uiStateScope = CoroutineScope(SupervisorJob() + testDispatcher)
        uiStateScope.launch { viewModel.uiState.collect {} }
    }

    @After
    fun tearDown() {
        uiStateScope.cancel()
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

    // ── Purchase success ──

    @Test
    fun `purchase success does not set error`() = runTest {
        val product = mockk<ProductInfo>(relaxed = true) {
            every { productId } returns "com.pepinillo.app.pro.annual"
        }
        productsFlow.value = listOf(product)
        testDispatcher.scheduler.advanceUntilIdle()

        viewModel.selectProduct("com.pepinillo.app.pro.annual")
        coEvery { subscriptionManager.launchPurchaseFlow(any(), any()) } returns PurchaseFlowResult.Success(
            state = SubscriptionState(tier = dev.creapolis.pepinillo.core.billing.SubscriptionTier.EVERYWHERE_ANNUAL),
            verification = null,
        )
        coEvery { apiClient.verifyReceipt(any()) } returns dev.creapolis.pepinillo.core.network.NetworkResult.Success(
            dev.creapolis.pepinillo.core.network.VerifyReceiptResponse(
                subscriptionTier = "pro",
                subscriptionExpiresAt = null,
            ),
        )
        // verification == null → verifyWithServerIfNeeded falls back to the profile sync;
        // stub it explicitly (relaxed mocks return a poisoned Result that fails the cast).
        every { authStore.getAccessToken() } returns "token"
        coEvery { userRepository.fetchAndCacheProfile() } returns Result.success(userEntity())

        val activity = mockk<android.app.Activity>(relaxed = true)
        viewModel.purchase(activity)
        testDispatcher.scheduler.advanceUntilIdle()

        assertNull(viewModel.uiState.value.errorRes)
    }

    @Test
    fun `purchase cancelled does not set error`() = runTest {
        val product = mockk<ProductInfo>(relaxed = true) {
            every { productId } returns "com.pepinillo.app.pro.annual"
        }
        productsFlow.value = listOf(product)
        testDispatcher.scheduler.advanceUntilIdle()

        viewModel.selectProduct("com.pepinillo.app.pro.annual")
        coEvery { subscriptionManager.launchPurchaseFlow(any(), any()) } returns PurchaseFlowResult.Cancelled

        val activity = mockk<android.app.Activity>(relaxed = true)
        viewModel.purchase(activity)
        testDispatcher.scheduler.advanceUntilIdle()

        assertNull(viewModel.uiState.value.errorRes)
    }

    // ── Restore ──

    @Test
    fun `restore success with premium does not set error`() = runTest {
        coEvery { subscriptionManager.restorePurchases() } returns RestoreFlowResult.Success(
            state = SubscriptionState(tier = dev.creapolis.pepinillo.core.billing.SubscriptionTier.EVERYWHERE_ANNUAL),
            verification = null,
        )
        every { authStore.getAccessToken() } returns "token"
        coEvery { userRepository.fetchAndCacheProfile() } returns Result.success(userEntity())

        viewModel.restorePurchases()
        testDispatcher.scheduler.advanceUntilIdle()

        assertNull(viewModel.uiState.value.errorRes)
    }

    @Test
    fun `restore success without premium shows no subscription error`() = runTest {
        coEvery { subscriptionManager.restorePurchases() } returns RestoreFlowResult.Success(
            state = SubscriptionState(tier = dev.creapolis.pepinillo.core.billing.SubscriptionTier.FREE),
            verification = null,
        )

        viewModel.restorePurchases()
        testDispatcher.scheduler.advanceUntilIdle()

        assertEquals(R.string.paywall_no_subscription, viewModel.uiState.value.errorRes)
    }

    @Test
    fun `restore failure shows error`() = runTest {
        coEvery { subscriptionManager.restorePurchases() } returns RestoreFlowResult.Failed("Network timeout")

        viewModel.restorePurchases()
        testDispatcher.scheduler.advanceUntilIdle()

        assertEquals(R.string.paywall_restore_failed, viewModel.uiState.value.errorRes)
    }

    // ── Offerings empty/error ──

    @Test
    fun `empty offerings list shows fallback`() = runTest {
        productsFlow.value = emptyList()
        testDispatcher.scheduler.advanceUntilIdle()

        assertTrue(viewModel.uiState.value.products.isEmpty())
        assertNull(viewModel.uiState.value.selectedProductId)
    }

    @Test
    fun `offerings with products selects annual by default`() = runTest {
        val annual = mockk<ProductInfo>(relaxed = true) {
            every { productId } returns "com.pepinillo.app.pro.annual"
        }
        val monthly = mockk<ProductInfo>(relaxed = true) {
            every { productId } returns "com.pepinillo.app.pro.monthly"
        }
        productsFlow.value = listOf(monthly, annual)
        testDispatcher.scheduler.advanceUntilIdle()

        assertEquals("com.pepinillo.app.pro.annual", viewModel.uiState.value.selectedProductId)
    }

    // ── B4: stale server profile must not downgrade an RC-confirmed purchase ──

    @Test
    fun `verify receipt error with stale free profile does not downgrade RC-confirmed entitlement`() = runTest {
        // B4: RC just confirmed the purchase; receipt verification hits an HTTP error and
        // the stale /users/me profile says "free". The active entitlement must survive.
        val futureExpiry = System.currentTimeMillis() + 31L * 24 * 60 * 60 * 1000
        val rcActive = SubscriptionState(
            tier = SubscriptionTier.EVERYWHERE_ANNUAL,
            activeProductId = "com.pepinillo.app.pro.annual",
            expirationDate = futureExpiry,
        )
        subscriptionStateFlow.value = rcActive
        // Route the mocked manager's updateFromServer through the REAL merge guard so
        // this pins the rule end-to-end through the ViewModel flow.
        every { subscriptionManager.updateFromServer(any(), any()) } answers {
            subscriptionStateFlow.value = mergeServerSubscription(
                current = subscriptionStateFlow.value,
                serverTier = tierFromString(firstArg()),
                serverExpiresAt = secondArg(),
            )
        }
        every { authStore.getAccessToken() } returns "token"

        val product = mockk<ProductInfo>(relaxed = true) {
            every { productId } returns "com.pepinillo.app.pro.annual"
        }
        productsFlow.value = listOf(product)
        testDispatcher.scheduler.advanceUntilIdle()
        viewModel.selectProduct("com.pepinillo.app.pro.annual")

        coEvery { subscriptionManager.launchPurchaseFlow(any(), any()) } returns PurchaseFlowResult.Success(
            state = rcActive,
            verification = PurchaseVerificationTarget(
                productId = "com.pepinillo.app.pro.annual",
                purchaseToken = "purchase-token",
            ),
        )
        coEvery { apiClient.verifyReceipt(any()) } returns
            dev.creapolis.pepinillo.core.network.NetworkResult.Error(500, "boom")
        coEvery { userRepository.fetchAndCacheProfile() } returns Result.success(
            userEntity(subscriptionTier = "free"),
        )

        val activity = mockk<android.app.Activity>(relaxed = true)
        viewModel.purchase(activity)
        testDispatcher.scheduler.advanceUntilIdle()

        // The verification error DID fall back to the stale profile…
        coVerify { apiClient.verifyReceipt(any()) }
        coVerify { subscriptionManager.updateFromServer("free", null) }
        // …but the RC-confirmed entitlement survived the downgrade attempt.
        assertEquals(SubscriptionTier.EVERYWHERE_ANNUAL, subscriptionStateFlow.value.tier)
        assertTrue(subscriptionStateFlow.value.hasLocalPremium)
        assertEquals(futureExpiry, subscriptionStateFlow.value.expirationDate)
        assertTrue(viewModel.uiState.value.canSync)
    }

    // -----------------------------------------------------------------------
    // Helpers
    // -----------------------------------------------------------------------

    private fun userEntity(subscriptionTier: String = "everywhere_annual") = UserEntity(
        id = "user-1",
        email = "e@x.com",
        name = "Name",
        subscriptionTier = subscriptionTier,
    )

    private fun tierFromString(raw: String): SubscriptionTier = when (raw) {
        "pepinillo_plus" -> SubscriptionTier.PEPINILLO_PLUS
        "everywhere_monthly" -> SubscriptionTier.EVERYWHERE_MONTHLY
        "everywhere_annual" -> SubscriptionTier.EVERYWHERE_ANNUAL
        else -> SubscriptionTier.FREE
    }

    @Test
    fun `guest purchase success shows create-account nudge`() = runTest {
        val product = mockk<ProductInfo>(relaxed = true) {
            every { productId } returns "com.pepinillo.app.pro.annual"
        }
        productsFlow.value = listOf(product)
        testDispatcher.scheduler.advanceUntilIdle()

        viewModel.selectProduct("com.pepinillo.app.pro.annual")
        coEvery { subscriptionManager.launchPurchaseFlow(any(), any()) } returns PurchaseFlowResult.Success(
            state = SubscriptionState(tier = SubscriptionTier.EVERYWHERE_ANNUAL),
            verification = null,
        )
        every { authStore.getAccessToken() } returns null

        val activity = mockk<android.app.Activity>(relaxed = true)
        viewModel.purchase(activity)
        testDispatcher.scheduler.advanceUntilIdle()

        assertTrue(viewModel.uiState.value.showCreateAccountNudge)
    }

    @Test
    fun `authed purchase success does not show create-account nudge`() = runTest {
        val product = mockk<ProductInfo>(relaxed = true) {
            every { productId } returns "com.pepinillo.app.pro.annual"
        }
        productsFlow.value = listOf(product)
        testDispatcher.scheduler.advanceUntilIdle()

        viewModel.selectProduct("com.pepinillo.app.pro.annual")
        coEvery { subscriptionManager.launchPurchaseFlow(any(), any()) } returns PurchaseFlowResult.Success(
            state = SubscriptionState(tier = SubscriptionTier.EVERYWHERE_ANNUAL),
            verification = null,
        )
        every { authStore.getAccessToken() } returns "token"
        coEvery { userRepository.fetchAndCacheProfile() } returns Result.success(userEntity())

        val activity = mockk<android.app.Activity>(relaxed = true)
        viewModel.purchase(activity)
        testDispatcher.scheduler.advanceUntilIdle()

        assertFalse(viewModel.uiState.value.showCreateAccountNudge)
    }

    @Test
    fun `dismissCreateAccountNudge clears the nudge`() = runTest {
        val product = mockk<ProductInfo>(relaxed = true) {
            every { productId } returns "com.pepinillo.app.pro.annual"
        }
        productsFlow.value = listOf(product)
        testDispatcher.scheduler.advanceUntilIdle()

        viewModel.selectProduct("com.pepinillo.app.pro.annual")
        coEvery { subscriptionManager.launchPurchaseFlow(any(), any()) } returns PurchaseFlowResult.Success(
            state = SubscriptionState(tier = SubscriptionTier.EVERYWHERE_ANNUAL),
            verification = null,
        )
        every { authStore.getAccessToken() } returns null

        val activity = mockk<android.app.Activity>(relaxed = true)
        viewModel.purchase(activity)
        testDispatcher.scheduler.advanceUntilIdle()
        assertTrue(viewModel.uiState.value.showCreateAccountNudge)

        viewModel.dismissCreateAccountNudge()
        testDispatcher.scheduler.advanceUntilIdle()
        assertFalse(viewModel.uiState.value.showCreateAccountNudge)
    }

}
