package dev.creapolis.pepinillo.domain.report

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
    private val userRepository: dev.creapolis.pepinillo.data.repository.UserRepository,
) : ReportGenerator {
    override suspend fun generate(payload: ReportPayload): AIReportResponse {
        val user = userRepository.getCachedUser()
        val isEverywhere = user?.subscriptionTier?.contains("everywhere") == true

        if (isEverywhere) {
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
