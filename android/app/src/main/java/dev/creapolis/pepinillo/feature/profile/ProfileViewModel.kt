package dev.creapolis.pepinillo.feature.profile

import android.content.Context
import android.net.Uri
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import dagger.hilt.android.lifecycle.HiltViewModel
import dev.creapolis.pepinillo.core.auth.AuthStore
import dev.creapolis.pepinillo.core.network.NetworkResult
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

data class Achievement(
    val icon: String,
    val title: String,
    val subtitle: String,
    val isUnlocked: Boolean,
)

data class ProfileUiState(
    val user: UserEntity? = null,
    val isLoggedIn: Boolean = false,
    val isLoading: Boolean = false,
    val totalFocusTimeMinutes: Long = 0,
    val totalSessions: Int = 0,
    val bestStreak: Int = 0,
    val achievements: List<Achievement> = emptyList(),
    val error: String? = null,
    val isEditSheetVisible: Boolean = false,
    val editName: String = "",
    val editBirthDate: String? = null,
    val editImageUrl: String? = null,
    val isUploading: Boolean = false,
    val isSaving: Boolean = false,
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
                val achievements = listOf(
                    Achievement(
                        icon = "EmojiEvents",
                        title = "First Focus",
                        subtitle = "Complete your first focus session",
                        isUnlocked = totalSessions >= 1,
                    ),
                    Achievement(
                        icon = "LocalFireDepartment",
                        title = "On Fire",
                        subtitle = "Reach a 7-day streak",
                        isUnlocked = bestStreak >= 7,
                    ),
                    Achievement(
                        icon = "Star",
                        title = "Centurion",
                        subtitle = "Complete 100 sessions",
                        isUnlocked = totalSessions >= 100,
                    ),
                    Achievement(
                        icon = "Timer",
                        title = "Marathon",
                        subtitle = "Focus for 4 hours in a single day",
                        isUnlocked = totalMinutes >= 240,
                    ),
                )
                _uiState.update {
                    it.copy(
                        totalFocusTimeMinutes = totalMinutes,
                        totalSessions = totalSessions,
                        bestStreak = bestStreak,
                        achievements = achievements,
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

    fun showEditSheet() {
        val user = _uiState.value.user
        _uiState.update {
            it.copy(
                isEditSheetVisible = true,
                editName = user?.name ?: "",
                editBirthDate = user?.birthDate,
                editImageUrl = user?.imageUrl,
            )
        }
    }

    fun hideEditSheet() {
        _uiState.update { it.copy(isEditSheetVisible = false) }
    }

    fun saveProfile(name: String) {
        viewModelScope.launch {
            _uiState.update { it.copy(isSaving = true) }
            val result = userRepository.updateProfile(
                UpdateProfileRequest(name = name)
            )
            _uiState.update {
                it.copy(
                    isSaving = false,
                    isEditSheetVisible = !result.isSuccess,
                    error = result.exceptionOrNull()?.message,
                )
            }
        }
    }

    fun uploadPhoto(context: Context, uri: Uri) {
        viewModelScope.launch {
            _uiState.update { it.copy(isUploading = true) }
            try {
                val inputStream = context.contentResolver.openInputStream(uri) ?: return@launch
                val bytes = inputStream.readBytes()
                inputStream.close()
                val mimeType = context.contentResolver.getType(uri) ?: "image/jpeg"
                when (val result = apiClient.uploadProfileImage(bytes, mimeType)) {
                    is NetworkResult.Success -> {
                        _uiState.update {
                            it.copy(
                                isUploading = false,
                                editImageUrl = result.data.imageUrl,
                            )
                        }
                    }
                    is NetworkResult.Error -> {
                        _uiState.update { it.copy(isUploading = false, error = "Upload failed: ${result.message}") }
                    }
                    is NetworkResult.NetworkError -> {
                        _uiState.update { it.copy(isUploading = false, error = "No internet connection") }
                    }
                }
            } catch (e: Exception) {
                _uiState.update { it.copy(isUploading = false, error = "Failed to read image") }
            }
        }
    }

    fun clearError() {
        _uiState.update { it.copy(error = null) }
    }
}
