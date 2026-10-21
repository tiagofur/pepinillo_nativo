package dev.creapolis.pepinillo.core.auth

import dev.creapolis.pepinillo.core.billing.PurchaseVerificationTarget
import dev.creapolis.pepinillo.core.billing.RestoreFlowResult
import dev.creapolis.pepinillo.core.billing.SubscriptionManager
import dev.creapolis.pepinillo.core.billing.SubscriptionState
import dev.creapolis.pepinillo.core.billing.SubscriptionTier
import dev.creapolis.pepinillo.core.network.VerifyReceiptResponse
import dev.creapolis.pepinillo.core.identity.IdentityManager
import dev.creapolis.pepinillo.core.network.AuthResponse
import dev.creapolis.pepinillo.core.network.NetworkResult
import dev.creapolis.pepinillo.core.network.PepinilloApiClient
import dev.creapolis.pepinillo.core.network.TokensDto
import dev.creapolis.pepinillo.core.network.UserDto
import dev.creapolis.pepinillo.data.local.PepinilloDatabase
import dev.creapolis.pepinillo.data.repository.UserRepository
import dev.creapolis.pepinillo.data.sync.InitialSyncManager
import dev.creapolis.pepinillo.data.sync.InitialUploadResult
import dev.creapolis.pepinillo.data.sync.SyncEngine
import dev.creapolis.pepinillo.data.sync.SyncMetadataStore
import dev.creapolis.pepinillo.data.sync.SyncResult
import dev.creapolis.pepinillo.data.sync.SyncWebSocketClient
import dev.creapolis.pepinillo.data.sync.TransientSyncException
import io.mockk.Runs
import io.mockk.coEvery
import io.mockk.coJustRun
import io.mockk.coVerify
import io.mockk.coVerifyOrder
import io.mockk.every
import io.mockk.just
import io.mockk.mockk
import io.mockk.verify
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

class SessionManagerTest {

    private lateinit var apiClient: PepinilloApiClient
    private lateinit var authStore: AuthStore
    private lateinit var database: PepinilloDatabase
    private lateinit var userRepository: UserRepository
    private lateinit var syncEngine: SyncEngine
    private lateinit var initialSyncManager: InitialSyncManager
    private lateinit var identityManager: IdentityManager
    private lateinit var syncWebSocketClient: SyncWebSocketClient
    private lateinit var subscriptionManager: SubscriptionManager
    private lateinit var syncMetadataStore: SyncMetadataStore
    private lateinit var sessionManager: SessionManager

    @Before
    fun setUp() {
        apiClient = mockk(relaxed = true)
        authStore = mockk(relaxed = true)
        database = mockk(relaxed = true)
        userRepository = mockk(relaxed = true)
        syncEngine = mockk(relaxed = true)
        initialSyncManager = mockk(relaxed = true)
        identityManager = mockk(relaxed = true)
        syncWebSocketClient = mockk(relaxed = true)
        subscriptionManager = mockk(relaxed = true)
        syncMetadataStore = mockk(relaxed = true)

        sessionManager = SessionManager(
            apiClient = apiClient,
            authStore = authStore,
            database = database,
            userRepository = userRepository,
            syncEngine = syncEngine,
            initialSyncManager = initialSyncManager,
            identityManager = identityManager,
            syncWebSocketClient = syncWebSocketClient,
            subscriptionManager = subscriptionManager,
            syncMetadataStore = syncMetadataStore,
        )
    }

    // -----------------------------------------------------------------------
    // signOut
    // -----------------------------------------------------------------------

    @Test
    fun `signOut disconnects WS, calls server logout, wipes Room, clears auth, refreshes identity`() = runTest {
        coJustRun { syncWebSocketClient.disconnect() }
        every { authStore.getRefreshToken() } returns "refresh-123"
        coEvery { apiClient.logout(any()) } returns NetworkResult.Success(Unit)
        coJustRun { database.clearAllUserData() }
        coJustRun { syncMetadataStore.clearAll() }
        coJustRun { userRepository.clearCache() }
        coJustRun { authStore.clearAll() }
        coJustRun { identityManager.refreshState() }
        coJustRun { subscriptionManager.logOut() }

        sessionManager.signOut()

        coVerifyOrder {
            syncWebSocketClient.disconnect()
            apiClient.logout("refresh-123")
            subscriptionManager.logOut()
            database.clearAllUserData()
            syncMetadataStore.clearAll()
            authStore.clearAll()
            identityManager.refreshState()
        }
    }

    @Test
    fun `signOut completes even if server logout fails`() = runTest {
        coJustRun { syncWebSocketClient.disconnect() }
        coEvery { apiClient.logout(any()) } returns NetworkResult.Error(500, "server error")
        coJustRun { database.clearAllUserData() }
        coJustRun { syncMetadataStore.clearAll() }
        coJustRun { authStore.clearAll() }
        coJustRun { identityManager.refreshState() }

        sessionManager.signOut()

        // Cleanup must still happen despite server logout failure
        coVerify { database.clearAllUserData() }
        coVerify { authStore.clearAll() }
        coVerify { identityManager.refreshState() }
    }

    // -----------------------------------------------------------------------
    // deleteAccount
    // -----------------------------------------------------------------------

    @Test
    fun `deleteAccount returns true and runs signOut cleanup on server success`() = runTest {
        coEvery { apiClient.deleteAccount() } returns NetworkResult.Success(Unit)
        coJustRun { syncWebSocketClient.disconnect() }
        coJustRun { database.clearAllUserData() }
        coJustRun { syncMetadataStore.clearAll() }
        coJustRun { authStore.clearAll() }
        coJustRun { identityManager.refreshState() }

        val result = sessionManager.deleteAccount()

        assertTrue(result)
        coVerify { database.clearAllUserData() }
        coVerify { identityManager.refreshState() }
    }

    @Test
    fun `deleteAccount returns false on server error and does NOT wipe local data`() = runTest {
        coEvery { apiClient.deleteAccount() } returns NetworkResult.Error(500, "fail")

        val result = sessionManager.deleteAccount()

        assertFalse(result)
        coVerify(exactly = 0) { database.clearAllUserData() }
    }

    // -----------------------------------------------------------------------
    // completeAuthSuccess — unverified
    // -----------------------------------------------------------------------

    @Test
    fun `completeAuthSuccess with unverified user saves tokens but returns Completed without data pipeline`() = runTest {
        val response = authResponse(emailVerified = false)

        val result = sessionManager.completeAuthSuccess(response)

        assertTrue(result is PostAuthFlowResult.Completed)
        verify { authStore.saveTokens("access", "refresh") }
        verify { authStore.saveUser("user-1", "Test", "test@test.com", emailVerified = false) }
        // Data pipeline must NOT run for unverified users
        coVerify(exactly = 0) { syncEngine.hasLocalData() }
        coVerify(exactly = 0) { syncWebSocketClient.connect() }
    }

    // -----------------------------------------------------------------------
    // completeAuthSuccess — verified, no local data
    // -----------------------------------------------------------------------

    @Test
    fun `completeAuthSuccess verified with no local data runs initial sync and connects WS`() = runTest {
        val response = authResponse(emailVerified = true)
        coEvery { syncEngine.hasLocalData() } returns false
        coEvery { initialSyncManager.performInitialSync() } returns
            InitialSyncManager.InitialSyncResult.Success
        coJustRun { syncEngine.syncAll() }
        coJustRun { syncWebSocketClient.connect() }

        val result = sessionManager.completeAuthSuccess(response)

        assertTrue(result is PostAuthFlowResult.Completed)
        coVerify { initialSyncManager.performInitialSync() }
        coVerify { syncWebSocketClient.connect() }
    }

    // -----------------------------------------------------------------------
    // completeAuthSuccess — verified, local data, no conflict
    // -----------------------------------------------------------------------

    @Test
    fun `completeAuthSuccess verified with local data and no server conflict uploads and connects WS`() = runTest {
        val response = authResponse(emailVerified = true)
        coEvery { syncEngine.hasLocalData() } returns true
        coEvery { syncEngine.hasServerData() } returns false
        coEvery { syncEngine.initialUpload() } returns InitialUploadResult.Success(hasExistingData = false)
        coJustRun { syncEngine.syncAll() }
        coJustRun { syncWebSocketClient.connect() }

        val result = sessionManager.completeAuthSuccess(response)

        assertTrue(result is PostAuthFlowResult.Completed)
        coVerify { syncEngine.initialUpload() }
        coVerify { syncWebSocketClient.connect() }
    }

    // -----------------------------------------------------------------------
    // completeAuthSuccess — verified, local data, server conflict
    // -----------------------------------------------------------------------

    @Test
    fun `completeAuthSuccess verified with server conflict returns MergeConflict without uploading or connecting WS`() = runTest {
        val response = authResponse(emailVerified = true)
        coEvery { syncEngine.hasLocalData() } returns true
        coEvery { syncEngine.hasServerData() } returns true

        val result = sessionManager.completeAuthSuccess(response)

        assertTrue(result is PostAuthFlowResult.MergeConflict)
        // B1: nothing may be uploaded before the user picks a merge option — otherwise
        // "Use account only" can no longer offer a clean server state.
        coVerify(exactly = 0) { syncEngine.initialUpload() }
        // WS must NOT connect until the user resolves the merge dialog (#346)
        coVerify(exactly = 0) { syncWebSocketClient.connect() }
    }

    @Test
    fun `completeAuthSuccess when server data check fails shows merge dialog without uploading`() = runTest {
        // B1 safe default: hasServerData() == null (check failed) must never silently
        // push local data — show the dialog and let the user decide.
        val response = authResponse(emailVerified = true)
        coEvery { syncEngine.hasLocalData() } returns true
        coEvery { syncEngine.hasServerData() } returns null

        val result = sessionManager.completeAuthSuccess(response)

        assertTrue(result is PostAuthFlowResult.MergeConflict)
        coVerify(exactly = 0) { syncEngine.initialUpload() }
        coVerify(exactly = 0) { syncWebSocketClient.connect() }
    }

    @Test
    fun `completeAuthSuccess when data appears on server during upload shows merge dialog`() = runTest {
        // Race guard: the server was empty at the pre-check but the upload landed on data
        // that appeared in between — still ask instead of silently merging.
        val response = authResponse(emailVerified = true)
        coEvery { syncEngine.hasLocalData() } returns true
        coEvery { syncEngine.hasServerData() } returns false
        coEvery { syncEngine.initialUpload() } returns InitialUploadResult.Success(hasExistingData = true)

        val result = sessionManager.completeAuthSuccess(response)

        assertTrue(result is PostAuthFlowResult.MergeConflict)
        coVerify(exactly = 0) { syncWebSocketClient.connect() }
    }

    // -----------------------------------------------------------------------
    // completeAuthSuccessFromVerify — runs data pipeline (#335 regression)
    // -----------------------------------------------------------------------

    @Test
    fun `completeAuthSuccessFromVerify runs data migration pipeline`() = runTest {
        val user = userDto(emailVerified = true)
        val tokens = TokensDto("access", "refresh")
        coEvery { syncEngine.hasLocalData() } returns false
        coEvery { initialSyncManager.performInitialSync() } returns
            InitialSyncManager.InitialSyncResult.Success
        coJustRun { syncEngine.syncAll() }
        coJustRun { syncWebSocketClient.connect() }

        val result = sessionManager.completeAuthSuccessFromVerify(user, tokens)

        assertTrue(result is PostAuthFlowResult.Completed)
        // Regression test for #335: verify path must run the data pipeline, not skip it
        coVerify { syncEngine.hasLocalData() }
        coVerify { syncWebSocketClient.connect() }
    }

    @Test
    fun `completeAuthSuccessFromVerify with server conflict shows merge dialog without uploading`() = runTest {
        val user = userDto(emailVerified = true)
        val tokens = TokensDto("access", "refresh")
        coEvery { syncEngine.hasLocalData() } returns true
        coEvery { syncEngine.hasServerData() } returns true

        val result = sessionManager.completeAuthSuccessFromVerify(user, tokens)

        assertTrue(result is PostAuthFlowResult.MergeConflict)
        // B1: verify follows the same ask-before-upload rule as login.
        coVerify(exactly = 0) { syncEngine.initialUpload() }
    }

    // -----------------------------------------------------------------------
    // onMergeResolved / onUseAccountOnly — WS connect (#346)
    // -----------------------------------------------------------------------

    @Test
    fun `onMergeResolved performs deferred upload then sync then connects WS`() = runTest {
        // B1: the actual upload is deferred to merge resolution — it runs here, after
        // the user explicitly chose to merge, and is best-effort.
        coEvery { syncEngine.initialUpload() } returns InitialUploadResult.Success(hasExistingData = true)
        coJustRun { syncEngine.syncAll() }
        coJustRun { syncWebSocketClient.connect() }

        sessionManager.onMergeResolved()

        coVerifyOrder {
            syncEngine.initialUpload()
            syncEngine.syncAll()
            syncWebSocketClient.connect()
        }
    }

    @Test
    fun `onMergeResolved still connects WS when the deferred upload fails`() = runTest {
        // Best-effort: a failed upload must not block the sync + connect steps.
        coEvery { syncEngine.initialUpload() } throws TransientSyncException("upload failed")
        coJustRun { syncEngine.syncAll() }
        coJustRun { syncWebSocketClient.connect() }

        sessionManager.onMergeResolved()

        coVerify { syncEngine.syncAll() }
        coVerify { syncWebSocketClient.connect() }
    }

    @Test
    fun `onUseAccountOnly connects WebSocket after wipe-and-sync`() = runTest {
        coEvery { initialSyncManager.wipeAndSync() } returns
            InitialSyncManager.InitialSyncResult.Success
        coJustRun { syncWebSocketClient.connect() }

        sessionManager.onUseAccountOnly()

        // B1: account-only must be genuinely clean — local data is discarded,
        // never uploaded.
        coVerify(exactly = 0) { syncEngine.initialUpload() }
        coVerify { initialSyncManager.wipeAndSync() }
        coVerify { syncWebSocketClient.connect() }
    }

    // -----------------------------------------------------------------------
    // Helpers
    // -----------------------------------------------------------------------

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

    // -----------------------------------------------------------------------
    // reconcileServerEntitlement (guest rescue)
    // -----------------------------------------------------------------------

    @Test
    fun `onMergeResolved reconciles server tier when RC reports premium`() = runTest {
        every { subscriptionManager.subscriptionState } returns MutableStateFlow(
            SubscriptionState(tier = SubscriptionTier.EVERYWHERE_ANNUAL),
        )
        coEvery { syncEngine.initialUpload() } returns InitialUploadResult.Success(hasExistingData = true)
        coEvery { syncEngine.syncAll() } returns SyncResult.Success
        coEvery { subscriptionManager.restorePurchases() } returns RestoreFlowResult.Success(
            state = SubscriptionState(tier = SubscriptionTier.EVERYWHERE_ANNUAL),
            verification = PurchaseVerificationTarget("prod", "tok"),
        )
        coEvery { apiClient.verifyReceipt(any()) } returns NetworkResult.Success(
            VerifyReceiptResponse(subscriptionTier = "everywhere_annual", subscriptionExpiresAt = null),
        )
        coJustRun { userRepository.fetchAndCacheProfile() }

        sessionManager.onMergeResolved()

        coVerify { subscriptionManager.restorePurchases() }
        coVerify { apiClient.verifyReceipt(any()) }
        coVerify { subscriptionManager.updateFromServer("everywhere_annual", null) }
    }

    @Test
    fun `onMergeResolved skips reconcile when RC has no premium`() = runTest {
        every { subscriptionManager.subscriptionState } returns MutableStateFlow(SubscriptionState())
        coEvery { syncEngine.initialUpload() } returns InitialUploadResult.Success(hasExistingData = true)
        coEvery { syncEngine.syncAll() } returns SyncResult.Success

        sessionManager.onMergeResolved()

        coVerify(exactly = 0) { subscriptionManager.restorePurchases() }
        coVerify(exactly = 0) { apiClient.verifyReceipt(any()) }
    }

    @Test
    fun `reconcile failure never breaks the merge flow`() = runTest {
        every { subscriptionManager.subscriptionState } returns MutableStateFlow(
            SubscriptionState(tier = SubscriptionTier.EVERYWHERE_ANNUAL),
        )
        coEvery { syncEngine.initialUpload() } returns InitialUploadResult.Success(hasExistingData = true)
        coEvery { syncEngine.syncAll() } returns SyncResult.Success
        coEvery { subscriptionManager.restorePurchases() } throws RuntimeException("rc down")

        // Must not throw.
        sessionManager.onMergeResolved()

        coVerify(exactly = 0) { apiClient.verifyReceipt(any()) }
    }
}
