package dev.creapolis.pepinillo.domain.report

import dev.creapolis.pepinillo.core.billing.FeatureGate
import dev.creapolis.pepinillo.core.billing.SubscriptionManager
import dev.creapolis.pepinillo.core.billing.SubscriptionState
import dev.creapolis.pepinillo.core.billing.SubscriptionTier
import dev.creapolis.pepinillo.core.network.AIReportResponse
import dev.creapolis.pepinillo.core.network.ReportInsight
import io.mockk.coEvery
import io.mockk.every
import io.mockk.mockk
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Before
import org.junit.Test

class ReportGeneratorTest {

    private lateinit var remoteGenerator: RemoteReportGenerator
    private lateinit var onDeviceGenerator: OnDeviceReportGenerator
    private lateinit var templateGenerator: TemplateReportGenerator
    private lateinit var subscriptionManager: SubscriptionManager
    private lateinit var featureGate: FeatureGate
    private lateinit var generator: ReportGeneratorImpl

    private val payload = ReportPayload(
        period = "week",
        periodStart = "2026-01-01",
        periodEnd = "2026-01-07",
        summary = ReportSummary(
            totalMinutes = 120,
            totalSessions = 5,
            completedSessions = 5,
            avgSessionMinutes = 24,
            totalInterruptions = 0,
            totalPauses = 0,
        ),
        trends = ReportTrends(0, 0, 0, 0),
        patterns = ReportPatterns(null, "9-12", "Mon", emptyMap()),
        taskBreakdown = emptyList(),
        dailyDistribution = emptyList(),
    )

    private val remoteResponse = AIReportResponse(
        title = "Remote",
        highlights = listOf("h1"),
        insights = listOf(ReportInsight("i1", "detail")),
        recommendations = listOf("r1"),
    )

    private val templateResponse = AIReportResponse(
        title = "Template",
        highlights = emptyList(),
        insights = emptyList(),
        recommendations = emptyList(),
    )

    @Before
    fun setUp() {
        remoteGenerator = mockk()
        onDeviceGenerator = mockk()
        templateGenerator = mockk()
        subscriptionManager = mockk(relaxed = true)
        featureGate = FeatureGate(subscriptionManager)
        generator = ReportGeneratorImpl(
            remoteGenerator,
            onDeviceGenerator,
            templateGenerator,
            featureGate,
        )

        every { templateGenerator.generate(any()) } returns templateResponse
        every { onDeviceGenerator.isAvailable() } returns false
    }

    @Test
    fun `uses remote generator when FeatureGate canUseAI`() = runTest {
        every { subscriptionManager.subscriptionState } returns kotlinx.coroutines.flow.MutableStateFlow(
            SubscriptionState(tier = SubscriptionTier.EVERYWHERE_MONTHLY),
        )
        coEvery { remoteGenerator.generate(payload) } returns remoteResponse

        val result = generator.generate(payload)

        assertEquals("Remote", result.title)
    }

    @Test
    fun `skips remote when free tier uses template fallback`() = runTest {
        every { subscriptionManager.subscriptionState } returns kotlinx.coroutines.flow.MutableStateFlow(
            SubscriptionState(),
        )
        coEvery { remoteGenerator.generate(payload) } returns remoteResponse

        val result = generator.generate(payload)

        assertEquals("Template", result.title)
    }
}