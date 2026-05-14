// WebSocketClient.swift
// Pepinillo — Deep Work Companion for Apple
//
// TCA dependency client for real-time WebSocket communication.
// Connects to the backend WebSocket endpoint and dispatches sync
// actions based on incoming server messages.

import Foundation
import ComposableArchitecture

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
        @Dependency(\.syncClient) var syncClient
        let manager = WebSocketManager(
            loadAccessToken: { await keychain.loadAccessToken() },
            getOrCreateDeviceId: { keychain.getOrCreateDeviceId() },
            syncTasks: { try await syncClient.syncTasks() },
            syncSessions: { try await syncClient.syncSessions() },
            syncSettings: { try await syncClient.syncSettings() },
            syncAll: { try await syncClient.syncAll() }
        )
#else
        let manager = WebSocketManager(
            loadAccessToken: { nil },
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

    init(
        loadAccessToken: @escaping @Sendable () async -> String?,
        getOrCreateDeviceId: @escaping @Sendable () -> String,
        syncTasks: @escaping @Sendable () async throws -> Void,
        syncSessions: @escaping @Sendable () async throws -> Void,
        syncSettings: @escaping @Sendable () async throws -> Void,
        syncAll: @escaping @Sendable () async throws -> Void
    ) {
        self.loadAccessToken = loadAccessToken
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

        guard let url = URL(string: "\(Self.baseWSURL)?token=\(token)&deviceId=\(deviceId)") else {
            lock.withLock { isConnecting = false }
            return
        }

        let session = URLSession(configuration: .default)
        let task = session.webSocketTask(with: url)

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
            print("[WebSocketClient] Failed to handle message '\(type)': \(error)")
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
