package dev.creapolis.pepinillo.domain.report

import dev.creapolis.pepinillo.core.network.AIReportResponse
import javax.inject.Inject
import javax.inject.Singleton

interface ReportGenerator {
    suspend fun generate(payload: ReportPayload): AIReportResponse
}

@Singleton
class ReportGeneratorImpl @Inject constructor(
    private val onDeviceGenerator: OnDeviceReportGenerator,
    private val templateGenerator: TemplateReportGenerator,
) : ReportGenerator {
    override suspend fun generate(payload: ReportPayload): AIReportResponse {
        if (onDeviceGenerator.isAvailable()) {
            val result = onDeviceGenerator.generate(payload)
            if (result != null) return result
        }
        return templateGenerator.generate(payload)
    }
}
