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
import dev.creapolis.pepinillo.core.network.NetworkResult
import dev.creapolis.pepinillo.core.network.PepinilloApiClient
import dev.creapolis.pepinillo.data.repository.UserRepository
import dev.creapolis.pepinillo.data.sync.SyncEngine
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
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
)

@HiltViewModel
class AuthViewModel @Inject constructor(
    private val apiClient: PepinilloApiClient,
    private val authStore: AuthStore,
    private val userRepository: UserRepository,
    private val syncEngine: SyncEngine,
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
                is NetworkResult.Success -> {
                    authStore.saveTokens(
                        result.data.tokens.accessToken,
                        result.data.tokens.refreshToken,
                    )
                    authStore.saveUser(
                        result.data.user.id,
                        result.data.user.name,
                        result.data.user.email,
                    )
                    userRepository.cacheUserFromDto(result.data.user)
                    CoroutineScope(SupervisorJob() + Dispatchers.IO).launch { syncEngine.syncAll() }
                    _uiState.value = _uiState.value.copy(isLoading = false, isAuthenticated = true)
                }
                is NetworkResult.Error -> {
                    _uiState.value = _uiState.value.copy(
                        isLoading = false,
                        error = mapAuthError(result.code, result.message),
                    )
                }
                is NetworkResult.NetworkError -> {
                    Log.e("AuthViewModel", "Login network error", result.exception)
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
                is NetworkResult.Success -> {
                    authStore.saveTokens(
                        result.data.tokens.accessToken,
                        result.data.tokens.refreshToken,
                    )
                    authStore.saveUser(
                        result.data.user.id,
                        result.data.user.name,
                        result.data.user.email,
                    )
                    userRepository.cacheUserFromDto(result.data.user)
                    CoroutineScope(SupervisorJob() + Dispatchers.IO).launch { syncEngine.syncAll() }
                    _uiState.value = _uiState.value.copy(isLoading = false, isAuthenticated = true)
                }
                is NetworkResult.Error -> {
                    _uiState.value = _uiState.value.copy(
                        isLoading = false,
                        error = mapAuthError(result.code, result.message),
                    )
                }
                is NetworkResult.NetworkError -> {
                    Log.e("AuthViewModel", "Register network error", result.exception)
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
                    is NetworkResult.Success -> {
                        authStore.saveTokens(
                            apiResult.data.tokens.accessToken,
                            apiResult.data.tokens.refreshToken,
                        )
                        authStore.saveUser(
                            apiResult.data.user.id,
                            apiResult.data.user.name,
                            apiResult.data.user.email,
                        )
                        userRepository.cacheUserFromDto(apiResult.data.user)
                        CoroutineScope(SupervisorJob() + Dispatchers.IO).launch { syncEngine.syncAll() }
                        _uiState.value = _uiState.value.copy(googleSignInLoading = false, isAuthenticated = true)
                    }
                    is NetworkResult.Error -> {
                        _uiState.value = _uiState.value.copy(
                            googleSignInLoading = false,
                            error = mapAuthError(apiResult.code, apiResult.message),
                        )
                    }
                    is NetworkResult.NetworkError -> {
                        Log.e("AuthViewModel", "Google sign-in network error", apiResult.exception)
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
                Log.e("AuthViewModel", "Google Sign-In failed", e)
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
            _uiState.value = AuthUiState(isAuthenticated = false)
        }
    }

    fun continueAsGuest() {
        _uiState.value = _uiState.value.copy(isGuestMode = true)
    }

    fun clearError() {
        _uiState.value = _uiState.value.copy(error = null)
    }

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
}
