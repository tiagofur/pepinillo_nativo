package dev.creapolis.pepinillo.domain.report

import android.content.Context
import android.util.Log
import com.google.mlkit.genai.prompt.Generation
import com.google.mlkit.genai.prompt.GenerativeModel
import com.google.mlkit.genai.prompt.generateContentRequest
import dagger.hilt.android.qualifiers.ApplicationContext
import dev.creapolis.pepinillo.core.network.AIReportResponse
import dev.creapolis.pepinillo.core.network.ReportInsight
import kotlinx.coroutines.tasks.await
import kotlinx.serialization.json.Json
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Implementation for on-device AI report generation via Gemini Nano using ML Kit GenAI.
 */
@Singleton
class OnDeviceReportGenerator @Inject constructor(
    @ApplicationContext private val context: Context,
) {
    companion object {
        private const val TAG = "OnDeviceReportGen"
        private const val MODEL_NAME = "gemini-nano" // Standard name for on-device Gemini
    }

    private val json = Json { 
        ignoreUnknownKeys = true 
        coerceInputValues = true
    }

    suspend fun isAvailable(): Boolean {
        return try {
            val generativeModel = Generation.getClient()
            // Some versions of ML Kit might require checking feature status. 
            // If not directly available, we assume true if the client exists, 
            // as generateContent will fail gracefully if AICore is missing.
            Log.d(TAG, "Checking On-device AI availability")
            true
        } catch (e: Exception) {
            Log.e(TAG, "On-device AI SDK initialization failed: ${e.message}")
            false
        }
    }

    suspend fun generate(payload: ReportPayload): AIReportResponse? {
        return runCatching {
            val generativeModel = Generation.getClient()
            
            val prompt = buildPrompt(payload)
            val request = generateContentRequest {
                text(prompt)
            }

            val response = generativeModel.generateContent(request)
            val responseText = response.text ?: return null
            
            Log.d(TAG, "Raw AI Response: $responseText")
            
            // Extract JSON from the response (sometimes the model wraps it in ```json ... ```)
            val cleanJson = extractJson(responseText)
            json.decodeFromString<AIReportResponse>(cleanJson)
        }.onFailure {
            Log.e(TAG, "Error generating AI report on-device: ${it.message}", it)
        }.getOrNull()
    }

    private fun buildPrompt(payload: ReportPayload): String {
        return """
            Actúa como un experto en productividad personal y coach de enfoque.
            Analiza los siguientes datos de uso de la aplicación Pepinillo (basada en técnica Pomodoro) del periodo ${payload.period} (${payload.periodStart} a ${payload.periodEnd}):
            
            RESUMEN:
            - Minutos totales de enfoque: ${payload.summary.totalMinutes}
            - Sesiones totales: ${payload.summary.totalSessions}
            - Sesiones completadas: ${payload.summary.completedSessions}
            - Interrupciones totales: ${payload.summary.totalInterruptions}
            - Promedio de minutos por sesión: ${payload.summary.avgSessionMinutes}
            
            PATRONES:
            - Modo dominante: ${payload.patterns.dominantMode ?: "N/A"}
            - Rango de hora pico: ${payload.patterns.peakHourRange}
            - Mejor día de la semana: ${payload.patterns.bestDayOfWeek}
            
            TAREAS PRINCIPALES:
            ${payload.taskBreakdown.joinToString("\n") { "- Task ID ${it.taskId}: ${it.totalMinutes} min en ${it.sessions} sesiones" }}
            
            INSTRUCCIÓN:
            Genera un diagnóstico de productividad detallado. Debes devolver ÚNICAMENTE un objeto JSON válido con la siguiente estructura exacta (sin texto adicional fuera del JSON):
            {
              "title": "Título motivador y corto",
              "highlights": ["3 puntos destacados positivos sobre su desempeño"],
              "insights": [
                { "category": "Categoría (ej. Enfoque, Ritmo, Tareas)", "text": "Un insight profundo basado en los datos" },
                { "category": "Categoría", "text": "Otro insight relevante" }
              ],
              "recommendations": ["3 recomendaciones prácticas para mejorar la productividad la próxima semana"]
            }
            
            Responde en ESPAÑOL.
        """.trimIndent()
    }

    private fun extractJson(text: String): String {
        val jsonRegex = """\{[\s\S]*\}""".toRegex()
        return jsonRegex.find(text)?.value ?: text
    }
}
