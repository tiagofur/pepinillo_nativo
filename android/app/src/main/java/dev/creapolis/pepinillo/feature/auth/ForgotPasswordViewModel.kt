package dev.creapolis.pepinillo.feature.auth

import android.util.Log
import androidx.annotation.StringRes
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import dagger.hilt.android.lifecycle.HiltViewModel
import dev.creapolis.pepinillo.R
import dev.creapolis.pepinillo.core.network.NetworkResult
import dev.creapolis.pepinillo.core.network.PepinilloApiClient
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.receiveAsFlow
import kotlinx.coroutines.launch
import javax.inject.Inject

sealed class ForgotPasswordStep {
    object EnterEmail : ForgotPasswordStep()
    object EnterCode : ForgotPasswordStep()
}

data class ForgotPasswordUiState(
    val step: ForgotPasswordStep = ForgotPasswordStep.EnterEmail,
    val email: String = "",
    val code: String = "",
    val newPassword: String = "",
    val confirmPassword: String = "",
    val isLoading: Boolean = false,
    @field:StringRes val errorMessageRes: Int? = null,
    val isPasswordVisible: Boolean = false,
    val isConfirmPasswordVisible: Boolean = false,
)

sealed class ForgotPasswordEvent {
    object NavigateBack : ForgotPasswordEvent()
    object ResetSuccess : ForgotPasswordEvent()
}

@HiltViewModel
class ForgotPasswordViewModel @Inject constructor(
    private val apiClient: PepinilloApiClient,
) : ViewModel() {

    private val _uiState = MutableStateFlow(ForgotPasswordUiState())
    val uiState: StateFlow<ForgotPasswordUiState> = _uiState.asStateFlow()

    private val _events = Channel<ForgotPasswordEvent>(Channel.BUFFERED)
    val events = _events.receiveAsFlow()

    fun onEmailChange(value: String) {
        _uiState.value = _uiState.value.copy(email = value, errorMessageRes = null)
    }

    fun onCodeChange(value: String) {
        _uiState.value = _uiState.value.copy(code = value, errorMessageRes = null)
    }

    fun onNewPasswordChange(value: String) {
        _uiState.value = _uiState.value.copy(newPassword = value, errorMessageRes = null)
    }

    fun onConfirmPasswordChange(value: String) {
        _uiState.value = _uiState.value.copy(confirmPassword = value, errorMessageRes = null)
    }

    fun togglePasswordVisibility() {
        _uiState.value = _uiState.value.copy(isPasswordVisible = !_uiState.value.isPasswordVisible)
    }

    fun toggleConfirmPasswordVisibility() {
        _uiState.value = _uiState.value.copy(isConfirmPasswordVisible = !_uiState.value.isConfirmPasswordVisible)
    }

    fun sendCode() {
        val email = _uiState.value.email.trim()
        if (email.isBlank()) {
            _uiState.value = _uiState.value.copy(errorMessageRes = R.string.forgot_enter_email)
            return
        }
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isLoading = true, errorMessageRes = null)
            when (val result = apiClient.forgotPassword(email)) {
                is NetworkResult.Success -> {
                    _uiState.value = _uiState.value.copy(
                        isLoading = false,
                        step = ForgotPasswordStep.EnterCode,
                    )
                }
                is NetworkResult.Error -> {
                    // Anti-enumeration (#347): if the email doesn't exist on the server,
                    // show the SAME success UX as if it did. This prevents an attacker
                    // from distinguishing existing vs non-existing accounts by the
                    // client's response. A genuine "account not found" is indistinguishable
                    // from "code sent" — the user simply won't receive a code.
                    if (result.message == "user_not_found" || result.message == "email_not_found") {
                        _uiState.value = _uiState.value.copy(
                            isLoading = false,
                            step = ForgotPasswordStep.EnterCode,
                        )
                    } else {
                        _uiState.value = _uiState.value.copy(
                            isLoading = false,
                            errorMessageRes = mapError(result.code, result.message),
                        )
                    }
                }
                is NetworkResult.NetworkError -> {
                    Log.e("ForgotPasswordViewModel", "Network error", result.exception)
                    _uiState.value = _uiState.value.copy(
                        isLoading = false,
                        errorMessageRes = mapNetworkError(result.exception),
                    )
                }
            }
        }
    }

    fun resendCode() {
        _uiState.value = _uiState.value.copy(
            code = "",
            newPassword = "",
            confirmPassword = "",
            errorMessageRes = null,
        )
        sendCode()
    }

    fun resetPassword() {
        val state = _uiState.value
        val passwordError = validatePassword(state.newPassword)
        if (passwordError != null) {
            _uiState.value = state.copy(errorMessageRes = passwordError)
            return
        }
        if (state.newPassword != state.confirmPassword) {
            _uiState.value = state.copy(errorMessageRes = R.string.forgot_passwords_no_match)
            return
        }
        if (state.code.isBlank()) {
            _uiState.value = state.copy(errorMessageRes = R.string.forgot_enter_code)
            return
        }
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isLoading = true, errorMessageRes = null)
            when (val result = apiClient.resetPassword(state.email.trim(), state.code.trim(), state.newPassword)) {
                is NetworkResult.Success -> {
                    _uiState.value = _uiState.value.copy(isLoading = false)
                    _events.send(ForgotPasswordEvent.ResetSuccess)
                }
                is NetworkResult.Error -> {
                    _uiState.value = _uiState.value.copy(
                        isLoading = false,
                        errorMessageRes = mapError(result.code, result.message),
                    )
                }
                is NetworkResult.NetworkError -> {
                    Log.e("ForgotPasswordViewModel", "Network error", result.exception)
                    _uiState.value = _uiState.value.copy(
                        isLoading = false,
                        errorMessageRes = mapNetworkError(result.exception),
                    )
                }
            }
        }
    }

    fun navigateBack() {
        viewModelScope.launch { _events.send(ForgotPasswordEvent.NavigateBack) }
    }

    @StringRes
    private fun validatePassword(password: String): Int? = when {
        password.length < 8 -> R.string.forgot_password_min_length
        !password.any { it.isUpperCase() } -> R.string.forgot_password_uppercase
        !password.any { it.isLowerCase() } -> R.string.forgot_password_lowercase
        !password.any { it.isDigit() } -> R.string.forgot_password_number
        else -> null
    }

    /** Map a server error to a localized StringRes — never surfaces the raw server message. */
    @StringRes
    private fun mapError(code: Int, message: String): Int = when {
        message == "invalid_code" || message == "code_expired" -> R.string.forgot_code_invalid
        // user_not_found/email_not_found intentionally NOT mapped here — sendCode()
        // handles them as success to prevent account enumeration (#347). If they reach
        // this point (e.g. resetPassword), use the generic "invalid code" path.
        message == "user_not_found" || message == "email_not_found" -> R.string.forgot_code_invalid
        message == "missing_required_fields" -> R.string.forgot_missing_fields
        code in 500..599 -> R.string.error_server
        else -> R.string.error_unknown
    }

    /** Map a network exception to a localized StringRes — never leaks exception class/message. */
    @StringRes
    private fun mapNetworkError(exception: Throwable): Int = when (exception) {
        is java.net.UnknownHostException -> R.string.error_no_connection
        is java.net.ConnectException -> R.string.error_connection_refused
        is java.net.SocketTimeoutException -> R.string.error_timeout
        is javax.net.ssl.SSLException -> R.string.error_ssl
        else -> R.string.error_unknown
    }
}
