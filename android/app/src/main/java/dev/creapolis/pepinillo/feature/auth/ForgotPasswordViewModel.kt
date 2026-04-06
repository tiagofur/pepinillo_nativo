package dev.creapolis.pepinillo.feature.auth

import android.util.Log
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import dagger.hilt.android.lifecycle.HiltViewModel
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
    val errorMessage: String? = null,
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
        _uiState.value = _uiState.value.copy(email = value, errorMessage = null)
    }

    fun onCodeChange(value: String) {
        _uiState.value = _uiState.value.copy(code = value, errorMessage = null)
    }

    fun onNewPasswordChange(value: String) {
        _uiState.value = _uiState.value.copy(newPassword = value, errorMessage = null)
    }

    fun onConfirmPasswordChange(value: String) {
        _uiState.value = _uiState.value.copy(confirmPassword = value, errorMessage = null)
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
            _uiState.value = _uiState.value.copy(errorMessage = "Please enter your email address")
            return
        }
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isLoading = true, errorMessage = null)
            when (val result = apiClient.forgotPassword(email)) {
                is NetworkResult.Success -> {
                    _uiState.value = _uiState.value.copy(
                        isLoading = false,
                        step = ForgotPasswordStep.EnterCode,
                    )
                }
                is NetworkResult.Error -> {
                    _uiState.value = _uiState.value.copy(
                        isLoading = false,
                        errorMessage = mapError(result.code, result.message),
                    )
                }
                is NetworkResult.NetworkError -> {
                    Log.e("ForgotPasswordViewModel", "Network error", result.exception)
                    _uiState.value = _uiState.value.copy(
                        isLoading = false,
                        errorMessage = mapNetworkError(result.exception),
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
            errorMessage = null,
        )
        sendCode()
    }

    fun resetPassword() {
        val state = _uiState.value
        val passwordError = validatePassword(state.newPassword)
        if (passwordError != null) {
            _uiState.value = state.copy(errorMessage = passwordError)
            return
        }
        if (state.newPassword != state.confirmPassword) {
            _uiState.value = state.copy(errorMessage = "Passwords do not match")
            return
        }
        if (state.code.isBlank()) {
            _uiState.value = state.copy(errorMessage = "Please enter the code from your email")
            return
        }
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isLoading = true, errorMessage = null)
            when (val result = apiClient.resetPassword(state.email.trim(), state.code.trim(), state.newPassword)) {
                is NetworkResult.Success -> {
                    _uiState.value = _uiState.value.copy(isLoading = false)
                    _events.send(ForgotPasswordEvent.ResetSuccess)
                }
                is NetworkResult.Error -> {
                    _uiState.value = _uiState.value.copy(
                        isLoading = false,
                        errorMessage = mapError(result.code, result.message),
                    )
                }
                is NetworkResult.NetworkError -> {
                    Log.e("ForgotPasswordViewModel", "Network error", result.exception)
                    _uiState.value = _uiState.value.copy(
                        isLoading = false,
                        errorMessage = mapNetworkError(result.exception),
                    )
                }
            }
        }
    }

    fun navigateBack() {
        viewModelScope.launch { _events.send(ForgotPasswordEvent.NavigateBack) }
    }

    private fun validatePassword(password: String): String? {
        if (password.length < 8) return "Password must be at least 8 characters"
        if (!password.any { it.isUpperCase() }) return "Password needs at least one uppercase letter"
        if (!password.any { it.isLowerCase() }) return "Password needs at least one lowercase letter"
        if (!password.any { it.isDigit() }) return "Password needs at least one number"
        return null
    }

    private fun mapError(code: Int, message: String): String = when {
        message == "invalid_code" || message == "code_expired" -> "The code is invalid or has expired. Please request a new one."
        message == "user_not_found" || message == "email_not_found" -> "No account found with that email address"
        message == "missing_required_fields" -> "Please fill in all fields"
        code in 500..599 -> "Server error. Please try again later."
        else -> "Error: $message"
    }

    private fun mapNetworkError(exception: Throwable): String = when (exception) {
        is java.net.UnknownHostException -> "Cannot resolve server: ${exception.message}"
        is java.net.ConnectException -> "Connection refused: ${exception.message}"
        is java.net.SocketTimeoutException -> "Connection timed out"
        is javax.net.ssl.SSLException -> "SSL error: ${exception.message}"
        else -> "Network error: ${exception::class.simpleName} - ${exception.message}"
    }
}
