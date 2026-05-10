package dev.creapolis.pepinillo.domain.report

import android.content.Context
import com.google.mlkit.genai.prompt.Generation
import com.google.mlkit.genai.prompt.GenerativeModel
import com.google.mlkit.genai.prompt.GenerateContentResponse
import dev.creapolis.pepinillo.core.network.AIReportResponse
import io.mockk.coEvery
import io.mockk.every
import io.mockk.mockk
import io.mockk.mockkObject
import io.mockk.unmockkAll
import kotlinx.coroutines.test.runTest
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Before
import org.junit.Test

class OnDeviceReportGeneratorTest {

    private lateinit var context: Context
    private lateinit var generator: OnDeviceReportGenerator
    private val mockModel = mockk<GenerativeModel>()

    @Before
    fun setup() {
        context = mockk(relaxed = true)
        generator = OnDeviceReportGenerator(context)
        mockkObject(Generation)
        every { Generation.getClient() } returns mockModel
    }

    @After
    fun tearDown() {
        unmockkAll()
    }

    @Test
    fun `isAvailable returns true when client is obtained successfully`() = runTest {
        val available = generator.isAvailable()
        assertTrue(available)
    }

    @Test
    fun `generate returns parsed AIReportResponse when model returns valid JSON`() = runTest {
        // Arrange
        val mockResponse = mockk<GenerateContentResponse>()
        val validJson = """
            {
              "title": "Super Productivo",
              "highlights": ["Hiciste mucho", "Buen ritmo"],
              "insights": [{"category": "Foco", "text": "Excelente concentración"}],
              "recommendations": ["Sigue así", "Descansa más"]
            }
        """.trimIndent()
        
        every { mockResponse.text } returns "```json\n$validJson\n```"
        coEvery { mockModel.generateContent(any()) } returns mockResponse

        val payload = createDummyPayload()

        // Act
        val result = generator.generate(payload)

        // Assert
        assertNotNull(result)
        assertEquals("Super Productivo", result?.title)
        assertEquals(2, result?.highlights?.size)
        assertEquals("Foco", result?.insights?.first()?.category)
    }

    @Test
    fun `generate returns null when model returns non-json text`() = runTest {
        // Arrange
        val mockResponse = mockk<GenerateContentResponse>()
        every { mockResponse.text } returns "Lo siento, no puedo procesar eso."
        coEvery { mockModel.generateContent(any()) } returns mockResponse

        val payload = createDummyPayload()

        // Act
        val result = generator.generate(payload)

        // Assert
        assertNull(result)
    }

    @Test
    fun `generate returns null when exception occurs`() = runTest {
        // Arrange
        coEvery { mockModel.generateContent(any()) } throws RuntimeException("AI Core Error")

        val payload = createDummyPayload()

        // Act
        val result = generator.generate(payload)

        // Assert
        assertNull(result)
    }

    private fun createDummyPayload() = ReportPayload(
        period = "Semana",
        periodStart = "2025-01-01",
        periodEnd = "2025-01-07",
        summary = ReportSummary(120, 5, 4, 1, 24.0),
        patterns = ReportPatterns("Pomodoro", "09:00 - 11:00", "Martes"),
        taskBreakdown = emptyList()
    )
    
    // Helper to allow assertTrue
    private fun assertTrue(value: Boolean) = assertEquals(true, value)
}
