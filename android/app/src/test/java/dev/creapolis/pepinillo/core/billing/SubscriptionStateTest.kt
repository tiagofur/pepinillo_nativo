package dev.creapolis.pepinillo.core.billing

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Tests for the SubscriptionTier enum and capability flags on SubscriptionState.
 *
 * Spec: android-subscription-tier-model
 */
class SubscriptionStateTest {

    // -----------------------------------------------------------------------
    // Tier enum membership
    // -----------------------------------------------------------------------

    @Test
    fun `SubscriptionTier has PEPINILLO_PLUS variant`() {
        val values = SubscriptionTier.values().map { it.name }
        assertTrue("PEPINILLO_PLUS must exist", values.contains("PEPINILLO_PLUS"))
    }

    @Test
    fun `SubscriptionTier has EVERYWHERE_MONTHLY variant`() {
        val values = SubscriptionTier.values().map { it.name }
        assertTrue("EVERYWHERE_MONTHLY must exist", values.contains("EVERYWHERE_MONTHLY"))
    }

    @Test
    fun `SubscriptionTier has EVERYWHERE_ANNUAL variant`() {
        val values = SubscriptionTier.values().map { it.name }
        assertTrue("EVERYWHERE_ANNUAL must exist", values.contains("EVERYWHERE_ANNUAL"))
    }

    @Test
    fun `SubscriptionTier has EVERYWHERE_LIFETIME variant`() {
        val values = SubscriptionTier.values().map { it.name }
        assertTrue("EVERYWHERE_LIFETIME must exist", values.contains("EVERYWHERE_LIFETIME"))
    }

    @Test
    fun `SubscriptionTier does NOT have PRO_MONTHLY`() {
        val values = SubscriptionTier.values().map { it.name }
        assertFalse("PRO_MONTHLY must be removed", values.contains("PRO_MONTHLY"))
    }

    @Test
    fun `SubscriptionTier does NOT have PRO_YEARLY`() {
        val values = SubscriptionTier.values().map { it.name }
        assertFalse("PRO_YEARLY must be removed", values.contains("PRO_YEARLY"))
    }

    @Test
    fun `SubscriptionTier does NOT have LIFETIME (old name)`() {
        // Old bare LIFETIME is replaced by EVERYWHERE_LIFETIME
        val values = SubscriptionTier.values().map { it.name }
        assertFalse("bare LIFETIME must be removed", values.contains("LIFETIME"))
    }

    // -----------------------------------------------------------------------
    // Capability flags — FREE
    // -----------------------------------------------------------------------

    @Test
    fun `FREE tier hasLocalPremium = false`() {
        val state = SubscriptionState(tier = SubscriptionTier.FREE)
        assertFalse(state.hasLocalPremium)
    }

    @Test
    fun `FREE tier canSync = false`() {
        val state = SubscriptionState(tier = SubscriptionTier.FREE)
        assertFalse(state.canSync)
    }

    @Test
    fun `FREE tier isPepinilloPlus = false`() {
        val state = SubscriptionState(tier = SubscriptionTier.FREE)
        assertFalse(state.isPepinilloPlus)
    }

    // -----------------------------------------------------------------------
    // Capability flags — PEPINILLO_PLUS
    // -----------------------------------------------------------------------

    @Test
    fun `PEPINILLO_PLUS tier hasLocalPremium = true`() {
        val state = SubscriptionState(tier = SubscriptionTier.PEPINILLO_PLUS)
        assertTrue(state.hasLocalPremium)
    }

    @Test
    fun `PEPINILLO_PLUS tier canSync = false`() {
        val state = SubscriptionState(tier = SubscriptionTier.PEPINILLO_PLUS)
        assertFalse(state.canSync)
    }

    @Test
    fun `PEPINILLO_PLUS tier isPepinilloPlus = true`() {
        val state = SubscriptionState(tier = SubscriptionTier.PEPINILLO_PLUS)
        assertTrue(state.isPepinilloPlus)
    }

    // -----------------------------------------------------------------------
    // Capability flags — EVERYWHERE_MONTHLY
    // -----------------------------------------------------------------------

    @Test
    fun `EVERYWHERE_MONTHLY tier hasLocalPremium = true`() {
        val state = SubscriptionState(tier = SubscriptionTier.EVERYWHERE_MONTHLY)
        assertTrue(state.hasLocalPremium)
    }

    @Test
    fun `EVERYWHERE_MONTHLY tier canSync = true`() {
        val state = SubscriptionState(tier = SubscriptionTier.EVERYWHERE_MONTHLY)
        assertTrue(state.canSync)
    }

    @Test
    fun `EVERYWHERE_MONTHLY tier isPepinilloPlus = false`() {
        val state = SubscriptionState(tier = SubscriptionTier.EVERYWHERE_MONTHLY)
        assertFalse(state.isPepinilloPlus)
    }

    // -----------------------------------------------------------------------
    // Capability flags — EVERYWHERE_ANNUAL
    // -----------------------------------------------------------------------

    @Test
    fun `EVERYWHERE_ANNUAL tier canSync = true`() {
        val state = SubscriptionState(tier = SubscriptionTier.EVERYWHERE_ANNUAL)
        assertTrue(state.canSync)
    }

    @Test
    fun `EVERYWHERE_ANNUAL tier hasLocalPremium = true`() {
        val state = SubscriptionState(tier = SubscriptionTier.EVERYWHERE_ANNUAL)
        assertTrue(state.hasLocalPremium)
    }

    @Test
    fun `EVERYWHERE_ANNUAL tier isPepinilloPlus = false`() {
        val state = SubscriptionState(tier = SubscriptionTier.EVERYWHERE_ANNUAL)
        assertFalse(state.isPepinilloPlus)
    }

    // -----------------------------------------------------------------------
    // Capability flags — EVERYWHERE_LIFETIME
    // -----------------------------------------------------------------------

    @Test
    fun `EVERYWHERE_LIFETIME tier canSync = true`() {
        val state = SubscriptionState(tier = SubscriptionTier.EVERYWHERE_LIFETIME)
        assertTrue(state.canSync)
    }

    @Test
    fun `EVERYWHERE_LIFETIME tier hasLocalPremium = true`() {
        val state = SubscriptionState(tier = SubscriptionTier.EVERYWHERE_LIFETIME)
        assertTrue(state.hasLocalPremium)
    }

    @Test
    fun `EVERYWHERE_LIFETIME tier isPepinilloPlus = false`() {
        val state = SubscriptionState(tier = SubscriptionTier.EVERYWHERE_LIFETIME)
        assertFalse(state.isPepinilloPlus)
    }

    // -----------------------------------------------------------------------
    // Default state
    // -----------------------------------------------------------------------

    @Test
    fun `default SubscriptionState is FREE`() {
        val state = SubscriptionState()
        assertFalse(state.hasLocalPremium)
        assertFalse(state.canSync)
        assertFalse(state.isPepinilloPlus)
    }
}
