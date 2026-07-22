package dev.creapolis.pepinillo.core.billing

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class SubscriptionMapperTest {

    @Test
    fun `PurchaseFlowResult Pending is sealed class member`() {
        val result: PurchaseFlowResult = PurchaseFlowResult.Pending
        assertTrue(result is PurchaseFlowResult.Pending)
    }

    @Test
    fun `PurchaseResult Pending enum value exists`() {
        assertEquals(PurchaseResult.Pending, PurchaseResult.valueOf("Pending"))
    }
}
