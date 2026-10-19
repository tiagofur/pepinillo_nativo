package dev.creapolis.pepinillo.core.billing

import org.junit.Assert.assertEquals
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
    fun `SubscriptionTier does NOT have EVERYWHERE_LIFETIME variant`() {
        val values = SubscriptionTier.values().map { it.name }
        assertFalse("EVERYWHERE_LIFETIME must be removed", values.contains("EVERYWHERE_LIFETIME"))
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
    // PepinilloProducts mapping
    // -----------------------------------------------------------------------

    @Test
    fun `PepinilloProducts maps legacy lifetime SKU to PEPINILLO_PLUS`() {
        val tier = PepinilloProducts.tierForProduct("com.pepinillo.app.pro.lifetime")
        assertTrue("com.pepinillo.app.pro.lifetime must map to PEPINILLO_PLUS", tier == SubscriptionTier.PEPINILLO_PLUS)
    }

    @Test
    fun `PepinilloProducts maps legacy monthly SKU to EVERYWHERE_MONTHLY`() {
        val tier = PepinilloProducts.tierForProduct("com.pepinillo.app.pro.monthly")
        assertTrue("com.pepinillo.app.pro.monthly must map to EVERYWHERE_MONTHLY", tier == SubscriptionTier.EVERYWHERE_MONTHLY)
    }

    @Test
    fun `PepinilloProducts maps legacy annual SKU to EVERYWHERE_ANNUAL`() {
        val tier = PepinilloProducts.tierForProduct("com.pepinillo.app.pro.annual")
        assertTrue("com.pepinillo.app.pro.annual must map to EVERYWHERE_ANNUAL", tier == SubscriptionTier.EVERYWHERE_ANNUAL)
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

    // -----------------------------------------------------------------------
    // mergeServerSubscription — stale-server downgrade guard (B4)
    // -----------------------------------------------------------------------

    @Test
    fun `server free is ignored while RC entitlement is active`() {
        // B4: RC confirmed the purchase; a stale /users/me says "free" — the active
        // entitlement (tier, product, expiry) must survive untouched.
        val current = SubscriptionState(
            tier = SubscriptionTier.EVERYWHERE_ANNUAL,
            activeProductId = "com.pepinillo.app.pro.annual",
            expirationDate = 1_000L,
        )

        val merged = mergeServerSubscription(current, SubscriptionTier.FREE, serverExpiresAt = null)

        assertEquals(current, merged)
    }

    @Test
    fun `lifetime entitlement with null expiry is preserved under server free`() {
        val current = SubscriptionState(
            tier = SubscriptionTier.PEPINILLO_PLUS,
            activeProductId = "com.pepinillo.app.pro.lifetime",
            expirationDate = null,
        )

        val merged = mergeServerSubscription(current, SubscriptionTier.FREE, serverExpiresAt = 500L)

        assertEquals(current, merged)
    }

    @Test
    fun `server free applies when RC has no active entitlement`() {
        val merged = mergeServerSubscription(
            current = SubscriptionState(tier = SubscriptionTier.FREE),
            serverTier = SubscriptionTier.FREE,
            serverExpiresAt = null,
        )

        assertEquals(SubscriptionTier.FREE, merged.tier)
        assertFalse(merged.hasLocalPremium)
    }

    @Test
    fun `server paid raises a free tier`() {
        val merged = mergeServerSubscription(
            current = SubscriptionState(tier = SubscriptionTier.FREE),
            serverTier = SubscriptionTier.EVERYWHERE_MONTHLY,
            serverExpiresAt = 900L,
        )

        assertEquals(SubscriptionTier.EVERYWHERE_MONTHLY, merged.tier)
        assertEquals(900L, merged.expirationDate)
    }

    @Test
    fun `server paid extends expiry when later than current`() {
        val merged = mergeServerSubscription(
            current = SubscriptionState(tier = SubscriptionTier.EVERYWHERE_ANNUAL, expirationDate = 900L),
            serverTier = SubscriptionTier.EVERYWHERE_ANNUAL,
            serverExpiresAt = 1_500L,
        )

        assertEquals(1_500L, merged.expirationDate)
    }

    @Test
    fun `server paid does not shorten expiry when earlier than current`() {
        val merged = mergeServerSubscription(
            current = SubscriptionState(tier = SubscriptionTier.EVERYWHERE_ANNUAL, expirationDate = 1_500L),
            serverTier = SubscriptionTier.EVERYWHERE_MONTHLY,
            serverExpiresAt = 900L,
        )

        assertEquals(1_500L, merged.expirationDate)
    }
}
