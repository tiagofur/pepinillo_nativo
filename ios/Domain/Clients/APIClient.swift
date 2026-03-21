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
    public var getMe: @Sendable () async throws -> APIUser
    public var updateMe: @Sendable (UpdateProfileRequest) async throws -> APIUser
    public var uploadProfileImage: @Sendable (_ imageData: Data, _ mimeType: String) async throws -> ImageUploadResponse
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
            getMe: { try await helper.authenticatedGet("users/me") },
            updateMe: { try await helper.authenticatedPut("users/me", body: $0) },
            uploadProfileImage: { imageData, mimeType in
                try await helper.authenticatedMultipartUpload(
                    "users/me/image",
                    fieldName: "image",
                    fileData: imageData,
                    mimeType: mimeType
                )
            }
        )
    }

    public static let testValue = APIClient()
}

// MARK: - API Helper

private struct APIHelper: Sendable {
    let keychain: KeychainClient

    #if DEBUG
    private static let baseURL = "http://localhost:8080/api/v1"
    #else
    private static let baseURL = "https://api.pepinillo.app/api/v1"
    #endif

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
        } catch {
            // Refresh failed — session is expired
            try? await keychain.deleteTokens()
            throw APIClientError.sessionExpired
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
