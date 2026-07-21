// APIDTOs.swift
// Pepinillo — Deep Work Companion for Apple
//
// Data Transfer Objects for backend API communication.
// All types are value types conforming to Codable, Sendable, Equatable.

import Foundation

// MARK: - Request DTOs

public struct LoginRequest: Codable, Sendable, Equatable {
    public let email: String
    public let password: String
}

public struct RegisterRequest: Codable, Sendable, Equatable {
    public let email: String
    public let name: String
    public let password: String
}

public struct RefreshRequest: Codable, Sendable, Equatable {
    public let refreshToken: String
}

public struct LogoutRequest: Codable, Sendable, Equatable {
    public let refreshToken: String
}

/// Request body for `DELETE /auth/account` (#193, #196).
/// `refreshToken` lets the backend revoke the app's own session even though the
/// access token is carried via the Authorization header; `appleAuthorizationCode`
/// lets the backend revoke Sign in with Apple user tokens (Apple requirement).
public struct DeleteAccountRequest: Codable, Sendable, Equatable {
    public let refreshToken: String?
    public let appleAuthorizationCode: String?

    public init(refreshToken: String?, appleAuthorizationCode: String?) {
        self.refreshToken = refreshToken
        self.appleAuthorizationCode = appleAuthorizationCode
    }
}

public struct AppleLoginRequest: Codable, Sendable, Equatable {
    public let idToken: String
    public let nonce: String
    /// User's full name as provided by Apple on first authorization.
    /// Only non-nil the very first time the user grants permission; nil on all
    /// subsequent sign-ins. The backend uses this to persist the real name since
    /// Apple never includes it inside the JWT identity token.
    public let name: String?
    /// User's email as provided by Apple on first authorization.
    /// Like `name`, this is only populated the first time Apple authorizes the app.
    public let email: String?

    public init(idToken: String, nonce: String, name: String? = nil, email: String? = nil) {
        self.idToken = idToken
        self.nonce = nonce
        self.name = name
        self.email = email
    }
}

public struct ForgotPasswordRequest: Codable, Sendable, Equatable {
    public let email: String
}

public struct VerifyEmailRequest: Codable, Sendable, Equatable {
    public let email: String
    public let code: String
}

public struct ResendVerificationRequest: Codable, Sendable, Equatable {
    public let email: String
}

public struct VerifyEmailResponse: Codable, Sendable, Equatable {
    public let message: String
    public let user: APIUser
    public let tokens: APITokens
}

public struct ResetPasswordRequest: Codable, Sendable, Equatable {
    public let email: String
    public let code: String
    public let newPassword: String
}

public struct UpdateProfileRequest: Codable, Sendable, Equatable {
    public let name: String?
    public let email: String?
    public let imageUrl: String?

    public init(name: String? = nil, email: String? = nil, imageUrl: String? = nil) {
        self.name = name
        self.email = email
        self.imageUrl = imageUrl
    }
}

// MARK: - Response DTOs

public struct APIUser: Codable, Sendable, Equatable {
    public let id: String
    public let email: String
    public let name: String
    public let imageUrl: String?
    public let subscriptionTier: String
    public let subscriptionExpiresAt: String?
    public let emailVerified: Bool
    public let createdAt: String
    public let updatedAt: String
    public let appleId: String?
    public let appleEmail: String?
    public let appleName: String?
}

public struct APITokens: Codable, Sendable, Equatable {
    public let accessToken: String
    public let refreshToken: String
    public let expiresIn: Int
}

public struct AuthResponse: Codable, Sendable, Equatable {
    public let user: APIUser
    public let tokens: APITokens
}

public struct RefreshResponse: Codable, Sendable, Equatable {
    public let tokens: APITokens
}

public struct ImageUploadResponse: Codable, Sendable, Equatable {
    public let imageUrl: String
}

// MARK: - Task Sync DTOs

public struct TaskSyncDTO: Codable, Sendable, Equatable {
    public let id: Int?
    public let syncId: String
    public let userId: String?
    public let title: String?
    public let description: String?
    public let energyLevel: String?
    public let recurrenceRule: String?
    public let recurringTemplateId: String?
    public let createdDate: String?
    public let finishDate: String?
    public let isFinished: Bool
    public let priority: Int
    public let category: String?
    public let trackingMode: String?
    public let estimatedPomodoros: Int
    public let completedPomodoros: Int
    public let focusedSeconds: Int
    public let focusedSecondsPomodoro: Int
    public let focusedSecondsFlowtime: Int
    public let focusedSecondsTimeblock: Int
    public let focusedSecondsStopwatch: Int
    public let activeSessionId: String?
    public let isDeleted: Bool
    public let subTasks: [SubTaskSyncDTO]?
    public let updatedAt: String?

    public init(
        id: Int? = nil, syncId: String, userId: String? = nil,
        title: String? = nil, description: String? = nil, energyLevel: String? = nil,
        recurrenceRule: String? = nil, recurringTemplateId: String? = nil,
        createdDate: String? = nil, finishDate: String? = nil,
        isFinished: Bool = false, priority: Int = 0, category: String? = nil,
        trackingMode: String? = nil, estimatedPomodoros: Int = 0, completedPomodoros: Int = 0,
        focusedSeconds: Int = 0,
        focusedSecondsPomodoro: Int = 0, focusedSecondsFlowtime: Int = 0,
        focusedSecondsTimeblock: Int = 0, focusedSecondsStopwatch: Int = 0,
        activeSessionId: String? = nil, isDeleted: Bool = false,
        subTasks: [SubTaskSyncDTO]? = nil, updatedAt: String? = nil
    ) {
        self.id = id
        self.syncId = syncId
        self.userId = userId
        self.title = title
        self.description = description
        self.energyLevel = energyLevel
        self.recurrenceRule = recurrenceRule
        self.recurringTemplateId = recurringTemplateId
        self.createdDate = createdDate
        self.finishDate = finishDate
        self.isFinished = isFinished
        self.priority = priority
        self.category = category
        self.trackingMode = trackingMode
        self.estimatedPomodoros = estimatedPomodoros
        self.completedPomodoros = completedPomodoros
        self.focusedSeconds = focusedSeconds
        self.focusedSecondsPomodoro = focusedSecondsPomodoro
        self.focusedSecondsFlowtime = focusedSecondsFlowtime
        self.focusedSecondsTimeblock = focusedSecondsTimeblock
        self.focusedSecondsStopwatch = focusedSecondsStopwatch
        self.activeSessionId = activeSessionId
        self.isDeleted = isDeleted
        self.subTasks = subTasks
        self.updatedAt = updatedAt
    }
}

public struct SubTaskSyncDTO: Codable, Sendable, Equatable {
    public let id: Int?
    public let taskId: Int?
    public let title: String?
    public let isFinished: Bool

    public init(id: Int? = nil, taskId: Int? = nil, title: String? = nil, isFinished: Bool = false) {
        self.id = id
        self.taskId = taskId
        self.title = title
        self.isFinished = isFinished
    }
}

public struct TaskSyncRequest: Codable, Sendable, Equatable {
    public let tasks: [TaskSyncDTO]
    public let deletedSyncIds: [String]
    public let lastSyncAt: String?

    public init(tasks: [TaskSyncDTO], deletedSyncIds: [String], lastSyncAt: String? = nil) {
        self.tasks = tasks
        self.deletedSyncIds = deletedSyncIds
        self.lastSyncAt = lastSyncAt
    }
}

public struct TaskSyncResponse: Codable, Sendable, Equatable {
    public let tasks: [TaskSyncDTO]
    public let deletedSyncIds: [String]
    public let syncTimestamp: String

    public init(tasks: [TaskSyncDTO], deletedSyncIds: [String], syncTimestamp: String) {
        self.tasks = tasks
        self.deletedSyncIds = deletedSyncIds
        self.syncTimestamp = syncTimestamp
    }
}

// MARK: - Focus Session Sync DTO

public struct FocusSessionSyncDTO: Codable, Sendable, Equatable {
    public let id: String
    public let userId: String?
    public let taskId: Int?
    public let taskSyncId: String?
    public let startedAt: String
    public let endedAt: String?
    public let mode: String
    public let phase: String
    public let durationSeconds: Int
    public let elapsedSeconds: Int
    public let pauseCount: Int
    public let totalPauseSeconds: Int
    public let wasCompleted: Bool
    public let sharedWithTaskIds: String?
    public let createdAt: String
    public let updatedAt: String

    public init(
        id: String, userId: String? = nil, taskId: Int? = nil,
        taskSyncId: String? = nil,
        startedAt: String, endedAt: String? = nil,
        mode: String, phase: String,
        durationSeconds: Int, elapsedSeconds: Int,
        pauseCount: Int = 0, totalPauseSeconds: Int = 0,
        wasCompleted: Bool = false, sharedWithTaskIds: String? = nil,
        createdAt: String, updatedAt: String
    ) {
        self.id = id
        self.userId = userId
        self.taskId = taskId
        self.taskSyncId = taskSyncId
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.mode = mode
        self.phase = phase
        self.durationSeconds = durationSeconds
        self.elapsedSeconds = elapsedSeconds
        self.pauseCount = pauseCount
        self.totalPauseSeconds = totalPauseSeconds
        self.wasCompleted = wasCompleted
        self.sharedWithTaskIds = sharedWithTaskIds
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Preference Sync

public struct PreferenceSyncItem: Codable, Sendable, Equatable {
    public let key: String
    public let value: String
    public let updatedAt: String  // RFC3339

    public init(key: String, value: String, updatedAt: String) {
        self.key = key
        self.value = value
        self.updatedAt = updatedAt
    }
}

public struct PreferenceSyncRequest: Codable, Sendable, Equatable {
    public let preferences: [PreferenceSyncItem]

    public init(preferences: [PreferenceSyncItem]) {
        self.preferences = preferences
    }
}

public struct PreferenceSyncResponse: Codable, Sendable, Equatable {
    public let preferences: [PreferenceSyncItem]
    public let serverTimestamp: String

    public init(preferences: [PreferenceSyncItem], serverTimestamp: String) {
        self.preferences = preferences
        self.serverTimestamp = serverTimestamp
    }
}

// MARK: - Session Batch Sync

public struct SessionSyncRequest: Codable, Sendable, Equatable {
    public let sessions: [FocusSessionSyncDTO]
    public let lastSyncAt: String?

    public init(sessions: [FocusSessionSyncDTO], lastSyncAt: String? = nil) {
        self.sessions = sessions
        self.lastSyncAt = lastSyncAt
    }
}

public struct SessionSyncResponse: Codable, Sendable, Equatable {
    public let sessions: [FocusSessionSyncDTO]
    public let serverTimestamp: String

    public init(sessions: [FocusSessionSyncDTO], serverTimestamp: String) {
        self.sessions = sessions
        self.serverTimestamp = serverTimestamp
    }
}

// MARK: - Initial Upload

public struct InitialUploadRequest: Codable, Sendable, Equatable {
    public let deviceId: String
    public let tasks: [TaskSyncDTO]
    public let sessions: [FocusSessionSyncDTO]
    public let settings: [PreferenceSyncItem]

    public init(deviceId: String, tasks: [TaskSyncDTO], sessions: [FocusSessionSyncDTO], settings: [PreferenceSyncItem]) {
        self.deviceId = deviceId
        self.tasks = tasks
        self.sessions = sessions
        self.settings = settings
    }
}

public struct InitialUploadResponse: Codable, Sendable, Equatable {
    public let tasks: [TaskSyncDTO]
    public let sessions: [FocusSessionSyncDTO]
    public let settings: [PreferenceSyncItem]
    public let serverTimestamp: String
    public let hasExistingData: Bool

    public init(tasks: [TaskSyncDTO], sessions: [FocusSessionSyncDTO], settings: [PreferenceSyncItem], serverTimestamp: String, hasExistingData: Bool) {
        self.tasks = tasks
        self.sessions = sessions
        self.settings = settings
        self.serverTimestamp = serverTimestamp
        self.hasExistingData = hasExistingData
    }
}

// MARK: - Full Sync (Paginated)

public struct PaginatedTaskPage: Codable, Sendable, Equatable {
    public let items: [TaskSyncDTO]
    public let nextCursor: String?
    public let hasMore: Bool

    public init(items: [TaskSyncDTO], nextCursor: String? = nil, hasMore: Bool = false) {
        self.items = items
        self.nextCursor = nextCursor
        self.hasMore = hasMore
    }
}

public struct PaginatedSessionPage: Codable, Sendable, Equatable {
    public let items: [FocusSessionSyncDTO]
    public let nextCursor: String?
    public let hasMore: Bool

    public init(items: [FocusSessionSyncDTO], nextCursor: String? = nil, hasMore: Bool = false) {
        self.items = items
        self.nextCursor = nextCursor
        self.hasMore = hasMore
    }
}

public struct FullSyncResponse: Codable, Sendable, Equatable {
    public let tasks: PaginatedTaskPage
    public let sessions: PaginatedSessionPage
    public let settings: [PreferenceSyncItem]
    public let serverTimestamp: String

    public init(tasks: PaginatedTaskPage, sessions: PaginatedSessionPage, settings: [PreferenceSyncItem], serverTimestamp: String) {
        self.tasks = tasks
        self.sessions = sessions
        self.settings = settings
        self.serverTimestamp = serverTimestamp
    }
}

// MARK: - Error

struct APIErrorBody: Codable, Sendable {
    let error: String
}

public enum APIClientError: Error, Equatable, Sendable {
    case invalidCredentials
    case emailAlreadyExists
    case weakPassword
    case invalidEmail
    case missingRequiredFields
    case invalidRefreshToken
    case sessionExpired
    case networkError
    case invalidURL
    case serverError(Int)
    case unknown(String)
    case invalidResetCode
    case resetCodeExpired

    public var userMessage: String {
        switch self {
        case .invalidCredentials:
            return String(localized: "Invalid email or password")
        case .emailAlreadyExists:
            return String(localized: "An account with this email already exists")
        case .weakPassword:
            return String(localized: "Password needs 8+ chars with uppercase, lowercase, and a number")
        case .invalidEmail:
            return String(localized: "Please enter a valid email address")
        case .missingRequiredFields:
            return String(localized: "Please fill in all fields")
        case .invalidRefreshToken, .sessionExpired:
            return String(localized: "Session expired. Please sign in again.")
        case .networkError:
            return String(localized: "No internet connection. You can still use the app offline.")
        case .invalidURL:
            return String(localized: "Unable to connect to the server. Please try again later.")
        case .serverError:
            return String(localized: "Server error. Please try again later.")
        case .unknown(let msg):
            return msg
        case .invalidResetCode:
            return String(localized: "Invalid reset code. Please check and try again.")
        case .resetCodeExpired:
            return String(localized: "Reset code has expired. Please request a new one.")
        }
    }

    static func from(errorCode: String) -> APIClientError {
        switch errorCode {
        case "invalid_credentials": return .invalidCredentials
        case "email_already_exists": return .emailAlreadyExists
        case "weak_password": return .weakPassword
        case "invalid_email": return .invalidEmail
        case "missing_required_fields": return .missingRequiredFields
        case "invalid_refresh_token": return .invalidRefreshToken
        case "invalid_reset_code": return .invalidResetCode
        case "reset_code_expired": return .resetCodeExpired
        default: return .unknown(errorCode)
        }
    }
}
