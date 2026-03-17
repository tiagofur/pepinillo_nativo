package dev.creapolis.pepinillo.feature.auth

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import dagger.hilt.android.lifecycle.HiltViewModel
import dev.creapolis.pepinillo.core.auth.AuthStore
import dev.creapolis.pepinillo.core.network.NetworkResult
import dev.creapolis.pepinillo.core.network.PepinilloApiClient
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import javax.inject.Inject

data class AuthUiState(
    val isLoading: Boolean = false,
    val error: String? = null,
    val isAuthenticated: Boolean = false,
)

@HiltViewModel
class AuthViewModel @Inject constructor(
    private val apiClient: PepinilloApiClient,
    private val authStore: AuthStore,
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
                    _uiState.value = _uiState.value.copy(isLoading = false, isAuthenticated = true)
                }
                is NetworkResult.Error -> {
                    _uiState.value = _uiState.value.copy(
                        isLoading = false,
                        error = if (result.code == 401) "Invalid email or password" else "Error: ${result.message}",
                    )
                }
                is NetworkResult.NetworkError -> {
                    _uiState.value = _uiState.value.copy(
                        isLoading = false,
                        error = "No internet connection",
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
                    _uiState.value = _uiState.value.copy(isLoading = false, isAuthenticated = true)
                }
                is NetworkResult.Error -> {
                    _uiState.value = _uiState.value.copy(isLoading = false, error = result.message)
                }
                is NetworkResult.NetworkError -> {
                    _uiState.value = _uiState.value.copy(isLoading = false, error = "No internet connection")
                }
            }
        }
    }

    fun logout() {
        viewModelScope.launch {
            apiClient.logout()
            authStore.clearAll()
            _uiState.value = AuthUiState(isAuthenticated = false)
        }
    }

    fun continueAsGuest() {
        _uiState.value = _uiState.value.copy(isAuthenticated = true)
    }

    fun clearError() {
        _uiState.value = _uiState.value.copy(error = null)
    }
}
