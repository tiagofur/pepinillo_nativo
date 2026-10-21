package dev.creapolis.pepinillo.core.auth

import android.util.Log
import dev.creapolis.pepinillo.core.billing.RestoreFlowResult
import dev.creapolis.pepinillo.core.billing.SubscriptionManager
import dev.creapolis.pepinillo.core.identity.IdentityManager
import dev.creapolis.pepinillo.core.network.AuthResponse
import dev.creapolis.pepinillo.core.network.NetworkResult
import dev.creapolis.pepinillo.core.network.PepinilloApiClient
import dev.creapolis.pepinillo.core.network.TokensDto
import dev.creapolis.pepinillo.core.network.UserDto
import dev.creapolis.pepinillo.core.network.VerifyReceiptRequest
import dev.creapolis.pepinillo.data.local.PepinilloDatabase
import dev.creapolis.pepinillo.data.repository.UserRepository
import dev.creapolis.pepinillo.data.sync.InitialSyncManager
import dev.creapolis.pepinillo.data.sync.InitialUploadResult
import dev.creapolis.pepinillo.data.sync.SyncEngine
import dev.creapolis.pepinillo.data.sync.SyncMetadataStore
import dev.creapolis.pepinillo.data.sync.SyncWebSocketClient
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Result of running the post-auth data-migration pipeline (initial upload / merge / initial sync).
 *
 * [showMergeDialog] is true when the server might already have data and the user must choose
 * whether to merge local+server or use account-only. NO local data has been uploaded when
 * this is returned — the upload is deferred to [SessionManager.onMergeResolved] so that
 * "Use account only" can still offer a genuinely clean server state (B1).
 */
sealed class PostAuthFlowResult {
    data object Completed : PostAuthFlowResult()
    data class MergeConflict(val showMergeDialog: Boolean) : PostAuthFlowResult()
}

/**
 * Single source of truth for session lifecycle: sign-out, account deletion, and the
 * post-authentication data-migration pipeline.
 *
 * Previously this logic was triplicated across AuthViewModel, ProfileViewModel, and
 * MoreViewModel — each copy omitting a different step (Room wipe, IdentityManager refresh,
 * RevenueCat logOut). That caused cross-account data leaks (#333), stale identity (#338),
 * and Pro entitlements sticking to the device (#334).
 *
 * Everything flows through here now so the ordering and completeness are guaranteed.
 */
@Singleton
class SessionManager @Inject constructor(
    private val apiClient: PepinilloApiClient,
    private val authStore: AuthStore,
    private val database: PepinilloDatabase,
    private val userRepository: UserRepository,
    private val syncEngine: SyncEngine,
    private val initialSyncManager: InitialSyncManager,
    private val identityManager: IdentityManager,
    private val syncWebSocketClient: SyncWebSocketClient,
    private val subscriptionManager: SubscriptionManager,
    private val syncMetadataStore: SyncMetadataStore,
) {

    private companion object {
        const val TAG = "SessionManager"
    }

    // ── Sign-out ──

    /**
     * Fully sign out the current user. Ordered so that no orphaned data can leak to the
     * next account login:
     *
     * 1. Disconnect WebSocket (stop realtime sync immediately).
     * 2. Server-side logout (revoke refresh token).
     * 3. RevenueCat logOut (clear Pro entitlements — they follow account, not device).
     * 4. Wipe ALL local user-owned data (tasks, sessions, stats, etc.).
     * 5. Clear sync metadata (prevent stale cursors for next account).
     * 6. Clear auth store (tokens + user info; deviceId preserved).
     * 7. Refresh identity manager (ANONYMOUS state propagates to SyncLifecycleObserver).
     */
    suspend fun signOut() {
        Log.d(TAG, "signOut: starting full session teardown")
        syncWebSocketClient.disconnect()
        val refreshToken = authStore.getRefreshToken()
        runCatching { apiClient.logout(refreshToken) }
            .onFailure { Log.w(TAG, "Server logout failed (non-fatal): ${it.message}") }
        runCatching { subscriptionManager.logOut() }
            .onFailure { Log.w(TAG, "RevenueCat logOut failed (non-fatal): ${it.message}") }
        runCatching { database.clearAllUserData() }
            .onFailure { Log.e(TAG, "Room wipe failed", it) }
        syncMetadataStore.clearAll()
        userRepository.clearCache()
        authStore.clearAll()
        identityManager.refreshState()
        Log.d(TAG, "signOut: session teardown complete")
    }

    /**
     * Permanently delete the account on the server, then run the same local cleanup as
     * [signOut]. Returns true if the server deletion succeeded (local cleanup runs regardless).
     */
    suspend fun deleteAccount(): Boolean {
        Log.d(TAG, "deleteAccount: requesting server deletion")
        return when (val result = apiClient.deleteAccount()) {
            is NetworkResult.Success -> {
                signOut()
                Log.d(TAG, "deleteAccount: complete")
                true
            }
            is NetworkResult.Error -> {
                Log.e(TAG, "deleteAccount: server error ${result.code}")
                false
            }
            is NetworkResult.NetworkError -> {
                Log.e(TAG, "deleteAccount: network error", result.exception)
                false
            }
        }
    }

    // ── Post-auth pipeline ──

    /**
     * Save tokens + user, then run the data-migration pipeline that determines what
     * happens with local vs. server data on first authenticated entry.
     *
     * This is shared by login, register, Google sign-in, AND email-verify success —
     * previously verify skipped the entire pipeline (#335).
     *
     * Caller responsibilities after this returns:
     * - [PostAuthFlowResult.Completed]: proceed to authenticated UI. WebSocket is connected.
     * - [PostAuthFlowResult.MergeConflict]: show merge dialog; on resolution call
     *   [onMergeResolved] or [onUseAccountOnly].
     *
     * If the user's email is NOT verified, returns [PostAuthFlowResult.Completed] after
     * saving tokens with `emailVerified=false`; the caller should route to verification.
     */
    suspend fun completeAuthSuccess(response: AuthResponse): PostAuthFlowResult {
        // Persist session including verification flag.
        authStore.saveTokens(response.tokens.accessToken, response.tokens.refreshToken)
        authStore.saveUser(
            response.user.id,
            response.user.name,
            response.user.email,
            emailVerified = response.user.emailVerified,
        )
        userRepository.cacheUserFromDto(response.user)
        runCatching { subscriptionManager.logIn(response.user.id) }
            .onFailure { Log.w(TAG, "RC logIn failed (non-fatal): ${it.message}") }
        identityManager.refreshState()

        // Unverified users must verify before data endpoints are usable.
        if (!response.user.emailVerified) {
            Log.d(TAG, "completeAuthSuccess: email not verified, deferring data pipeline")
            return PostAuthFlowResult.Completed
        }

        return runDataMigrationPipeline()
    }

    /** Variant for [VerifyEmailResponse] which carries the same user+tokens shape. */
    suspend fun completeAuthSuccessFromVerify(
        user: UserDto,
        tokens: TokensDto,
    ): PostAuthFlowResult {
        authStore.saveTokens(tokens.accessToken, tokens.refreshToken)
        authStore.saveUser(user.id, user.name, user.email, emailVerified = true)
        userRepository.cacheUserFromDto(user)
        runCatching { subscriptionManager.logIn(user.id) }
            .onFailure { Log.w(TAG, "RC logIn failed (non-fatal): ${it.message}") }
        identityManager.refreshState()
        return runDataMigrationPipeline()
    }

    /**
     * The core data-migration logic: if local data exists, check the server BEFORE uploading
     * anything; if the server has (or might have) data, surface a merge conflict and defer the
     * upload until the user chooses. If no local data, pull from server.
     *
     * In all non-conflict paths, the WebSocket is connected so realtime sync works
     * immediately without a process restart.
     */
    private suspend fun runDataMigrationPipeline(): PostAuthFlowResult {
        val hasLocal = syncEngine.hasLocalData()

        if (hasLocal) {
            // B1: the pre-check MUST happen before any upload. Once local rows are pushed,
            // "Use account only" can no longer offer a clean server state, and an upload
            // error used to skip the dialog while dirty rows were pushed anyway.
            when (syncEngine.hasServerData()) {
                true -> {
                    // Server already has data — ask BEFORE uploading; the upload runs in
                    // onMergeResolved() only if the user chooses to merge.
                    Log.d(TAG, "Server already has data — deferring upload until merge choice")
                    return PostAuthFlowResult.MergeConflict(showMergeDialog = true)
                }
                null -> {
                    // Pre-check failed — safe default: never silently push local data.
                    Log.w(TAG, "hasServerData check failed — showing merge dialog (safe default)")
                    return PostAuthFlowResult.MergeConflict(showMergeDialog = true)
                }
                false -> {
                    Log.d(TAG, "Server has no data, running initial upload")
                    when (val uploadResult = syncEngine.initialUpload()) {
                        is InitialUploadResult.Success -> {
                            if (uploadResult.hasExistingData) {
                                // Race: data appeared on the server between the pre-check and
                                // the upload landing — still ask instead of silently merging.
                                return PostAuthFlowResult.MergeConflict(showMergeDialog = true)
                            }
                            // No conflict — fall through to connect + sync.
                        }
                        is InitialUploadResult.NotAuthenticated -> {
                            Log.w(TAG, "Initial upload returned NotAuthenticated, falling through")
                        }
                        is InitialUploadResult.Error -> {
                            // Non-fatal: the server is empty, so retrying later via syncAll
                            // cannot create a merge conflict.
                            Log.e(TAG, "Initial upload failed (non-fatal)", uploadResult.exception)
                        }
                    }
                }
            }
        } else {
            // Empty Room — pull everything from server first.
            Log.d(TAG, "No local data, running initial sync from server")
            when (val syncResult = initialSyncManager.performInitialSync()) {
                is InitialSyncManager.InitialSyncResult.Success ->
                    Log.d(TAG, "Initial sync succeeded")
                is InitialSyncManager.InitialSyncResult.NotAuthenticated ->
                    Log.w(TAG, "Initial sync returned NotAuthenticated")
                is InitialSyncManager.InitialSyncResult.Error ->
                    Log.e(TAG, "Initial sync failed (non-fatal)", syncResult.exception)
            }
        }

        // Normal incremental sync + WebSocket connect for all non-conflict paths.
        runCatching { syncEngine.syncAll() }
            .onFailure { Log.w(TAG, "syncAll failed (non-fatal): ${it.message}") }
        syncWebSocketClient.connect()
        reconcileServerEntitlement()
        return PostAuthFlowResult.Completed
    }

    /**
     * Post-login entitlement reconcile (guest rescue). If RevenueCat reports an
     * active entitlement — e.g. a guest purchase made before sign-in, now
     * transferred by the RC alias — but the server was never told (guest
     * purchases skip verification: no token), run a silent restore+verify so
     * the server tier converges without any user action. Best-effort: never
     * fails authentication.
     */
    private suspend fun reconcileServerEntitlement() {
        runCatching {
            if (!subscriptionManager.subscriptionState.value.hasLocalPremium) return
            val verification = when (val result = subscriptionManager.restorePurchases()) {
                is RestoreFlowResult.Success -> result.verification
                is RestoreFlowResult.Failed -> {
                    Log.w(TAG, "reconcile: restore failed (non-fatal): ${result.message}")
                    return
                }
            } ?: return
            when (val result = apiClient.verifyReceipt(
                VerifyReceiptRequest(
                    productId = verification.productId,
                    purchaseToken = verification.purchaseToken,
                ),
            )) {
                is NetworkResult.Success -> {
                    subscriptionManager.updateFromServer(
                        result.data.subscriptionTier,
                        result.data.subscriptionExpiresAt,
                    )
                    userRepository.fetchAndCacheProfile()
                }
                else -> Log.w(TAG, "reconcile: server verify inconclusive (non-fatal)")
            }
        }.onFailure { Log.w(TAG, "reconcileServerEntitlement failed (non-fatal): ${it.message}") }
    }

    /**
     * Merge resolution: user chose to keep both local and server data. Performs the
     * deferred upload (B1: nothing was uploaded before the choice), then a full sync,
     * then connects the WebSocket (previously missing, #346).
     */
    suspend fun onMergeResolved() {
        runCatching { syncEngine.initialUpload() }
            .onFailure { Log.w(TAG, "initialUpload after merge resolution failed (non-fatal): ${it.message}") }
        runCatching { syncEngine.syncAll() }
            .onFailure { Log.w(TAG, "syncAll after merge failed (non-fatal): ${it.message}") }
        syncWebSocketClient.connect()
        reconcileServerEntitlement()
    }

    /**
     * Merge resolution: user chose to discard local data and use server data only.
     * Genuinely clean since B1 — nothing was uploaded before the choice, so wiping local
     * data cannot leak it into the account. Wipe local, pull fresh from server, then
     * connect WebSocket (previously missing, #346).
     */
    suspend fun onUseAccountOnly() {
        initialSyncManager.wipeAndSync()
        syncWebSocketClient.connect()
        reconcileServerEntitlement()
    }
}
