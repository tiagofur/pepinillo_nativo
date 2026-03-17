package dev.creapolis.pepinillo.viewmodel

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import dev.creapolis.pepinillo.data.WearDataStore
import dev.creapolis.pepinillo.data.WearMessageSender
import kotlinx.coroutines.launch

class WearViewModel(application: Application) : AndroidViewModel(application) {
    private val sender = WearMessageSender(application)

    val timerState = WearDataStore.timerState
    val tasks = WearDataStore.tasks
    val stats = WearDataStore.stats
    val pendingCommandCount = WearDataStore.pendingCommandCount
    val lastSyncAtMillis = WearDataStore.lastSyncAtMillis

    fun startTimer(mode: String) {
        viewModelScope.launch { sender.startTimer(mode) }
    }

    fun pauseTimer() {
        viewModelScope.launch { sender.pauseTimer() }
    }

    fun resumeTimer() {
        viewModelScope.launch { sender.resumeTimer() }
    }

    fun stopTimer() {
        viewModelScope.launch { sender.stopTimer() }
    }

    fun completeTask(taskId: String) {
        viewModelScope.launch { sender.completeTask(taskId) }
    }
}
