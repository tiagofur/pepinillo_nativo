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
import dev.creapolis.pepinillo.core.auth.PostAuthFlowResult
import dev.creapolis.pepinillo.core.auth.SessionManager
import dev.creapolis.pepinillo.core.identity.IdentityManager
import dev.creapolis.pepinillo.core.network.NetworkResult
import dev.creapolis.pepinillo.core.network.PepinilloApiClient
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
    val resendLoading: Boolean = false,
    val resendCooldownUntil: Long = 0L, // epoch millis; 0 = no cooldown
    val resendSuccess: Boolean = false,
)

@HiltViewModel
class AuthViewModel @Inject constructor(
    @param:ApplicationContext private val context: Context,
    private val apiClient: PepinilloApiClient,
    private val authStore: AuthStore,
    private val identityManager: IdentityManager,
    private val sessionManager: SessionManager,
) : ViewModel() {

    private val _uiState = MutableStateFlow(AuthUiState(
        isAuthenticated = authStore.getAccessToken() != null,
    ))
    val uiState: StateFlow<AuthUiState> = _uiState.asStateFlow()

    // ── Login ──

    fun login(email: String, password: String) {
        if (email.isBlank() || password.isBlank()) {
            _uiState.value = _uiState.value.copy(error = context.getString(R.string.auth_error_fill_all_fields))
            return
        }
        // Synchronous guard: prevent double-submit before the coroutine even launches (#341).
        if (_uiState.value.isLoading) return
        _uiState.value = _uiState.value.copy(isLoading = true, error = null)
        viewModelScope.launch {
            when (val result = apiClient.login(email, password)) {
                is NetworkResult.Success -> handleAuthSuccess(result.data)
                is NetworkResult.Error -> {
                    _uiState.value = _uiState.value.copy(
                        isLoading = false,
                        error = mapAuthError(result.code, result.message),
                    )
                }
                is NetworkResult.NetworkError -> {
                    Log.e(TAG, "Login network error: ${result.exception::class.simpleName}")
                    _uiState.value = _uiState.value.copy(
                        isLoading = false,
                        error = mapNetworkError(result.exception),
                    )
                }
            }
        }
    }

    // ── Register ──

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
        if (_uiState.value.isLoading) return
        _uiState.value = _uiState.value.copy(isLoading = true, error = null)
        viewModelScope.launch {
            when (val result = apiClient.register(email, name, password)) {
                is NetworkResult.Success -> handleAuthSuccess(result.data)
                is NetworkResult.Error -> {
                    _uiState.value = _uiState.value.copy(
                        isLoading = false,
                        error = mapAuthError(result.code, result.message),
                    )
                }
                is NetworkResult.NetworkError -> {
                    Log.e(TAG, "Register network error: ${result.exception::class.simpleName}")
                    _uiState.value = _uiState.value.copy(
                        isLoading = false,
                        error = mapNetworkError(result.exception),
                    )
                }
            }
        }
    }

    // ── Google Sign-In ──

    fun signInWithGoogle(context: Context) {
        if (_uiState.value.googleSignInLoading) return
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(googleSignInLoading = true, error = null)
            try {
                val googleIdOption = GetGoogleIdOption.Builder()
                    .setServerClientId(BuildConfig.GOOGLE_WEB_CLIENT_ID)
                    .setFilterByAuthorizedAccounts(false)
                    // Explicit account choice on return visits — auto-select can silently
                    // re-pick the wrong account for multi-account users (#350).
                    .setAutoSelectEnabled(false)
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
                    is NetworkResult.Success -> handleAuthSuccess(apiResult.data)
                    is NetworkResult.Error -> {
                        _uiState.value = _uiState.value.copy(
                            googleSignInLoading = false,
                            error = mapAuthError(apiResult.code, apiResult.message),
                        )
                    }
                    is NetworkResult.NetworkError -> {
                        Log.e(TAG, "Google sign-in network error: ${apiResult.exception::class.simpleName}")
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
                Log.e(TAG, "Google Sign-In failed: ${e::class.simpleName}")
                _uiState.value = _uiState.value.copy(
                    googleSignInLoading = false,
                    error = context.getString(R.string.auth_error_google_signin),
                )
            }
        }
    }

    // ── Logout ──

    fun logout() {
        viewModelScope.launch {
            sessionManager.signOut()
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
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(showMergeDialog = false, isAuthenticated = true)
            sessionManager.onMergeResolved()
        }
    }

    fun onUseAccountOnly() {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(showMergeDialog = false, isLoading = true)
            sessionManager.onUseAccountOnly()
            _uiState.value = _uiState.value.copy(isLoading = false, isAuthenticated = true)
        }
    }

    fun dismissMergeDialog() {
        // Treat dismiss the same as merge (keep everything)
        onMergeData()
    }

    // ── Post-Auth Flow ──

    /**
     * Central handler for successful authentication (login, register, Google).
     * Delegates token persistence + data-migration pipeline to [SessionManager].
     */
    private suspend fun handleAuthSuccess(response: dev.creapolis.pepinillo.core.network.AuthResponse) {
        when (val flow = sessionManager.completeAuthSuccess(response)) {
            is PostAuthFlowResult.Completed -> {
                // Either fully authenticated, or email verification required (check below).
                if (!response.user.emailVerified) {
                    _uiState.value = _uiState.value.copy(
                        isLoading = false,
                        googleSignInLoading = false,
                        emailVerificationRequired = response.user.email,
                    )
                } else {
                    _uiState.value = _uiState.value.copy(
                        isLoading = false,
                        googleSignInLoading = false,
                        isAuthenticated = true,
                    )
                }
            }
            is PostAuthFlowResult.MergeConflict -> {
                _uiState.value = _uiState.value.copy(
                    isLoading = false,
                    googleSignInLoading = false,
                    showMergeDialog = true,
                )
            }
        }
    }

    // ── Email Verification ──

    fun verifyEmail(code: String) {
        val email = _uiState.value.emailVerificationRequired ?: return
        if (_uiState.value.isLoading) return
        _uiState.value = _uiState.value.copy(isLoading = true, error = null)
        viewModelScope.launch {
            when (val result = apiClient.verifyEmail(email, code)) {
                is NetworkResult.Success -> {
                    val response = result.data
                    // Delegate to SessionManager so verify runs the SAME data-migration
                    // pipeline as login (initialUpload/merge/initialSync). Previously
                    // verify skipped this entirely (#335).
                    when (val flow = sessionManager.completeAuthSuccessFromVerify(
                        user = response.user,
                        tokens = response.tokens,
                    )) {
                        is PostAuthFlowResult.Completed -> {
                            _uiState.value = _uiState.value.copy(
                                isLoading = false,
                                emailVerificationRequired = null,
                                isAuthenticated = true,
                            )
                        }
                        is PostAuthFlowResult.MergeConflict -> {
                            _uiState.value = _uiState.value.copy(
                                isLoading = false,
                                emailVerificationRequired = null,
                                showMergeDialog = true,
                            )
                        }
                    }
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
        // Cooldown: prevent spamming resend (#344).
        val now = System.currentTimeMillis()
        if (_uiState.value.resendLoading || now < _uiState.value.resendCooldownUntil) return

        _uiState.value = _uiState.value.copy(resendLoading = true, resendSuccess = false, error = null)
        viewModelScope.launch {
            when (val result = apiClient.resendVerificationEmail(email)) {
                is NetworkResult.Success -> {
                    _uiState.value = _uiState.value.copy(
                        resendLoading = false,
                        resendCooldownUntil = now + RESEND_COOLDOWN_MS,
                        resendSuccess = true,
                    )
                }
                is NetworkResult.Error -> {
                    _uiState.value = _uiState.value.copy(
                        resendLoading = false,
                        error = context.getString(R.string.auth_error_resend_failed),
                    )
                }
                is NetworkResult.NetworkError -> {
                    _uiState.value = _uiState.value.copy(
                        resendLoading = false,
                        error = mapNetworkError(result.exception),
                    )
                }
            }
        }
    }

    fun dismissEmailVerification() {
        // User explicitly cancels — log them out so they aren't in a broken half-authed state
        viewModelScope.launch {
            sessionManager.signOut()
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
        // Never interpolate raw server message into UI — use a generic localized string (#342).
        else -> context.getString(R.string.auth_error_generic)
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
        const val RESEND_COOLDOWN_MS = 60_000L
    }
}
