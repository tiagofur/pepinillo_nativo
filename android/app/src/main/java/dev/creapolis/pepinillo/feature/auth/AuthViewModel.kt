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
import dev.creapolis.pepinillo.BuildConfig
import dev.creapolis.pepinillo.core.auth.AuthStore
import dev.creapolis.pepinillo.core.identity.IdentityManager
import dev.creapolis.pepinillo.core.network.AuthResponse
import dev.creapolis.pepinillo.core.network.NetworkResult
import dev.creapolis.pepinillo.core.network.PepinilloApiClient
import dev.creapolis.pepinillo.data.repository.UserRepository
import dev.creapolis.pepinillo.data.sync.InitialUploadResult
import dev.creapolis.pepinillo.data.sync.SyncEngine
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
)

@HiltViewModel
class AuthViewModel @Inject constructor(
    private val apiClient: PepinilloApiClient,
    private val authStore: AuthStore,
    private val userRepository: UserRepository,
    private val syncEngine: SyncEngine,
    private val identityManager: IdentityManager,
) : ViewModel() {

    private val _uiState = MutableStateFlow(AuthUiState(
        isAuthenticated = authStore.getAccessToken() != null,
    ))
    val uiState: StateFlow<AuthUiState> = _uiState.asStateFlow()

    fun login(email: String, password: String) {
        if (email.isBlank() || password.isBlank()) {
            _uiState.value = _uiState.value.copy(error = "Please fill in all fields")
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
            _uiState.value = _uiState.value.copy(error = "Please fill in all fields")
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
                    error = "No Google accounts available on this device",
                )
            } catch (e: Exception) {
                Log.e(TAG, "Google Sign-In failed", e)
                _uiState.value = _uiState.value.copy(
                    googleSignInLoading = false,
                    error = "Google Sign-In failed. Please try again.",
                )
            }
        }
    }

    fun logout() {
        viewModelScope.launch {
            val refreshToken = authStore.getRefreshToken()
            apiClient.logout(refreshToken)
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
        // TODO: Phase 4 — wipe local Room data then pull from server via InitialSyncManager
        // For now, dismiss the dialog and proceed as normal
        _uiState.value = _uiState.value.copy(showMergeDialog = false, isAuthenticated = true)
        viewModelScope.launch(Dispatchers.IO) { syncEngine.syncAll() }
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
        identityManager.refreshState()

        // Check if local Room has data that needs uploading
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

        // No local data or upload succeeded without conflicts — start normal sync
        viewModelScope.launch(Dispatchers.IO) { syncEngine.syncAll() }
        _uiState.value = _uiState.value.copy(
            isLoading = false,
            googleSignInLoading = false,
            isAuthenticated = true,
        )
    }

    // ── Helpers ──

    private fun mapAuthError(code: Int, message: String): String = when {
        message == "invalid_credentials" -> "Invalid email or password"
        message == "email_already_exists" -> "An account with this email already exists"
        message == "weak_password" -> "Password needs 8+ chars with uppercase, lowercase, and a number"
        message == "invalid_email" -> "Please enter a valid email address"
        message == "missing_required_fields" -> "Please fill in all fields"
        message == "invalid_google_token" -> "Google Sign-In failed. Please try again."
        code == 401 -> "Invalid email or password"
        code in 500..599 -> "Server error. Please try again later."
        else -> "Error: $message"
    }

    private fun mapNetworkError(exception: Throwable): String = when (exception) {
        is java.net.UnknownHostException -> "Cannot resolve server: ${exception.message}"
        is java.net.ConnectException -> "Connection refused: ${exception.message}"
        is java.net.SocketTimeoutException -> "Connection timed out"
        is javax.net.ssl.SSLException -> "SSL error: ${exception.message}"
        is javax.net.ssl.SSLHandshakeException -> "SSL handshake failed: ${exception.message}"
        else -> "Network error: ${exception::class.simpleName} - ${exception.message}"
    }

    private fun validatePassword(password: String): String? {
        if (password.length < 8) return "Password must be at least 8 characters"
        if (!password.any { it.isUpperCase() }) return "Password needs at least one uppercase letter"
        if (!password.any { it.isLowerCase() }) return "Password needs at least one lowercase letter"
        if (!password.any { it.isDigit() }) return "Password needs at least one number"
        return null
    }

    private companion object {
        const val TAG = "AuthViewModel"
    }
}
