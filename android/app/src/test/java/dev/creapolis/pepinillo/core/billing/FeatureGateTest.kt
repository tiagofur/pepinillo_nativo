package dev.creapolis.pepinillo.core.billing

import io.mockk.every
import io.mockk.mockk
import kotlinx.coroutines.flow.MutableStateFlow
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

/**
 * Tests for FeatureGate capability-flag routing.
 *
 * Spec: android-subscription-tier-model — "FeatureGate.canUseSync() reflects canSync"
 */
class FeatureGateTest {

    private lateinit var subscriptionManager: SubscriptionManager
    private lateinit var featureGate: FeatureGate

    private fun buildGate(tier: SubscriptionTier): FeatureGate {
        subscriptionManager = mockk(relaxed = true)
        every { subscriptionManager.subscriptionState } returns MutableStateFlow(
            SubscriptionState(tier = tier)
        )
        return FeatureGate(subscriptionManager)
    }

    // -----------------------------------------------------------------------
    // canUseSync — routes through canSync
    // -----------------------------------------------------------------------

    @Test
    fun `canUseSync returns false for FREE tier`() {
        val gate = buildGate(SubscriptionTier.FREE)
        assertFalse(gate.canUseSync())
    }

    @Test
    fun `canUseSync returns false for PEPINILLO_PLUS tier`() {
        val gate = buildGate(SubscriptionTier.PEPINILLO_PLUS)
        assertFalse(gate.canUseSync())
    }

    @Test
    fun `canUseSync returns true for EVERYWHERE_MONTHLY`() {
        val gate = buildGate(SubscriptionTier.EVERYWHERE_MONTHLY)
        assertTrue(gate.canUseSync())
    }

    @Test
    fun `canUseSync returns true for EVERYWHERE_ANNUAL`() {
        val gate = buildGate(SubscriptionTier.EVERYWHERE_ANNUAL)
        assertTrue(gate.canUseSync())
    }

    // -----------------------------------------------------------------------
    // hasLocalPremium gates (all other feature gates)
    // -----------------------------------------------------------------------

    @Test
    fun `canUseMode premium returns false for FREE tier`() {
        val gate = buildGate(SubscriptionTier.FREE)
        assertFalse(gate.canUseMode(dev.creapolis.pepinillo.feature.focus.FocusMode.Flow))
    }

    @Test
    fun `canUseMode premium returns true for PEPINILLO_PLUS tier`() {
        val gate = buildGate(SubscriptionTier.PEPINILLO_PLUS)
        assertTrue(gate.canUseMode(dev.creapolis.pepinillo.feature.focus.FocusMode.Flow))
    }

    @Test
    fun `canUseMode premium returns true for EVERYWHERE_MONTHLY tier`() {
        val gate = buildGate(SubscriptionTier.EVERYWHERE_MONTHLY)
        assertTrue(gate.canUseMode(dev.creapolis.pepinillo.feature.focus.FocusMode.Flow))
    }

    @Test
    fun `canUseSubtasks returns false for FREE tier`() {
        val gate = buildGate(SubscriptionTier.FREE)
        assertFalse(gate.canUseSubtasks())
    }

    @Test
    fun `canUseSubtasks returns true for PEPINILLO_PLUS tier`() {
        val gate = buildGate(SubscriptionTier.PEPINILLO_PLUS)
        assertTrue(gate.canUseSubtasks())
    }

    @Test
    fun `canUseRecurrence returns false for FREE tier`() {
        val gate = buildGate(SubscriptionTier.FREE)
        assertFalse(gate.canUseRecurrence())
    }

    @Test
    fun `canUseRecurrence returns true for EVERYWHERE_ANNUAL tier`() {
        val gate = buildGate(SubscriptionTier.EVERYWHERE_ANNUAL)
        assertTrue(gate.canUseRecurrence())
    }

    @Test
    fun `canAccessFullAnalytics returns false for FREE tier`() {
        val gate = buildGate(SubscriptionTier.FREE)
        assertFalse(gate.canAccessFullAnalytics())
    }

    @Test
    fun `canAccessFullAnalytics returns true for PEPINILLO_PLUS tier`() {
        val gate = buildGate(SubscriptionTier.PEPINILLO_PLUS)
        assertTrue(gate.canAccessFullAnalytics())
    }

    @Test
    fun `canUseWearOS returns false for FREE tier`() {
        val gate = buildGate(SubscriptionTier.FREE)
        assertFalse(gate.canUseWearOS())
    }

    @Test
    fun `canUseWearOS returns true for PEPINILLO_PLUS tier`() {
        val gate = buildGate(SubscriptionTier.PEPINILLO_PLUS)
        assertTrue(gate.canUseWearOS())
    }

    // -----------------------------------------------------------------------
    // isPro backward-compat alias still reflects hasLocalPremium
    // -----------------------------------------------------------------------

    @Test
    fun `isPro is false for FREE tier`() {
        val gate = buildGate(SubscriptionTier.FREE)
        assertFalse(gate.isPro)
    }

    @Test
    fun `isPro is true for PEPINILLO_PLUS tier`() {
        val gate = buildGate(SubscriptionTier.PEPINILLO_PLUS)
        assertTrue(gate.isPro)
    }
}
