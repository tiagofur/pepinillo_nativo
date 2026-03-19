package dev.creapolis.pepinillo.core.billing

import dev.creapolis.pepinillo.feature.focus.FocusMode
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.map
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class FeatureGate @Inject constructor(
    private val subscriptionManager: SubscriptionManager,
) {
    val subscriptionState: StateFlow<SubscriptionState> = subscriptionManager.subscriptionState

    val isPro: Boolean get() = subscriptionManager.subscriptionState.value.isPro

    fun canUseMode(mode: FocusMode): Boolean {
        if (isPro) return true
        return mode.isFreeTier
    }

    fun canAddTask(currentActiveCount: Int): Boolean {
        if (isPro) return true
        return currentActiveCount < FREE_TASK_LIMIT
    }

    fun canUseSubtasks(): Boolean = isPro

    fun canUseRecurrence(): Boolean = isPro

    fun canAccessFullAnalytics(): Boolean = isPro

    fun canUseSync(): Boolean = isPro

    fun canUseWearOS(): Boolean = isPro

    companion object {
        const val FREE_TASK_LIMIT = 3
    }
}
