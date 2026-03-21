package dev.creapolis.pepinillo.feature.profile

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import dagger.hilt.android.lifecycle.HiltViewModel
import dev.creapolis.pepinillo.core.auth.AuthStore
import dev.creapolis.pepinillo.core.network.UpdateProfileRequest
import dev.creapolis.pepinillo.data.local.entity.UserEntity
import dev.creapolis.pepinillo.data.repository.SessionRepository
import dev.creapolis.pepinillo.core.network.PepinilloApiClient
import dev.creapolis.pepinillo.data.repository.UserRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

data class ProfileUiState(
    val user: UserEntity? = null,
    val isLoggedIn: Boolean = false,
    val isLoading: Boolean = false,
    val totalFocusTimeMinutes: Long = 0,
    val totalSessions: Int = 0,
    val bestStreak: Int = 0,
    val error: String? = null,
)

@HiltViewModel
class ProfileViewModel @Inject constructor(
    private val userRepository: UserRepository,
    private val sessionRepository: SessionRepository,
    private val authStore: AuthStore,
    private val apiClient: PepinilloApiClient,
) : ViewModel() {

    private val _uiState = MutableStateFlow(ProfileUiState())
    val uiState: StateFlow<ProfileUiState> = _uiState.asStateFlow()

    init {
        // Observe auth state
        viewModelScope.launch {
            authStore.isLoggedIn.collect { loggedIn ->
                _uiState.update { it.copy(isLoggedIn = loggedIn) }
                if (loggedIn) {
                    loadProfile()
                } else {
                    _uiState.update { it.copy(user = null) }
                }
            }
        }
        // Always load local stats regardless of auth state
        loadStats()
    }

    private fun loadProfile() {
        viewModelScope.launch {
            // Observe cached user from Room
            userRepository.observeCachedUser().collect { user ->
                _uiState.update { it.copy(user = user) }
            }
        }
        // Best-effort refresh from network
        viewModelScope.launch {
            userRepository.fetchAndCacheProfile()
        }
    }

    private fun loadStats() {
        viewModelScope.launch {
            sessionRepository.getAllDaysWithSessions().collect { allDays ->
                val totalMinutes = allDays.sumOf { it.totalMinutes.toLong() }
                val totalSessions = allDays.sumOf { it.sessionsCompleted }
                val bestStreak = sessionRepository.calculateBestStreak(allDays)
                _uiState.update {
                    it.copy(
                        totalFocusTimeMinutes = totalMinutes,
                        totalSessions = totalSessions,
                        bestStreak = bestStreak,
                    )
                }
            }
        }
    }

    fun refreshProfile() {
        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true) }
            userRepository.fetchAndCacheProfile()
            _uiState.update { it.copy(isLoading = false) }
        }
    }

    fun updateName(name: String) {
        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true) }
            val result = userRepository.updateProfile(
                UpdateProfileRequest(name = name),
            )
            _uiState.update {
                it.copy(
                    isLoading = false,
                    error = result.exceptionOrNull()?.message,
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
        }
    }

    fun clearError() {
        _uiState.update { it.copy(error = null) }
    }
}
