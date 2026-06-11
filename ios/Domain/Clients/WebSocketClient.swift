// WebSocketClient.swift
// Pepinillo — Deep Work Companion for Apple
//
// TCA dependency client for real-time WebSocket communication.
// Connects to the backend WebSocket endpoint and dispatches sync
// actions based on incoming server messages.

import Foundation
import OSLog
import ComposableArchitecture

private let wsLogger = Logger(subsystem: "com.pepinillo.app", category: "websocket")

// MARK: - Client

@DependencyClient
public struct WebSocketClient: Sendable {
    public var connect: @Sendable () async -> Void
    public var disconnect: @Sendable () -> Void = { }
}

// MARK: - Live implementation

extension WebSocketClient: DependencyKey {
    public static var liveValue: WebSocketClient {
#if os(iOS) || os(macOS)
        @Dependency(\.keychainClient) var keychain
        @Dependency(\.apiClient) var apiClient
        @Dependency(\.syncClient) var syncClient
        let manager = WebSocketManager(
            loadAccessToken: { await keychain.loadAccessToken() },
            loadRefreshToken: { await keychain.loadRefreshToken() },
            refreshTokens: { try await apiClient.refreshTokens($0) },
            saveTokens: { try await keychain.saveTokens($0, $1) },
            getOrCreateDeviceId: { keychain.getOrCreateDeviceId() },
            syncTasks: { try await syncClient.syncTasks() },
            syncSessions: { try await syncClient.syncSessions() },
            syncSettings: { try await syncClient.syncSettings() },
            syncAll: { try await syncClient.syncAll() }
        )
#else
        let manager = WebSocketManager(
            loadAccessToken: { nil },
            loadRefreshToken: { nil },
            refreshTokens: { _ in throw URLError(.cancelled) },
            saveTokens: { _, _ in },
            getOrCreateDeviceId: { "" },
            syncTasks: { },
            syncSessions: { },
            syncSettings: { },
            syncAll: { }
        )
#endif
        return WebSocketClient(
            connect: { await manager.connect() },
            disconnect: { manager.disconnect() }
        )
    }

    public static let testValue = WebSocketClient()
}

// MARK: - WebSocket Manager

private final class WebSocketManager: @unchecked Sendable {
    private let lock = NSLock()
    private let loadAccessToken: @Sendable () async -> String?
    private let loadRefreshToken: @Sendable () async -> String?
    private let refreshTokens: @Sendable (RefreshRequest) async throws -> RefreshResponse
    private let saveTokens: @Sendable (String, String) async throws -> Void
    private let getOrCreateDeviceId: @Sendable () -> String
    private let syncTasks: @Sendable () async throws -> Void
    private let syncSessions: @Sendable () async throws -> Void
    private let syncSettings: @Sendable () async throws -> Void
    private let syncAll: @Sendable () async throws -> Void
    private var webSocketTask: URLSessionWebSocketTask?
    private var isConnected = false
    private var isConnecting = false
    private var retryCount = 0
    private var shouldReconnect = false
    // Prevents concurrent token-refresh races during reconnect backoff.
    private var isRefreshingToken = false

    init(
        loadAccessToken: @escaping @Sendable () async -> String?,
        loadRefreshToken: @escaping @Sendable () async -> String?,
        refreshTokens: @escaping @Sendable (RefreshRequest) async throws -> RefreshResponse,
        saveTokens: @escaping @Sendable (String, String) async throws -> Void,
        getOrCreateDeviceId: @escaping @Sendable () -> String,
        syncTasks: @escaping @Sendable () async throws -> Void,
        syncSessions: @escaping @Sendable () async throws -> Void,
        syncSettings: @escaping @Sendable () async throws -> Void,
        syncAll: @escaping @Sendable () async throws -> Void
    ) {
        self.loadAccessToken = loadAccessToken
        self.loadRefreshToken = loadRefreshToken
        self.refreshTokens = refreshTokens
        self.saveTokens = saveTokens
        self.getOrCreateDeviceId = getOrCreateDeviceId
        self.syncTasks = syncTasks
        self.syncSessions = syncSessions
        self.syncSettings = syncSettings
        self.syncAll = syncAll
    }

    /// WebSocket base URL resolved from Info.plist (`WS_BASE_URL`, injected
    /// via xcconfig). Falls back to production if the key is missing.
    private static let baseWSURL: String = {
        if let value = Bundle.main.object(forInfoDictionaryKey: "WS_BASE_URL") as? String,
           !value.isEmpty,
           value != "$(WS_BASE_URL)" {
            return value
        }
        return "wss://api.ppn.creapolis.dev/api/v1/ws"
    }()
    private static let maxBackoff: TimeInterval = 30

    func connect() async {
        lock.withLock {
            shouldReconnect = true
            retryCount = 0
        }

        await performConnect()
    }

    func disconnect() {
        let task = lock.withLock { () -> URLSessionWebSocketTask? in
            shouldReconnect = false
            let currentTask = webSocketTask
            webSocketTask = nil
            isConnected = false
            isConnecting = false
            return currentTask
        }

        task?.cancel(with: .goingAway, reason: nil)
    }

    private func performConnect() async {
        let canStart = lock.withLock { () -> Bool in
            if isConnecting || webSocketTask?.state == .running {
                return false
            }
            isConnecting = true
            return true
        }
        guard canStart else { return }

        guard let token = await loadAccessToken() else {
            lock.withLock { isConnecting = false }
            return
        }
        let deviceId = getOrCreateDeviceId()

        // Token is sent both in the query string (backward compat with current
        // backend) AND in the Authorization header so that once the backend
        // honours the header, we can remove the query param without a flag day.
        // TODO: remove `?token=...` query param once backend reads the header.
        guard let url = URL(string: "\(Self.baseWSURL)?token=\(token)&deviceId=\(deviceId)") else {
            lock.withLock { isConnecting = false }
            return
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let session = URLSession(configuration: .default)
        let task = session.webSocketTask(with: request)

        lock.withLock {
            webSocketTask = task
            isConnecting = false
            isConnected = true
            retryCount = 0
        }

        task.resume()

        await receiveMessages(task: task)
    }

    private func receiveMessages(task: URLSessionWebSocketTask) async {
        while task.state == .running {
            do {
                let message = try await task.receive()
                await handleMessage(message)
            } catch {
                let shouldRetry = lock.withLock { () -> Bool in
                    isConnected = false
                    isConnecting = false
                    if webSocketTask === task {
                        webSocketTask = nil
                    }
                    return shouldReconnect
                }

                if shouldRetry {
                    await reconnectWithBackoff()
                }
                return
            }
        }

        let shouldRetry = lock.withLock { () -> Bool in
            isConnected = false
            isConnecting = false
            if webSocketTask === task {
                webSocketTask = nil
            }
            return shouldReconnect
        }

        if shouldRetry {
            await reconnectWithBackoff()
        }
    }

    private func handleMessage(_ message: URLSessionWebSocketTask.Message) async {
        guard case .string(let text) = message,
              let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String else { return }

        do {
            switch type {
            case "task_updated":
                try await syncTasks()
            case "sessions_synced":
                try await syncSessions()
            case "settings_updated":
                try await syncSettings()
            case "sync_required":
                try await syncAll()
            default:
                break
            }
        } catch {
            wsLogger.error("Failed to handle WebSocket message '\(type, privacy: .public)': \(error, privacy: .public)")
#if os(iOS) || os(macOS)
            SentryService.captureError(error, context: "WebSocket message '\(type)' triggered sync failure")
#endif
        }
    }

    private func reconnectWithBackoff() async {
        let count = lock.withLock { () -> Int in
            let current = retryCount
            retryCount += 1
            return current
        }

        let delay = min(pow(2.0, Double(count)), Self.maxBackoff)
        try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))

        let shouldRetry = lock.withLock { shouldReconnect }
        guard shouldRetry else { return }

        // After the first failed attempt, try to refresh the access token before
        // reconnecting. This breaks the infinite retry loop that occurs when the
        // token has expired: without a refresh, every reconnect attempt gets a
        // 401 close frame and schedules another backoff indefinitely.
        // Single-flight guard prevents concurrent refresh races.
        if count >= 1 {
            let shouldRefresh = lock.withLock { () -> Bool in
                guard !isRefreshingToken else { return false }
                isRefreshingToken = true
                return true
            }
            if shouldRefresh {
                do {
                    if let refreshToken = await loadRefreshToken() {
                        let response = try await refreshTokens(RefreshRequest(refreshToken: refreshToken))
                        try await saveTokens(response.tokens.accessToken, response.tokens.refreshToken)
                        wsLogger.info("WebSocket token refreshed before reconnect")
                    } else {
                        wsLogger.debug("No refresh token available, reconnecting with existing token")
                    }
                } catch {
                    wsLogger.warning("WebSocket token refresh failed before reconnect: \(error, privacy: .public)")
                }
                lock.withLock { isRefreshingToken = false }
            }
        }

        await performConnect()
    }
}

// MARK: - DependencyValues registration

extension DependencyValues {
    public var webSocketClient: WebSocketClient {
        get { self[WebSocketClient.self] }
        set { self[WebSocketClient.self] = newValue }
    }
}
