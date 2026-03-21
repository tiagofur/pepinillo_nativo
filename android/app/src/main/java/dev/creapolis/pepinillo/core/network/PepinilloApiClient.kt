package dev.creapolis.pepinillo.core.network

import android.util.Log
import io.ktor.client.HttpClient
import io.ktor.client.call.body
import io.ktor.client.request.delete
import io.ktor.client.request.get
import io.ktor.client.request.parameter
import io.ktor.client.request.forms.MultiPartFormDataContent
import io.ktor.client.request.forms.formData
import io.ktor.client.request.post
import io.ktor.client.request.put
import io.ktor.client.request.setBody
import io.ktor.http.ContentType
import io.ktor.http.Headers
import io.ktor.http.HttpHeaders
import io.ktor.http.contentType
import javax.inject.Inject
import javax.inject.Singleton

private const val TAG = "PepinilloApi"

@Singleton
class PepinilloApiClient @Inject constructor(
    private val httpClient: HttpClient,
) {
    // ── Auth ──

    suspend fun login(email: String, password: String): NetworkResult<AuthResponse> =
        safeCall { httpClient.post("auth/login") { jsonBody(LoginRequest(email, password)) }.body() }

    suspend fun register(email: String, name: String, password: String): NetworkResult<AuthResponse> =
        safeCall { httpClient.post("auth/register") { jsonBody(RegisterRequest(email, name, password)) }.body() }

    suspend fun loginWithGoogle(idToken: String): NetworkResult<AuthResponse> =
        safeCall { httpClient.post("auth/google") { jsonBody(GoogleLoginRequest(idToken)) }.body() }

    suspend fun refreshToken(refreshToken: String): NetworkResult<RefreshResponse> =
        safeCall { httpClient.post("auth/refresh") { jsonBody(RefreshRequest(refreshToken)) }.body() }

    suspend fun logout(refreshToken: String?): NetworkResult<Unit> =
        safeCall {
            httpClient.post("auth/logout") {
                jsonBody(RefreshRequest(refreshToken ?: ""))
            }.body()
        }

    // ── User ──

    suspend fun getMe(): NetworkResult<UserDto> =
        safeCall { httpClient.get("users/me").body() }

    suspend fun updateMe(request: UpdateProfileRequest): NetworkResult<UserDto> =
        safeCall { httpClient.put("users/me") { jsonBody(request) }.body() }

    suspend fun uploadProfileImage(imageBytes: ByteArray, mimeType: String): NetworkResult<ImageUploadResponse> =
        safeCall {
            httpClient.post("users/me/image") {
                setBody(MultiPartFormDataContent(formData {
                    append("image", imageBytes, Headers.build {
                        append(HttpHeaders.ContentType, mimeType)
                        append(HttpHeaders.ContentDisposition, "filename=\"profile.jpg\"")
                    })
                }))
            }.body()
        }

    // ── Tasks ──

    suspend fun getTasks(): NetworkResult<List<TaskDto>> =
        safeCall { httpClient.get("tasks/").body() }

    suspend fun createTask(task: TaskDto): NetworkResult<TaskDto> =
        safeCall { httpClient.post("tasks/") { jsonBody(task) }.body() }

    suspend fun updateTask(id: Int, task: TaskDto): NetworkResult<TaskDto> =
        safeCall { httpClient.put("tasks/$id") { jsonBody(task) }.body() }

    suspend fun deleteTask(id: Int): NetworkResult<Unit> =
        safeCall { httpClient.delete("tasks/$id").body() }

    suspend fun syncTasks(request: TaskSyncRequest): NetworkResult<TaskSyncResponse> =
        safeCall { httpClient.post("tasks/sync") { jsonBody(request) }.body() }

    // ── Subtasks ──

    suspend fun getSubtasks(taskId: Int): NetworkResult<List<SubTaskDto>> =
        safeCall { httpClient.get("tasks/$taskId/subtasks").body() }

    suspend fun createSubtask(taskId: Int, subtask: SubTaskDto): NetworkResult<SubTaskDto> =
        safeCall { httpClient.post("tasks/$taskId/subtasks") { jsonBody(subtask) }.body() }

    suspend fun updateSubtask(taskId: Int, subtaskId: Int, subtask: SubTaskDto): NetworkResult<SubTaskDto> =
        safeCall { httpClient.put("tasks/$taskId/subtasks/$subtaskId") { jsonBody(subtask) }.body() }

    suspend fun deleteSubtask(taskId: Int, subtaskId: Int): NetworkResult<Unit> =
        safeCall { httpClient.delete("tasks/$taskId/subtasks/$subtaskId").body() }

    // ── Pomodoro Sessions ──

    suspend fun createSession(session: PomodoroSessionDto): NetworkResult<PomodoroSessionDto> =
        safeCall { httpClient.post("pomodoro/sessions") { jsonBody(session) }.body() }

    suspend fun getSessionsInRange(from: String, to: String): NetworkResult<List<PomodoroSessionDto>> =
        safeCall {
            httpClient.get("pomodoro/sessions/range") {
                parameter("from", from)
                parameter("to", to)
            }.body()
        }

    // ── Pomodoro Config ──

    suspend fun getConfig(): NetworkResult<PomodoroConfigDto> =
        safeCall { httpClient.get("pomodoro/config").body() }

    suspend fun updateConfig(config: PomodoroConfigDto): NetworkResult<PomodoroConfigDto> =
        safeCall { httpClient.put("pomodoro/config") { jsonBody(config) }.body() }

    // ── Billing ──

    suspend fun verifyReceipt(request: VerifyReceiptRequest): NetworkResult<VerifyReceiptResponse> =
        safeCall { httpClient.post("billing/verify-receipt") { jsonBody(request) }.body() }

    // ── Helpers ──

    private suspend fun <T> safeCall(block: suspend () -> T): NetworkResult<T> {
        return try {
            NetworkResult.Success(block())
        } catch (e: io.ktor.client.plugins.ClientRequestException) {
            val errorBody = try {
                e.response.body<ErrorResponse>()
            } catch (_: Exception) { null }
            Log.e(TAG, "API error ${e.response.status}", e)
            NetworkResult.Error(e.response.status.value, errorBody?.error ?: e.message)
        } catch (e: io.ktor.client.plugins.ServerResponseException) {
            Log.e(TAG, "Server error ${e.response.status}", e)
            NetworkResult.Error(e.response.status.value, e.message)
        } catch (e: Exception) {
            Log.e(TAG, "Network error", e)
            NetworkResult.NetworkError(e)
        }
    }

    private fun io.ktor.client.request.HttpRequestBuilder.jsonBody(body: Any) {
        contentType(ContentType.Application.Json)
        setBody(body)
    }
}
