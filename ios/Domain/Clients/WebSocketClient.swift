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
        let manager = WebSocketManager()
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
    private var webSocketTask: URLSessionWebSocketTask?
    private var isConnected = false
    private var retryCount = 0
    private var shouldReconnect = false

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
        lock.lock()
        shouldReconnect = true
        retryCount = 0
        lock.unlock()

        await performConnect()
    }

    func disconnect() {
        lock.lock()
        shouldReconnect = false
        let task = webSocketTask
        webSocketTask = nil
        isConnected = false
        lock.unlock()

        task?.cancel(with: .goingAway, reason: nil)
    }

    private func performConnect() async {
        @Dependency(\.keychainClient) var keychain
        guard let token = await keychain.loadAccessToken() else { return }
        let deviceId = keychain.getOrCreateDeviceId()

        guard let url = URL(string: "\(Self.baseWSURL)?token=\(token)&deviceId=\(deviceId)") else { return }

        let session = URLSession(configuration: .default)
        let task = session.webSocketTask(with: url)

        lock.lock()
        webSocketTask = task
        lock.unlock()

        task.resume()

        lock.lock()
        isConnected = true
        retryCount = 0
        lock.unlock()

        await receiveMessages(task: task)
    }

    private func receiveMessages(task: URLSessionWebSocketTask) async {
        while task.state == .running {
            do {
                let message = try await task.receive()
                await handleMessage(message)
            } catch {
                lock.lock()
                isConnected = false
                let shouldRetry = shouldReconnect
                lock.unlock()

                if shouldRetry {
                    await reconnectWithBackoff()
                }
                return
            }
        }

        lock.lock()
        isConnected = false
        let shouldRetry = shouldReconnect
        lock.unlock()

        if shouldRetry {
            await reconnectWithBackoff()
        }
    }

    private func handleMessage(_ message: URLSessionWebSocketTask.Message) async {
        guard case .string(let text) = message,
              let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String else { return }

        @Dependency(\.syncClient) var syncClient

        do {
            switch type {
            case "task_updated":
                try await syncClient.syncTasks()
            case "sessions_synced":
                try await syncClient.syncSessions()
            case "settings_updated":
                try await syncClient.syncSettings()
            case "sync_required":
                try await syncClient.syncAll()
            default:
                break
            }
        } catch {
            print("[WebSocketClient] Failed to handle message '\(type)': \(error)")
        }
    }

    private func reconnectWithBackoff() async {
        lock.lock()
        let count = retryCount
        retryCount += 1
        lock.unlock()

        let delay = min(pow(2.0, Double(count)), Self.maxBackoff)
        try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))

        lock.lock()
        let shouldRetry = shouldReconnect
        lock.unlock()

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
