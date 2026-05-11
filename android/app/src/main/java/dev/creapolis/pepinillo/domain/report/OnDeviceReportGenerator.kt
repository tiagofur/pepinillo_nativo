package dev.creapolis.pepinillo.domain.report

import android.content.Context
import android.util.Log
import dagger.hilt.android.qualifiers.ApplicationContext
import dev.creapolis.pepinillo.core.network.AIReportResponse
import kotlinx.serialization.json.Json
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Stub for on-device AI report generation via Gemini Nano.
 * We use a stub to unblock APK generation while investigating the beta SDK signature.
 */
@Singleton
class OnDeviceReportGenerator @Inject constructor(
    @ApplicationContext private val context: Context,
) {
    companion object {
        private const val TAG = "OnDeviceReportGen"
    }

    private val json = Json { 
        ignoreUnknownKeys = true 
        coerceInputValues = true
    }

    suspend fun isAvailable(): Boolean {
        // Temporary return false to unblock build
        return false
    }

    suspend fun generate(payload: ReportPayload): AIReportResponse? {
        // Temporary return null to unblock build
        return null
    }

    private fun buildPrompt(payload: ReportPayload): String {
        return "Stub prompt"
    }

    private fun extractJson(text: String): String {
        return text
    }
}
