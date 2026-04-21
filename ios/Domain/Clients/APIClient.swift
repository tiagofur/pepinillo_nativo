// APIClient.swift
// Pepinillo — Deep Work Companion for Apple
//
// TCA dependency client for backend API communication.
// Handles authentication, token refresh, and error mapping.

import Foundation
import ComposableArchitecture

// MARK: - Client

@DependencyClient
public struct APIClient: Sendable {
    public var login: @Sendable (LoginRequest) async throws -> AuthResponse
    public var register: @Sendable (RegisterRequest) async throws -> AuthResponse
    public var loginWithApple: @Sendable (AppleLoginRequest) async throws -> AuthResponse
    public var refreshTokens: @Sendable (RefreshRequest) async throws -> RefreshResponse
    public var logout: @Sendable (LogoutRequest) async throws -> Void
    public var forgotPassword: @Sendable (ForgotPasswordRequest) async throws -> Void
    public var resetPassword: @Sendable (ResetPasswordRequest) async throws -> Void
    public var verifyEmail: @Sendable (VerifyEmailRequest) async throws -> VerifyEmailResponse
    public var resendVerificationEmail: @Sendable (ResendVerificationRequest) async throws -> Void
    public var getMe: @Sendable () async throws -> APIUser
    public var updateMe: @Sendable (UpdateProfileRequest) async throws -> APIUser
    public var uploadProfileImage: @Sendable (_ imageData: Data, _ mimeType: String) async throws -> ImageUploadResponse
    public var syncTasks: @Sendable (TaskSyncRequest) async throws -> TaskSyncResponse
    public var createSession: @Sendable (FocusSessionSyncDTO) async throws -> FocusSessionSyncDTO
    public var getAllSessions: @Sendable () async throws -> [FocusSessionSyncDTO]
    public var getPreferences: @Sendable () async throws -> PreferenceSyncResponse
    public var upsertPreferences: @Sendable (PreferenceSyncRequest) async throws -> PreferenceSyncResponse
    public var syncSessions: @Sendable (SessionSyncRequest) async throws -> SessionSyncResponse
    public var initialUpload: @Sendable (InitialUploadRequest) async throws -> InitialUploadResponse
    public var getFullSync: @Sendable (_ taskCursor: String?, _ sessionCursor: String?, _ limit: Int) async throws -> FullSyncResponse
}

// MARK: - Live implementation

extension APIClient: DependencyKey {
    public static var liveValue: APIClient {
        @Dependency(\.keychainClient) var keychain
        let helper = APIHelper(keychain: keychain)
        return APIClient(
            login: { try await helper.post("auth/login", body: $0) },
            register: { try await helper.post("auth/register", body: $0) },
            loginWithApple: { try await helper.post("auth/apple", body: $0) },
            refreshTokens: { try await helper.post("auth/refresh", body: $0) },
            logout: { try await helper.postVoid("auth/logout", body: $0) },
            forgotPassword: { try await helper.postVoid("auth/forgot-password", body: $0) },
            resetPassword: { try await helper.postVoid("auth/reset-password", body: $0) },
            verifyEmail: { try await helper.post("auth/verify-email", body: $0) },
            resendVerificationEmail: { try await helper.postVoid("auth/resend-verification", body: $0) },
            getMe: { try await helper.authenticatedGet("users/me") },
            updateMe: { try await helper.authenticatedPut("users/me", body: $0) },
            uploadProfileImage: { imageData, mimeType in
                try await helper.authenticatedMultipartUpload(
                    "users/me/image",
                    fieldName: "image",
                    fileData: imageData,
                    mimeType: mimeType
                )
            },
            syncTasks: { request in
                try await helper.authenticatedPost("tasks/sync", body: request)
            },
            createSession: { session in
                try await helper.authenticatedPost("focus/sessions", body: session)
            },
            getAllSessions: {
                try await helper.authenticatedGet("focus/sessions/all")
            },
            getPreferences: {
                try await helper.authenticatedGet("preferences")
            },
            upsertPreferences: { request in
                try await helper.authenticatedPut("preferences", body: request)
            },
            syncSessions: { request in
                try await helper.authenticatedPost("sync/sessions", body: request)
            },
            initialUpload: { request in
                try await helper.authenticatedPost("sync/initial-upload", body: request)
            },
            getFullSync: { taskCursor, sessionCursor, limit in
                var path = "sync/full?limit=\(limit)"
                if let tc = taskCursor { path += "&taskCursor=\(tc)" }
                if let sc = sessionCursor { path += "&sessionCursor=\(sc)" }
                return try await helper.authenticatedGet(path)
            }
        )
    }

    public static let testValue = APIClient()
}

// MARK: - API Helper

private struct APIHelper: Sendable {
    let keychain: KeychainClient

    /// Base URL resolved from Info.plist (`API_BASE_URL`, injected via xcconfig).
    /// Falls back to the production API if the key is missing — never ships a
    /// localhost default to the App Store.
    private static let baseURL: String = {
        if let value = Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String,
           !value.isEmpty,
           value != "$(API_BASE_URL)" {
            return value
        }
        return "https://api.ppn.creapolis.dev/api/v1"
    }()

    private var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        return encoder
    }

    private var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }

    // MARK: - Unauthenticated requests

    func post<Req: Encodable & Sendable, Res: Decodable & Sendable>(
        _ path: String,
        body: Req
    ) async throws -> Res {
        var request = URLRequest(url: URL(string: "\(Self.baseURL)/\(path)")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(body)

        let (data, response) = try await performRequest(request)
        try validateResponse(data: data, response: response)
        return try decoder.decode(Res.self, from: data)
    }

    func postVoid<Req: Encodable & Sendable>(
        _ path: String,
        body: Req
    ) async throws {
        var request = URLRequest(url: URL(string: "\(Self.baseURL)/\(path)")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(body)

        let (data, response) = try await performRequest(request)
        try validateResponse(data: data, response: response)
    }

    // MARK: - Authenticated requests (with 401 → refresh → retry)

    func authenticatedGet<Res: Decodable & Sendable>(
        _ path: String
    ) async throws -> Res {
        var request = URLRequest(url: URL(string: "\(Self.baseURL)/\(path)")!)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        return try await performAuthenticated(request)
    }

    func authenticatedPost<Req: Encodable & Sendable, Res: Decodable & Sendable>(
        _ path: String,
        body: Req
    ) async throws -> Res {
        var request = URLRequest(url: URL(string: "\(Self.baseURL)/\(path)")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(body)

        return try await performAuthenticated(request)
    }

    func authenticatedPut<Req: Encodable & Sendable, Res: Decodable & Sendable>(
        _ path: String,
        body: Req
    ) async throws -> Res {
        var request = URLRequest(url: URL(string: "\(Self.baseURL)/\(path)")!)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(body)

        return try await performAuthenticated(request)
    }

    // MARK: - Authenticated multipart upload

    func authenticatedMultipartUpload<Res: Decodable & Sendable>(
        _ path: String,
        fieldName: String,
        fileData: Data,
        mimeType: String
    ) async throws -> Res {
        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: URL(string: "\(Self.baseURL)/\(path)")!)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        let fileExtension = mimeType == "image/png" ? "png" : "jpeg"
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"\(fieldName)\"; filename=\"image.\(fileExtension)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body

        return try await performAuthenticated(request)
    }

    // MARK: - Private helpers

    private func performAuthenticated<Res: Decodable & Sendable>(
        _ request: URLRequest
    ) async throws -> Res {
        // First attempt with current access token
        guard let accessToken = await keychain.loadAccessToken() else {
            throw APIClientError.sessionExpired
        }

        var authedRequest = request
        authedRequest.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await performRequest(authedRequest)

        // If 401, try refreshing tokens and retry once
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 401 {
            return try await refreshAndRetry(originalRequest: request)
        }

        try validateResponse(data: data, response: response)
        return try decoder.decode(Res.self, from: data)
    }

    private func refreshAndRetry<Res: Decodable & Sendable>(
        originalRequest: URLRequest
    ) async throws -> Res {
        guard let refreshToken = await keychain.loadRefreshToken() else {
            throw APIClientError.sessionExpired
        }

        // Attempt token refresh
        let refreshBody = RefreshRequest(refreshToken: refreshToken)
        let refreshResponse: RefreshResponse
        do {
            refreshResponse = try await post("auth/refresh", body: refreshBody)
        } catch let apiError as APIClientError {
            // Only clear tokens on definitive rejection (401/403), not transient errors
            switch apiError {
            case .sessionExpired, .serverError(401), .serverError(403):
                try? await keychain.deleteTokens()
                throw APIClientError.sessionExpired
            default:
                // Transient error (network, 5xx, etc.) — don't clear tokens
                throw apiError
            }
        } catch {
            // Network-level error — don't clear tokens, just propagate
            throw APIClientError.networkError
        }

        // Save new tokens
        try await keychain.saveTokens(
            refreshResponse.tokens.accessToken,
            refreshResponse.tokens.refreshToken
        )

        // Retry original request with new access token
        var retryRequest = originalRequest
        retryRequest.setValue(
            "Bearer \(refreshResponse.tokens.accessToken)",
            forHTTPHeaderField: "Authorization"
        )

        let (data, response) = try await performRequest(retryRequest)
        try validateResponse(data: data, response: response)
        return try decoder.decode(Res.self, from: data)
    }

    private func performRequest(_ request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await URLSession.shared.data(for: request)
        } catch {
            throw APIClientError.networkError
        }
    }

    private func validateResponse(data: Data, response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIClientError.networkError
        }

        let statusCode = httpResponse.statusCode

        guard (200...299).contains(statusCode) else {
            // Try to parse error body
            if let errorBody = try? JSONDecoder().decode(APIErrorBody.self, from: data) {
                throw APIClientError.from(errorCode: errorBody.error)
            }
            throw APIClientError.serverError(statusCode)
        }
    }
}

// MARK: - DependencyValues registration

extension DependencyValues {
    public var apiClient: APIClient {
        get { self[APIClient.self] }
        set { self[APIClient.self] = newValue }
    }
}
