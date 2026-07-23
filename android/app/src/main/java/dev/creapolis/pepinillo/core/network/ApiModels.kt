package dev.creapolis.pepinillo.core.network

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

// ── Auth ──

@Serializable
data class LoginRequest(
    val email: String,
    val password: String,
)

@Serializable
data class ForgotPasswordRequest(val email: String)

@Serializable
data class ResetPasswordRequest(val email: String, val code: String, val newPassword: String)

@Serializable
data class VerifyEmailRequest(val email: String, val code: String)

@Serializable
data class ResendVerificationRequest(val email: String)

@Serializable
data class VerifyEmailResponse(
    val message: String,
    val user: UserDto,
    val tokens: TokensDto,
)

@Serializable
data class RegisterRequest(
    val email: String,
    val name: String,
    val password: String,
)

@Serializable
data class GoogleLoginRequest(val idToken: String)

@Serializable
data class RefreshRequest(
    val refreshToken: String,
)

@Serializable
data class AuthResponse(
    val user: UserDto,
    val tokens: TokensDto,
)

@Serializable
data class TokensDto(
    val accessToken: String,
    val refreshToken: String,
    val expiresIn: Long = 0,
)

@Serializable
data class RefreshResponse(
    val tokens: TokensDto,
)

// ── User ──

@Serializable
data class UserDto(
    val id: String,
    val email: String,
    val name: String,
    val imageUrl: String? = null,
    val subscriptionTier: String = "free",
    val subscriptionExpiresAt: String? = null,
    val emailVerified: Boolean = false,
    val aiCreditsBalance: Int = 0,
    val createdAt: String = "",
    val updatedAt: String = "",
)

// ── Task ──

@Serializable
data class TaskDto(
    val id: Int = 0,
    val syncId: String = "",
    val userId: String = "",
    val title: String? = null,
    val description: String? = null,
    val energyLevel: String? = null,
    val recurrenceRule: String? = null,
    val recurringTemplateId: String? = null,
    val dueDate: String? = null,
    val scheduledForToday: Boolean = false,
    val sortOrder: Int = 0,
    val createdDate: String? = null,
    val finishDate: String? = null,
    val isFinished: Boolean = false,
    val priority: Int = 0,
    val category: String? = null,
    val estimatedPomodoros: Int = 0,
    val completedPomodoros: Int = 0,
    val focusedSeconds: Int = 0,
    val activeSessionId: String? = null,
    val isDeleted: Boolean = false,
    val updatedAt: String = "",
    val trackingMode: String = "pomodoro",
    val completedFlowtimeSessions: Int = 0,
    val completedTimeblockSessions: Int = 0,
    val completedStopwatchSeconds: Int = 0,
    val focusedSecondsPomodoro: Int = 0,
    val focusedSecondsFlowtime: Int = 0,
    val focusedSecondsTimeblock: Int = 0,
    val focusedSecondsStopwatch: Int = 0,
    val subTasks: List<SubTaskDto> = emptyList(),
)

@Serializable
data class SubTaskDto(
    val id: Int = 0,
    val taskId: Int = 0,
    val title: String? = null,
    val isFinished: Boolean = false,
)

// ── Task Sync ──

@Serializable
data class TaskSyncRequest(
    val tasks: List<TaskDto>,
    val deletedSyncIds: List<String> = emptyList(),
    val lastSyncAt: String? = null,
)

@Serializable
data class TaskSyncResponse(
    val tasks: List<TaskDto>,
    val deletedSyncIds: List<String> = emptyList(),
    val syncTimestamp: Long = 0,
)

// ── Pomodoro Session ──

@Serializable
data class PomodoroSessionDto(
    val id: String = "",
    val userId: String = "",
    val taskId: Int? = null,
    val taskSyncId: String? = null,
    val startedAt: String = "",
    val endedAt: String? = null,
    val mode: String = "pomodoro",
    val phase: String = "",
    val durationSeconds: Int = 0,
    val elapsedSeconds: Int = 0,
    val pauseCount: Int = 0,
    val totalPauseSeconds: Int = 0,
    val wasCompleted: Boolean = false,
    val interruptions: Int = 0,
    val pomodoroNumber: Int? = null,
    val satisfactionRating: Int? = null,
    val journalNote: String? = null,
    val sharedWithTaskIds: String? = null,
    val createdAt: String = "",
    val updatedAt: String = "",
)

// ── Session Sync ──

@Serializable
data class SessionSyncRequest(
    val sessions: List<PomodoroSessionDto>,
    val lastSyncAt: String? = null,
)

@Serializable
data class SessionSyncResponse(
    val sessions: List<PomodoroSessionDto>,
    val serverTimestamp: String,
)

// ── Focus Stats ──

@Serializable
data class FocusStatsDto(
    val id: Int = 0,
    val userId: String = "",
    val date: String = "",
    val pomodoros: Int = 0,
    val pomodoroDuration: Int = 0,
    val breaks: Int = 0,
    val breakDuration: Int = 0,
    val rests: Int = 0,
    val restDuration: Int = 0,
    val flowtimeSeconds: Int = 0,
    val timeblockSeconds: Int = 0,
    val stopwatchSeconds: Int = 0,
    val flowtimeCount: Int = 0,
    val timeblockCount: Int = 0,
    val stopwatchCount: Int = 0,
    val dailyGoal: Int = 0,
    val dailyCompleted: Boolean = false,
    val count: Int = 0,
    val createdAt: String = "",
    val updatedAt: String = "",
)

// ── Focus Config ──

@Serializable
data class FocusConfigDto(
    val userId: String = "",
    val defaultMode: String = "pomodoro",
    val pomodoroMinutes: Int = 25,
    val shortBreakMinutes: Int = 5,
    val longBreakMinutes: Int = 15,
    val pomodorosUntilLong: Int = 4,
    val flowtimeCheckInMinutes: Int = 25,
    val timeblockMinutes: Int = 60,
    val dailyGoal: Int = 8,
    val notifications: Boolean = false,
    val autoStart: Boolean = false,
    val autoBreak: Boolean = false,
    val lastUpdate: String? = null,
    val createdAt: String = "",
    val updatedAt: String = "",
)

// ── Billing ──

@Serializable
data class VerifyReceiptRequest(
    val platform: String = "android",
    val productId: String,
    val purchaseToken: String,
)

@Serializable
data class VerifyReceiptResponse(
    val subscriptionTier: String = "free",
    val subscriptionExpiresAt: Long? = null,
)

// ── Profile ──

@Serializable
data class UpdateProfileRequest(
    val name: String? = null,
    val imageUrl: String? = null,
)

@Serializable
data class ImageUploadResponse(
    val imageUrl: String,
)

@Serializable
data class ErrorResponse(
    val error: String = "",
)

// ── Preference Sync ──

@Serializable
data class PreferenceSyncItem(
    val key: String,
    val value: String,
    @SerialName("updatedAt") val updatedAt: String, // RFC3339
)

@Serializable
data class PreferenceSyncRequest(
    val preferences: List<PreferenceSyncItem>,
)

@Serializable
data class PreferenceSyncResponse(
    val preferences: List<PreferenceSyncItem>,
    val serverTimestamp: String, // RFC3339
)

// ── Initial Upload ──

@Serializable
data class InitialUploadRequest(
    val deviceId: String,
    val tasks: List<TaskDto>,
    val sessions: List<PomodoroSessionDto>,
    val settings: List<PreferenceSyncItem>,
)

@Serializable
data class InitialUploadResponse(
    val tasks: List<TaskDto>,
    val sessions: List<PomodoroSessionDto>,
    val settings: List<PreferenceSyncItem>,
    val serverTimestamp: String,
    val hasExistingData: Boolean,
)

// ── Full Sync (cursor-paginated) ──

@Serializable
data class PaginatedTaskPage(
    val items: List<TaskDto>,
    val nextCursor: String? = null,
    val hasMore: Boolean = false,
)

@Serializable
data class PaginatedSessionPage(
    val items: List<PomodoroSessionDto>,
    val nextCursor: String? = null,
    val hasMore: Boolean = false,
)

@Serializable
data class FullSyncResponse(
    val tasks: PaginatedTaskPage,
    val sessions: PaginatedSessionPage,
    val settings: List<PreferenceSyncItem> = emptyList(),
    val serverTimestamp: String,
)

// ── AI Report ──

@Serializable
data class AIReportResponse(
    val title: String,
    val highlights: List<String>,
    val insights: List<ReportInsight>,
    val recommendations: List<String>,
)

@Serializable
data class ReportInsight(
    val category: String,
    val text: String,
)

// ── Pomodoro Config ──

@Serializable
data class PomodoroConfigDto(
    val userId: String = "",
    val pomodoroTime: Int = 25,
    val breakTime: Int = 5,
    val restTime: Int = 15,
    val qtyPomodoros: Int = 4,
    val dailyGoal: Int = 8,
    val notifications: Boolean = false,
    val autoPomodoro: Boolean = false,
    val autoBreak: Boolean = false,
    val lastUpdate: Long? = null,
    val createdAt: Long = 0,
    val updatedAt: Long = 0,
)
