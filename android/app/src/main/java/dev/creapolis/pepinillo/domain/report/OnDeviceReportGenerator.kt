package dev.creapolis.pepinillo.domain.report

import android.content.Context
import android.util.Log
import dagger.hilt.android.qualifiers.ApplicationContext
import dev.creapolis.pepinillo.core.network.AIReportResponse
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Stub for on-device AI report generation via Gemini Nano.
 *
 * Currently returns null (falls back to TemplateReportGenerator) because
 * the ML Kit GenAI SDK is not yet publicly available in Maven repositories.
 *
 * When the SDK becomes available, this class will use Gemini Nano's
 * summarization API to generate richer, AI-powered productivity insights.
 */
@Singleton
class OnDeviceReportGenerator @Inject constructor(
    @ApplicationContext private val context: Context,
) {
    companion object {
        private const val TAG = "OnDeviceReportGen"
    }

    @Suppress("UNUSED_PARAMETER")
    suspend fun isAvailable(): Boolean {
        // TODO: Check Gemini Nano availability when ML Kit GenAI SDK is published
        // val summarizer = Summarization.getClient(...)
        // val status = summarizer.checkFeatureStatus().await()
        // return status == FeatureStatus.AVAILABLE
        Log.d(TAG, "On-device AI not yet available — using template fallback")
        return false
    }

    @Suppress("UNUSED_PARAMETER")
    suspend fun generate(payload: ReportPayload): AIReportResponse? {
        // TODO: Implement when ML Kit GenAI SDK is available
        return null
    }
}
