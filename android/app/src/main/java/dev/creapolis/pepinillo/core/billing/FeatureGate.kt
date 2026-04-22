package dev.creapolis.pepinillo.core.billing

import dev.creapolis.pepinillo.domain.soundscape.Soundscape
import dev.creapolis.pepinillo.feature.focus.FocusMode
import kotlinx.coroutines.flow.StateFlow
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class FeatureGate @Inject constructor(
    private val subscriptionManager: SubscriptionManager,
) {
    val subscriptionState: StateFlow<SubscriptionState> = subscriptionManager.subscriptionState

    /** True for any paid user (Pepinillo+ or any Everywhere+ tier). */
    val isPro: Boolean get() = subscriptionManager.subscriptionState.value.hasLocalPremium

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

    /** Only Everywhere+ users can sync to the backend. */
    fun canUseSync(): Boolean = subscriptionManager.subscriptionState.value.canSync

    fun canUseWearOS(): Boolean = isPro

    fun canUseSoundscape(soundscape: Soundscape): Boolean = isPro || !soundscape.requiresPro

    companion object {
        const val FREE_TASK_LIMIT = 3
    }
}
