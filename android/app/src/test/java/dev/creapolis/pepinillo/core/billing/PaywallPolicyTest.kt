package dev.creapolis.pepinillo.core.billing

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class PaywallPolicyTest {

    @Test
    fun pepinilloPlusUserCanOpenPaywallForEverywhereUpgrade() {
        val state = SubscriptionState(tier = SubscriptionTier.PEPINILLO_PLUS)
        assertFalse(
            PaywallPolicy.shouldAutoDismiss(state, PepinilloProducts.EVERYWHERE_ANNUAL),
        )
        assertFalse(
            PaywallPolicy.shouldAutoDismiss(state, PepinilloProducts.EVERYWHERE_MONTHLY),
        )
    }

    @Test
    fun everywhereUserAutoDismissesWhenSelectingSubscription() {
        val state = SubscriptionState(tier = SubscriptionTier.EVERYWHERE_ANNUAL)
        assertTrue(
            PaywallPolicy.shouldAutoDismiss(state, PepinilloProducts.EVERYWHERE_ANNUAL),
        )
    }

    @Test
    fun pepinilloPlusUserAutoDismissesWhenSelectingLifetime() {
        val state = SubscriptionState(tier = SubscriptionTier.PEPINILLO_PLUS)
        assertTrue(
            PaywallPolicy.shouldAutoDismiss(state, PepinilloProducts.PEPINILLO_PLUS),
        )
    }

    @Test
    fun freeUserNeverAutoDismisses() {
        val state = SubscriptionState()
        assertFalse(PaywallPolicy.shouldAutoDismiss(state, PepinilloProducts.EVERYWHERE_ANNUAL))
    }
}