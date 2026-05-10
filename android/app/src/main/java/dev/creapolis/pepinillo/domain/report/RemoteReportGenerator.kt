package dev.creapolis.pepinillo.domain.report

import dev.creapolis.pepinillo.core.network.AIReportResponse
import dev.creapolis.pepinillo.core.network.NetworkResult
import dev.creapolis.pepinillo.core.network.PepinilloApiClient
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class RemoteReportGenerator @Inject constructor(
    private val apiClient: PepinilloApiClient,
) {
    suspend fun generate(payload: ReportPayload): AIReportResponse? {
        return when (val result = apiClient.generateAIReport(payload)) {
            is NetworkResult.Success -> result.data
            else -> null
        }
    }
}
