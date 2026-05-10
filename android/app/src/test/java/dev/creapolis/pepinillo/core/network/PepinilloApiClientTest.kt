package dev.creapolis.pepinillo.core.network

import dev.creapolis.pepinillo.core.auth.AuthStore
import io.ktor.client.HttpClient
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.client.plugins.contentnegotiation.ContentNegotiation
import io.ktor.http.ContentType
import io.ktor.http.HttpStatusCode
import io.ktor.http.headersOf
import io.ktor.serialization.kotlinx.json.json
import io.mockk.mockk
import kotlinx.coroutines.test.runTest
import kotlinx.serialization.json.Json
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class PepinilloApiClientTest {

    private val json = Json { ignoreUnknownKeys = true }
    private val authStore: AuthStore = mockk()

    private fun createClient(engine: MockEngine): PepinilloApiClient {
        val httpClient = HttpClient(engine) {
            install(ContentNegotiation) {
                json(json)
            }
        }
        return PepinilloApiClient(httpClient, json, authStore)
    }

    @Test
    fun `createSession should use focus sessions endpoint`() = runTest {
        val mockEngine = MockEngine { request ->
            assertEquals("/focus/sessions", request.url.encodedPath)
            respond(
                content = """{"id": "1", "taskId": 10, "userId": "user-1", "startTime": "2024-01-01T00:00:00Z", "durationSeconds": 1500, "type": "WORK", "status": "COMPLETED"}""",
                status = HttpStatusCode.OK,
                headers = headersOf("Content-Type", ContentType.Application.Json.toString())
            )
        }
        val client = createClient(mockEngine)
        
        val result = client.createSession(PomodoroSessionDto(id = "1", taskId = 10))
        
        assertTrue(result is NetworkResult.Success)
    }
}
