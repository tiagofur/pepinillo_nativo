package dev.creapolis.pepinillo.domain.report

import dev.creapolis.pepinillo.core.billing.FeatureGate
import dev.creapolis.pepinillo.core.network.AIReportResponse
import javax.inject.Inject
import javax.inject.Singleton

interface ReportGenerator {
    suspend fun generate(payload: ReportPayload): AIReportResponse
}

@Singleton
class ReportGeneratorImpl @Inject constructor(
    private val remoteGenerator: RemoteReportGenerator,
    private val onDeviceGenerator: OnDeviceReportGenerator,
    private val templateGenerator: TemplateReportGenerator,
    private val featureGate: FeatureGate,
) : ReportGenerator {
    override suspend fun generate(payload: ReportPayload): AIReportResponse {
        val canUseAI = featureGate.canUseAI()

        if (canUseAI) {
            val remoteResult = remoteGenerator.generate(payload)
            if (remoteResult != null) return remoteResult
        }

        if (onDeviceGenerator.isAvailable()) {
            val result = onDeviceGenerator.generate(payload)
            if (result != null) return result
        }
        return templateGenerator.generate(payload)
    }
}
