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

public struct AppleLoginRequest: Codable, Sendable, Equatable {
    public let idToken: String
}

public struct UpdateProfileRequest: Codable, Sendable, Equatable {
    public let name: String?
    public let imageUrl: String?
    public let birthDate: String?

    public init(name: String? = nil, imageUrl: String? = nil, birthDate: String? = nil) {
        self.name = name
        self.imageUrl = imageUrl
        self.birthDate = birthDate
    }
}

// MARK: - Response DTOs

public struct APIUser: Codable, Sendable, Equatable {
    public let id: String
    public let email: String
    public let name: String
    public let imageUrl: String?
    public let birthDate: String?
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
    case serverError(Int)
    case unknown(String)

    public var userMessage: String {
        switch self {
        case .invalidCredentials: return "Invalid email or password"
        case .emailAlreadyExists: return "An account with this email already exists"
        case .weakPassword: return "Password needs 8+ chars with uppercase, lowercase, and a number"
        case .invalidEmail: return "Please enter a valid email address"
        case .missingRequiredFields: return "Please fill in all fields"
        case .invalidRefreshToken, .sessionExpired: return "Session expired. Please sign in again."
        case .networkError: return "No internet connection. You can still use the app offline."
        case .serverError: return "Server error. Please try again later."
        case .unknown(let msg): return msg
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
        default: return .unknown(errorCode)
        }
    }
}
