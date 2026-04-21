package dev.creapolis.pepinillo.core.network

import android.util.Log
import dev.creapolis.pepinillo.core.auth.AuthStore
import io.ktor.client.HttpClient
import io.ktor.client.call.body
import io.ktor.client.request.delete
import io.ktor.client.request.get
import io.ktor.client.request.header
import io.ktor.client.request.parameter
import io.ktor.client.request.forms.MultiPartFormDataContent
import io.ktor.client.request.forms.formData
import io.ktor.client.request.post
import io.ktor.client.request.put
import io.ktor.client.request.setBody
import io.ktor.http.ContentType
import io.ktor.http.Headers
import io.ktor.http.HttpHeaders
import io.ktor.client.statement.bodyAsText
import io.ktor.http.contentType
import kotlinx.serialization.json.Json
import javax.inject.Inject
import javax.inject.Singleton

private const val TAG = "PepinilloApi"

@Singleton
class PepinilloApiClient @Inject constructor(
    private val httpClient: HttpClient,
    private val json: Json,
    private val authStore: AuthStore,
) {
    // ── Auth ──

    suspend fun login(email: String, password: String): NetworkResult<AuthResponse> =
        safeAuthCall { httpClient.post("auth/login") { jsonBody(LoginRequest(email, password)) } }

    suspend fun register(email: String, name: String, password: String): NetworkResult<AuthResponse> =
        safeAuthCall { httpClient.post("auth/register") { jsonBody(RegisterRequest(email, name, password)) } }

    suspend fun loginWithGoogle(idToken: String): NetworkResult<AuthResponse> =
        safeAuthCall { httpClient.post("auth/google") { jsonBody(GoogleLoginRequest(idToken)) } }

    suspend fun forgotPassword(email: String): NetworkResult<Unit> =
        safeCall { httpClient.post("auth/forgot-password") { jsonBody(ForgotPasswordRequest(email)) }.body() }

    suspend fun resetPassword(email: String, code: String, newPassword: String): NetworkResult<Unit> =
        safeCall { httpClient.post("auth/reset-password") { jsonBody(ResetPasswordRequest(email, code, newPassword)) }.body() }

    suspend fun verifyEmail(email: String, code: String): NetworkResult<VerifyEmailResponse> =
        safeCall { httpClient.post("auth/verify-email") { jsonBody(VerifyEmailRequest(email, code)) }.body() }

    suspend fun resendVerificationEmail(email: String): NetworkResult<Unit> =
        safeCall { httpClient.post("auth/resend-verification") { jsonBody(ResendVerificationRequest(email)) }.body() }

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
        safeCall { httpClient.post("tasks/sync") { jsonBody(request); withDeviceId() }.body() }

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

    suspend fun getAllSessions(): NetworkResult<List<PomodoroSessionDto>> =
        safeCall { httpClient.get("focus/sessions/all").body() }

    suspend fun syncSessions(request: SessionSyncRequest): NetworkResult<SessionSyncResponse> =
        safeCall { httpClient.post("sync/sessions") { jsonBody(request); withDeviceId() }.body() }

    // ── Pomodoro Config ──

    suspend fun getConfig(): NetworkResult<PomodoroConfigDto> =
        safeCall { httpClient.get("pomodoro/config").body() }

    suspend fun updateConfig(config: PomodoroConfigDto): NetworkResult<PomodoroConfigDto> =
        safeCall { httpClient.put("pomodoro/config") { jsonBody(config) }.body() }

    // ── Focus Config (multi-mode) ──

    suspend fun getFocusConfig(): NetworkResult<FocusConfigDto> =
        safeCall { httpClient.get("focus/config").body() }

    suspend fun updateFocusConfig(config: FocusConfigDto): NetworkResult<FocusConfigDto> =
        safeCall { httpClient.put("focus/config") { jsonBody(config) }.body() }

    // ── Focus Stats ──

    suspend fun getStats(from: String, to: String): NetworkResult<List<FocusStatsDto>> =
        safeCall {
            httpClient.get("focus/stats") {
                parameter("from", from)
                parameter("to", to)
            }.body()
        }

    suspend fun upsertStats(stats: FocusStatsDto): NetworkResult<FocusStatsDto> =
        safeCall { httpClient.post("focus/stats") { jsonBody(stats) }.body() }

    // ── Preferences ──

    suspend fun getPreferences(): NetworkResult<PreferenceSyncResponse> =
        safeCall { httpClient.get("preferences").body() }

    suspend fun upsertPreferences(request: PreferenceSyncRequest): NetworkResult<PreferenceSyncResponse> =
        safeCall { httpClient.put("preferences") { jsonBody(request); withDeviceId() }.body() }

    // ── Initial Upload ──

    suspend fun initialUpload(request: InitialUploadRequest): NetworkResult<InitialUploadResponse> =
        safeCall { httpClient.post("sync/initial-upload") { jsonBody(request); withDeviceId() }.body() }

    // ── Full Sync (cursor-paginated pull) ──

    suspend fun getFullSync(
        taskCursor: String? = null,
        sessionCursor: String? = null,
        limit: Int = 100,
    ): NetworkResult<FullSyncResponse> =
        safeCall {
            httpClient.get("sync/full") {
                taskCursor?.let { parameter("taskCursor", it) }
                sessionCursor?.let { parameter("sessionCursor", it) }
                parameter("limit", limit.toString())
                withDeviceId()
            }.body()
        }

    // ── Billing ──

    suspend fun verifyReceipt(request: VerifyReceiptRequest): NetworkResult<VerifyReceiptResponse> =
        safeCall { httpClient.post("billing/verify-receipt") { jsonBody(request) }.body() }

    // ── Helpers ──

    private suspend fun safeAuthCall(
        block: suspend () -> io.ktor.client.statement.HttpResponse,
    ): NetworkResult<AuthResponse> {
        return try {
            val response = block()
            val rawBody = response.bodyAsText()
            Log.d(TAG, "AUTH RAW RESPONSE [${response.status}]: $rawBody")
            val parsed = json.decodeFromString<AuthResponse>(rawBody)
            NetworkResult.Success(parsed)
        } catch (e: io.ktor.client.plugins.ClientRequestException) {
            val rawBody = try { e.response.bodyAsText() } catch (_: Exception) { "n/a" }
            Log.e(TAG, "AUTH API error ${e.response.status}: $rawBody", e)
            val errorBody = try { json.decodeFromString<ErrorResponse>(rawBody) } catch (_: Exception) { null }
            NetworkResult.Error(e.response.status.value, errorBody?.error ?: e.message)
        } catch (e: io.ktor.client.plugins.ServerResponseException) {
            val rawBody = try { e.response.bodyAsText() } catch (_: Exception) { "n/a" }
            Log.e(TAG, "AUTH Server error ${e.response.status}: $rawBody", e)
            val errorBody = try { json.decodeFromString<ErrorResponse>(rawBody) } catch (_: Exception) { null }
            NetworkResult.Error(e.response.status.value, errorBody?.error ?: e.message)
        } catch (e: Exception) {
            Log.e(TAG, "AUTH error: ${e::class.simpleName}: ${e.message}", e)
            NetworkResult.NetworkError(e)
        }
    }

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

    private fun io.ktor.client.request.HttpRequestBuilder.withDeviceId() {
        header("X-Device-ID", authStore.getOrCreateDeviceId())
    }
}
