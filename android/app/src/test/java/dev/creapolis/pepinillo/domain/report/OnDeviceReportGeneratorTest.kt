package dev.creapolis.pepinillo.domain.report

import android.content.Context
import io.mockk.mockk
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Before
import org.junit.Test

class OnDeviceReportGeneratorTest {

    private lateinit var context: Context
    private lateinit var generator: OnDeviceReportGenerator

    @Before
    fun setup() {
        context = mockk(relaxed = true)
        generator = OnDeviceReportGenerator(context)
    }

    @Test
    fun `isAvailable returns false while on-device generation is stubbed`() = runTest {
        val available = generator.isAvailable()

        assertFalse(available)
    }

    @Test
    fun `generate returns null while on-device generation is stubbed`() = runTest {
        val result = generator.generate(createDummyPayload())

        assertNull(result)
    }

    private fun createDummyPayload() = ReportPayload(
        period = "Semana",
        periodStart = "2025-01-01",
        periodEnd = "2025-01-07",
        summary = ReportSummary(
            totalMinutes = 120,
            totalSessions = 5,
            completedSessions = 4,
            avgSessionMinutes = 24,
            totalInterruptions = 1,
            totalPauses = 0,
        ),
        trends = ReportTrends(
            minutesChange = 20,
            sessionsChange = 1,
            previousTotalMinutes = 100,
            previousTotalSessions = 4,
        ),
        patterns = ReportPatterns(
            dominantMode = "Pomodoro",
            peakHourRange = "09:00 - 11:00",
            bestDayOfWeek = "Martes",
            modeDistribution = mapOf("Pomodoro" to 5),
        ),
        taskBreakdown = emptyList(),
        dailyDistribution = emptyList(),
    )
}
