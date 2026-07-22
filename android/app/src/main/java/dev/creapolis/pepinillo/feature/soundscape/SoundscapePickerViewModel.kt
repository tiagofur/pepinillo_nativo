package dev.creapolis.pepinillo.feature.soundscape

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import dagger.hilt.android.lifecycle.HiltViewModel
import dev.creapolis.pepinillo.core.billing.FeatureGate
import dev.creapolis.pepinillo.domain.soundscape.Soundscape
import dev.creapolis.pepinillo.domain.soundscape.SoundscapeManager
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

data class SoundscapePickerUiState(
    val selectedSoundscape: Soundscape? = null,
    val previewingSoundscape: Soundscape? = null,
    val isPro: Boolean = false,
)

@HiltViewModel
class SoundscapePickerViewModel @Inject constructor(
    private val soundscapeManager: SoundscapeManager,
    private val featureGate: FeatureGate,
) : ViewModel() {

    private val _uiState = MutableStateFlow(
        SoundscapePickerUiState(
            selectedSoundscape = soundscapeManager.currentSoundscape,
            isPro = featureGate.isPro, // hasLocalPremium: any paid tier
        )
    )
    val uiState: StateFlow<SoundscapePickerUiState> = _uiState.asStateFlow()

    init {
        viewModelScope.launch {
            featureGate.subscriptionState.collect { subState ->
                _uiState.update { it.copy(isPro = subState.hasLocalPremium) }
            }
        }
    }

    private var previewJob: Job? = null

    fun updateSelected(soundscape: Soundscape?) {
        _uiState.value = _uiState.value.copy(selectedSoundscape = soundscape)
    }

    fun togglePreview(soundscape: Soundscape) {
        if (_uiState.value.previewingSoundscape == soundscape) {
            stopPreview()
            return
        }

        previewJob?.cancel()
        _uiState.value = _uiState.value.copy(previewingSoundscape = soundscape)

        previewJob = viewModelScope.launch {
            soundscapeManager.play(soundscape, 0.5f)
            delay(3000L)
            soundscapeManager.fadeOut()
            _uiState.value = _uiState.value.copy(previewingSoundscape = null)
        }
    }

    fun stopPreview() {
        previewJob?.cancel()
        previewJob = null
        soundscapeManager.stop()
        _uiState.value = _uiState.value.copy(previewingSoundscape = null)
    }

    fun canUseSoundscape(soundscape: Soundscape): Boolean {
        return featureGate.canUseSoundscape(soundscape)
    }

    override fun onCleared() {
        super.onCleared()
        previewJob?.cancel()
        // Don't stop the manager here — it may be playing a session soundscape
    }
}
