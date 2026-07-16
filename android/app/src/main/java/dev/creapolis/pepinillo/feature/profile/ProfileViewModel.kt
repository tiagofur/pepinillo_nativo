package dev.creapolis.pepinillo.feature.profile

import android.content.Context
import android.net.Uri
import androidx.annotation.StringRes
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import dagger.hilt.android.lifecycle.HiltViewModel
import dev.creapolis.pepinillo.R
import dev.creapolis.pepinillo.core.auth.AuthStore
import dev.creapolis.pepinillo.core.auth.SessionManager
import dev.creapolis.pepinillo.core.billing.SubscriptionManager
import dev.creapolis.pepinillo.core.network.NetworkResult
import dev.creapolis.pepinillo.core.network.UpdateProfileRequest
import dev.creapolis.pepinillo.data.local.entity.UserEntity
import dev.creapolis.pepinillo.data.repository.SessionRepository
import dev.creapolis.pepinillo.core.network.PepinilloApiClient
import dev.creapolis.pepinillo.data.repository.UserRepository
import dev.creapolis.pepinillo.data.sync.SyncWebSocketClient
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

data class Achievement(
    val icon: String,
    val titleRes: Int,
    val subtitleRes: Int,
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
    val errorRes: Int? = null,
    val isEditSheetVisible: Boolean = false,
    val editName: String = "",
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
    private val syncWebSocketClient: SyncWebSocketClient,
    private val subscriptionManager: SubscriptionManager,
    private val sessionManager: SessionManager,
) : ViewModel() {

    private val _uiState = MutableStateFlow(ProfileUiState())
    val uiState: StateFlow<ProfileUiState> = _uiState.asStateFlow()

    init {
        // Observe auth state
        viewModelScope.launch {
            authStore.isLoggedIn.collect { loggedIn ->
                _uiState.update {
                    it.copy(
                        isLoggedIn = loggedIn,
                        isLoading = loggedIn, // show loading until user data arrives
                    )
                }
                if (loggedIn) {
                    loadProfile()
                } else {
                    _uiState.update { it.copy(user = null, isLoading = false) }
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
                _uiState.update { it.copy(user = user, isLoading = false) }
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
                        titleRes = R.string.achievement_first_focus_title,
                        subtitleRes = R.string.achievement_first_focus_subtitle,
                        isUnlocked = totalSessions >= 1,
                    ),
                    Achievement(
                        icon = "LocalFireDepartment",
                        titleRes = R.string.achievement_on_fire_title,
                        subtitleRes = R.string.achievement_on_fire_subtitle,
                        isUnlocked = bestStreak >= 7,
                    ),
                    Achievement(
                        icon = "Star",
                        titleRes = R.string.achievement_centurion_title,
                        subtitleRes = R.string.achievement_centurion_subtitle,
                        isUnlocked = totalSessions >= 100,
                    ),
                    Achievement(
                        icon = "Timer",
                        titleRes = R.string.achievement_marathon_title,
                        subtitleRes = R.string.achievement_marathon_subtitle,
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
                    errorRes = if (result.isFailure) R.string.error_unknown else null,
                )
            }
        }
    }

    /**
     * Sign out via [SessionManager] — the single source of truth that guarantees
     * WS disconnect, server logout, RC logOut, Room wipe, auth clear, and identity
     * refresh all happen in order. Returns when complete so the caller can navigate
     * only after tokens are actually cleared (#351).
     */
    fun logout(onComplete: () -> Unit = {}) {
        viewModelScope.launch {
            sessionManager.signOut()
            _uiState.update { it.copy(isLoading = false, isLoggedIn = false, user = null) }
            onComplete()
        }
    }

    /**
     * Permanently delete the account via [SessionManager], then run full local cleanup.
     * [onSuccess] fires only after the wipe is complete.
     */
    fun deleteAccount(onSuccess: () -> Unit) {
        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true) }
            val success = sessionManager.deleteAccount()
            if (success) {
                _uiState.update { it.copy(isLoading = false, isLoggedIn = false, user = null) }
                onSuccess()
            } else {
                _uiState.update { it.copy(isLoading = false, errorRes = R.string.error_delete_account_failed) }
            }
        }
    }

    fun showEditSheet() {
        val user = _uiState.value.user
        _uiState.update {
            it.copy(
                isEditSheetVisible = true,
                editName = user?.name ?: "",
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
                    errorRes = if (result.isFailure) R.string.error_unknown else null,
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
                        _uiState.update { it.copy(isUploading = false, errorRes = R.string.error_upload_failed) }
                    }
                    is NetworkResult.NetworkError -> {
                        _uiState.update { it.copy(isUploading = false, errorRes = R.string.error_no_connection) }
                    }
                }
            } catch (e: Exception) {
                _uiState.update { it.copy(isUploading = false, errorRes = R.string.error_read_image) }
            }
        }
    }

    fun clearError() {
        _uiState.update { it.copy(errorRes = null) }
    }
}
