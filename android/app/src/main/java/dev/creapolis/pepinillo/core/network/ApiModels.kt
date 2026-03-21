package dev.creapolis.pepinillo.core.network

import kotlinx.serialization.Serializable

// ── Auth ──

@Serializable
data class LoginRequest(
    val email: String,
    val password: String,
)

@Serializable
data class RegisterRequest(
    val email: String,
    val name: String,
    val password: String,
)

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
    val birthDate: String? = null,
    val subscriptionTier: String = "free",
    val subscriptionExpiresAt: String? = null,
    val emailVerified: Boolean = false,
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
    val createdDate: Long? = null,
    val finishDate: Long? = null,
    val isFinished: Boolean = false,
    val priority: Int = 0,
    val category: String? = null,
    val estimatedPomodoros: Int = 0,
    val completedPomodoros: Int = 0,
    val focusedSeconds: Int = 0,
    val activeSessionId: String? = null,
    val isDeleted: Boolean = false,
    val updatedAt: Long = 0,
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
    val lastSyncAt: Long? = null,
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
    val startedAt: Long = 0,
    val endedAt: Long? = null,
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
    val createdAt: Long = 0,
    val updatedAt: Long = 0,
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
    val birthDate: String? = null,
)

@Serializable
data class ImageUploadResponse(
    val imageUrl: String,
)

@Serializable
data class ErrorResponse(
    val error: String = "",
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
