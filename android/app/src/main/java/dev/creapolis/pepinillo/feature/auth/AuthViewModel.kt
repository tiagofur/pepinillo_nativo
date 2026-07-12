package dev.creapolis.pepinillo.feature.auth

import android.content.Context
import android.util.Log
import androidx.credentials.CredentialManager
import androidx.credentials.GetCredentialRequest
import androidx.credentials.exceptions.GetCredentialCancellationException
import androidx.credentials.exceptions.NoCredentialException
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.google.android.libraries.identity.googleid.GetGoogleIdOption
import com.google.android.libraries.identity.googleid.GoogleIdTokenCredential
import dagger.hilt.android.lifecycle.HiltViewModel
import dagger.hilt.android.qualifiers.ApplicationContext
import dev.creapolis.pepinillo.BuildConfig
import dev.creapolis.pepinillo.R
import dev.creapolis.pepinillo.core.auth.AuthStore
import dev.creapolis.pepinillo.core.billing.SubscriptionManager
import dev.creapolis.pepinillo.core.identity.IdentityManager
import dev.creapolis.pepinillo.core.network.AuthResponse
import dev.creapolis.pepinillo.core.network.NetworkResult
import dev.creapolis.pepinillo.core.network.PepinilloApiClient
import dev.creapolis.pepinillo.data.repository.UserRepository
import dev.creapolis.pepinillo.data.sync.InitialSyncManager
import dev.creapolis.pepinillo.data.sync.InitialUploadResult
import dev.creapolis.pepinillo.data.sync.SyncEngine
import dev.creapolis.pepinillo.data.sync.SyncWebSocketClient
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import javax.inject.Inject

data class AuthUiState(
    val isLoading: Boolean = false,
    val googleSignInLoading: Boolean = false,
    val error: String? = null,
    val isAuthenticated: Boolean = false,
    val isGuestMode: Boolean = false,
    val showMergeDialog: Boolean = false,
    val emailVerificationRequired: String? = null, // email address awaiting verification
)

@HiltViewModel
class AuthViewModel @Inject constructor(
    @ApplicationContext private val context: Context,
    private val apiClient: PepinilloApiClient,
    private val authStore: AuthStore,
    private val userRepository: UserRepository,
    private val syncEngine: SyncEngine,
    private val initialSyncManager: InitialSyncManager,
    private val identityManager: IdentityManager,
    private val syncWebSocketClient: SyncWebSocketClient,
    private val subscriptionManager: SubscriptionManager,
) : ViewModel() {

    private val _uiState = MutableStateFlow(AuthUiState(
        isAuthenticated = authStore.getAccessToken() != null,
    ))
    val uiState: StateFlow<AuthUiState> = _uiState.asStateFlow()

    fun login(email: String, password: String) {
        if (email.isBlank() || password.isBlank()) {
            _uiState.value = _uiState.value.copy(error = context.getString(R.string.auth_error_fill_all_fields))
            return
        }
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isLoading = true, error = null)
            when (val result = apiClient.login(email, password)) {
                is NetworkResult.Success -> handleAuthSuccess(result.data, isLoading = true)
                is NetworkResult.Error -> {
                    _uiState.value = _uiState.value.copy(
                        isLoading = false,
                        error = mapAuthError(result.code, result.message),
                    )
                }
                is NetworkResult.NetworkError -> {
                    Log.e(TAG, "Login network error", result.exception)
                    _uiState.value = _uiState.value.copy(
                        isLoading = false,
                        error = mapNetworkError(result.exception),
                    )
                }
            }
        }
    }

    fun register(name: String, email: String, password: String) {
        if (name.isBlank() || email.isBlank() || password.isBlank()) {
            _uiState.value = _uiState.value.copy(error = context.getString(R.string.auth_error_fill_all_fields))
            return
        }
        val passwordError = validatePassword(password)
        if (passwordError != null) {
            _uiState.value = _uiState.value.copy(error = passwordError)
            return
        }
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isLoading = true, error = null)
            when (val result = apiClient.register(email, name, password)) {
                is NetworkResult.Success -> handleAuthSuccess(result.data, isLoading = true)
                is NetworkResult.Error -> {
                    _uiState.value = _uiState.value.copy(
                        isLoading = false,
                        error = mapAuthError(result.code, result.message),
                    )
                }
                is NetworkResult.NetworkError -> {
                    Log.e(TAG, "Register network error", result.exception)
                    _uiState.value = _uiState.value.copy(
                        isLoading = false,
                        error = mapNetworkError(result.exception),
                    )
                }
            }
        }
    }

    fun signInWithGoogle(context: Context) {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(googleSignInLoading = true, error = null)
            try {
                val googleIdOption = GetGoogleIdOption.Builder()
                    .setServerClientId(BuildConfig.GOOGLE_WEB_CLIENT_ID)
                    .setFilterByAuthorizedAccounts(false)
                    .setAutoSelectEnabled(true)
                    .build()

                val request = GetCredentialRequest.Builder()
                    .addCredentialOption(googleIdOption)
                    .build()

                val credentialManager = CredentialManager.create(context)
                val result = credentialManager.getCredential(context, request)
                val credential = result.credential

                val googleIdTokenCredential = GoogleIdTokenCredential.createFrom(credential.data)
                val idToken = googleIdTokenCredential.idToken

                when (val apiResult = apiClient.loginWithGoogle(idToken)) {
                    is NetworkResult.Success -> handleAuthSuccess(apiResult.data, isGoogle = true)
                    is NetworkResult.Error -> {
                        _uiState.value = _uiState.value.copy(
                            googleSignInLoading = false,
                            error = mapAuthError(apiResult.code, apiResult.message),
                        )
                    }
                    is NetworkResult.NetworkError -> {
                        Log.e(TAG, "Google sign-in network error", apiResult.exception)
                        _uiState.value = _uiState.value.copy(
                            googleSignInLoading = false,
                            error = mapNetworkError(apiResult.exception),
                        )
                    }
                }
            } catch (e: GetCredentialCancellationException) {
                _uiState.value = _uiState.value.copy(googleSignInLoading = false)
            } catch (e: NoCredentialException) {
                _uiState.value = _uiState.value.copy(
                    googleSignInLoading = false,
                    error = context.getString(R.string.auth_error_no_google_accounts),
                )
            } catch (e: Exception) {
                Log.e(TAG, "Google Sign-In failed", e)
                _uiState.value = _uiState.value.copy(
                    googleSignInLoading = false,
                    error = context.getString(R.string.auth_error_google_signin),
                )
            }
        }
    }

    fun logout() {
        viewModelScope.launch {
            syncWebSocketClient.disconnect()
            val refreshToken = authStore.getRefreshToken()
            apiClient.logout(refreshToken)
            subscriptionManager.logOut()
            userRepository.clearCache()
            authStore.clearAll()
            identityManager.refreshState()
            _uiState.value = AuthUiState(isAuthenticated = false)
        }
    }

    fun continueAsGuest() {
        _uiState.value = _uiState.value.copy(isGuestMode = true)
    }

    fun clearError() {
        _uiState.value = _uiState.value.copy(error = null)
    }

    // ── Data Merge Dialog Actions ──

    fun onMergeData() {
        // Data was already uploaded during initialUpload — just dismiss and proceed
        _uiState.value = _uiState.value.copy(showMergeDialog = false, isAuthenticated = true)
        viewModelScope.launch(Dispatchers.IO) { syncEngine.syncAll() }
    }

    fun onUseAccountOnly() {
        viewModelScope.launch(Dispatchers.IO) {
            _uiState.value = _uiState.value.copy(showMergeDialog = false, isLoading = true)
            when (val result = initialSyncManager.wipeAndSync()) {
                is InitialSyncManager.InitialSyncResult.Success -> {
                    Log.d(TAG, "wipeAndSync succeeded, navigating to main")
                    _uiState.value = _uiState.value.copy(isLoading = false, isAuthenticated = true)
                }
                is InitialSyncManager.InitialSyncResult.NotAuthenticated -> {
                    Log.w(TAG, "wipeAndSync returned NotAuthenticated")
                    _uiState.value = _uiState.value.copy(
                        isLoading = false,
                        error = context.getString(R.string.auth_error_session_expired),
                    )
                }
                is InitialSyncManager.InitialSyncResult.Error -> {
                    Log.e(TAG, "wipeAndSync failed", result.exception)
                    // Non-fatal: proceed authenticated — next sync will retry
                    _uiState.value = _uiState.value.copy(
                        isLoading = false,
                        isAuthenticated = true,
                        error = context.getString(R.string.auth_error_sync_download),
                    )
                }
            }
        }
    }

    fun dismissMergeDialog() {
        // Treat dismiss the same as merge (keep everything)
        onMergeData()
    }

    // ── Post-Auth Flow ──

    /**
     * Central handler for successful authentication (login, register, Google).
     * Saves tokens/user, then runs the initial upload flow if local data exists.
     */
    private suspend fun handleAuthSuccess(
        response: AuthResponse,
        isLoading: Boolean = false,
        isGoogle: Boolean = false,
    ) {
        authStore.saveTokens(
            response.tokens.accessToken,
            response.tokens.refreshToken,
        )
        authStore.saveUser(
            response.user.id,
            response.user.name,
            response.user.email,
        )
        userRepository.cacheUserFromDto(response.user)
        subscriptionManager.logIn(response.user.id)
        identityManager.refreshState()

        // Email/password users must verify before accessing data endpoints
        if (!response.user.emailVerified) {
            _uiState.value = _uiState.value.copy(
                isLoading = false,
                googleSignInLoading = false,
                emailVerificationRequired = response.user.email,
            )
            return
        }
        val hasLocal = syncEngine.hasLocalData()
        if (hasLocal) {
            Log.d(TAG, "Local data exists, running initial upload")
            val uploadResult = syncEngine.initialUpload()
            when (uploadResult) {
                is InitialUploadResult.Success -> {
                    if (uploadResult.hasExistingData) {
                        // Server already had data — ask user what to do
                        _uiState.value = _uiState.value.copy(
                            isLoading = false,
                            googleSignInLoading = false,
                            showMergeDialog = true,
                        )
                        return
                    }
                    // No conflict — proceed normally
                }
                is InitialUploadResult.NotAuthenticated -> {
                    Log.w(TAG, "Initial upload returned NotAuthenticated")
                    // Fall through — regular sync will handle it
                }
                is InitialUploadResult.Error -> {
                    Log.e(TAG, "Initial upload failed", uploadResult.exception)
                    // Non-fatal — fall through to normal sync
                }
            }
        }

        if (!hasLocal) {
            // Empty Room — pull everything from server first, then normal sync
            Log.d(TAG, "No local data, running initial sync from server")
            when (val syncResult = initialSyncManager.performInitialSync()) {
                is InitialSyncManager.InitialSyncResult.Success -> {
                    Log.d(TAG, "Initial sync from server succeeded")
                }
                is InitialSyncManager.InitialSyncResult.NotAuthenticated -> {
                    Log.w(TAG, "Initial sync returned NotAuthenticated")
                }
                is InitialSyncManager.InitialSyncResult.Error -> {
                    Log.e(TAG, "Initial sync failed, will retry on next sync", syncResult.exception)
                }
            }
        }

        // Start normal incremental sync and connect WebSocket
        viewModelScope.launch(Dispatchers.IO) { syncEngine.syncAll() }
        syncWebSocketClient.connect()
        _uiState.value = _uiState.value.copy(
            isLoading = false,
            googleSignInLoading = false,
            isAuthenticated = true,
        )
    }

    // ── Helpers ──

    fun verifyEmail(code: String) {
        val email = _uiState.value.emailVerificationRequired ?: return
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isLoading = true, error = null)
            when (val result = apiClient.verifyEmail(email, code)) {
                is NetworkResult.Success -> {
                    val response = result.data
                    authStore.saveTokens(response.tokens.accessToken, response.tokens.refreshToken)
                    authStore.saveUser(response.user.id, response.user.name, response.user.email)
                    userRepository.cacheUserFromDto(response.user)
                    identityManager.refreshState()
                    viewModelScope.launch(Dispatchers.IO) { syncEngine.syncAll() }
                    syncWebSocketClient.connect()
                    _uiState.value = _uiState.value.copy(
                        isLoading = false,
                        emailVerificationRequired = null,
                        isAuthenticated = true,
                    )
                }
                is NetworkResult.Error -> {
                    val msg = when {
                        result.message == "invalid_code" -> context.getString(R.string.auth_error_invalid_code)
                        result.message == "already_verified" -> context.getString(R.string.auth_error_already_verified)
                        result.code in 500..599 -> context.getString(R.string.auth_error_server)
                        else -> context.getString(R.string.auth_error_verification_failed)
                    }
                    _uiState.value = _uiState.value.copy(isLoading = false, error = msg)
                }
                is NetworkResult.NetworkError -> {
                    _uiState.value = _uiState.value.copy(
                        isLoading = false,
                        error = mapNetworkError(result.exception),
                    )
                }
            }
        }
    }

    fun resendVerificationEmail() {
        val email = _uiState.value.emailVerificationRequired ?: return
        viewModelScope.launch {
            apiClient.resendVerificationEmail(email)
        }
    }

    fun dismissEmailVerification() {
        // User explicitly cancels — log them out so they aren't in a broken half-authed state
        viewModelScope.launch {
            authStore.clearAll()
            identityManager.refreshState()
            _uiState.value = AuthUiState(isAuthenticated = false)
        }
    }

    fun restoreEmailVerificationState(email: String) {
        if (_uiState.value.emailVerificationRequired == null) {
            _uiState.value = _uiState.value.copy(emailVerificationRequired = email)
        }
    }

    // ── Helpers ──

    private fun mapAuthError(code: Int, message: String): String = when {
        message == "invalid_credentials" -> context.getString(R.string.auth_error_invalid_credentials)
        message == "email_already_exists" -> context.getString(R.string.auth_error_email_exists)
        message == "weak_password" -> context.getString(R.string.auth_error_weak_password)
        message == "invalid_email" -> context.getString(R.string.auth_error_invalid_email)
        message == "missing_required_fields" -> context.getString(R.string.auth_error_fill_all_fields)
        message == "invalid_google_token" -> context.getString(R.string.auth_error_invalid_google_token)
        code == 401 -> context.getString(R.string.auth_error_invalid_credentials)
        code in 500..599 -> context.getString(R.string.auth_error_server)
        else -> context.getString(R.string.auth_error_unknown, message)
    }

    private fun mapNetworkError(exception: Throwable): String = when (exception) {
        is java.net.UnknownHostException -> context.getString(R.string.auth_error_network_unresolved)
        is java.net.ConnectException -> context.getString(R.string.auth_error_network_refused)
        is java.net.SocketTimeoutException -> context.getString(R.string.auth_error_network_timeout)
        is javax.net.ssl.SSLHandshakeException -> context.getString(R.string.auth_error_ssl)
        is javax.net.ssl.SSLException -> context.getString(R.string.auth_error_ssl)
        else -> context.getString(R.string.auth_error_network_generic)
    }

    private fun validatePassword(password: String): String? {
        if (password.length < 8) return context.getString(R.string.auth_error_password_min_length)
        if (!password.any { it.isUpperCase() }) return context.getString(R.string.auth_error_password_uppercase)
        if (!password.any { it.isLowerCase() }) return context.getString(R.string.auth_error_password_lowercase)
        if (!password.any { it.isDigit() }) return context.getString(R.string.auth_error_password_digit)
        return null
    }

    private companion object {
        const val TAG = "AuthViewModel"
    }
}
