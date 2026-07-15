// KeychainClient.swift
// Pepinillo — Deep Work Companion for Apple
//
// TCA dependency client for secure token storage via iOS Keychain.

import Foundation
import Security
import ComposableArchitecture

// MARK: - Client

@DependencyClient
public struct KeychainClient: Sendable {
    public var saveTokens: @Sendable (_ accessToken: String, _ refreshToken: String) async throws -> Void
    public var loadAccessToken: @Sendable () async -> String?
    public var loadRefreshToken: @Sendable () async -> String?
    public var deleteTokens: @Sendable () async throws -> Void
    public var hasTokens: @Sendable () async -> Bool = { false }
    public var getOrCreateDeviceId: @Sendable () -> String = { UUID().uuidString }
}

// MARK: - Token pair (atomic write #201)

private struct KeychainTokenPair: Codable {
    let accessToken: String
    let refreshToken: String
}

// MARK: - Live implementation

extension KeychainClient: DependencyKey {
    private static let service = "com.pepinillo.app.auth"
    private static let tokenPairAccount = "authTokenPair"
    private static let accessTokenAccount = "accessToken"
    private static let refreshTokenAccount = "refreshToken"

    public static let liveValue = KeychainClient(
        saveTokens: { accessToken, refreshToken in
            let pair = KeychainTokenPair(accessToken: accessToken, refreshToken: refreshToken)
            let data = try JSONEncoder().encode(pair)
            try saveRaw(account: tokenPairAccount, data: data)
            // Remove legacy split entries so reads cannot return a partial pair.
            delete(account: accessTokenAccount)
            delete(account: refreshTokenAccount)
        },
        loadAccessToken: {
            loadTokenPair()?.accessToken
        },
        loadRefreshToken: {
            loadTokenPair()?.refreshToken
        },
        deleteTokens: {
            delete(account: tokenPairAccount)
            delete(account: accessTokenAccount)
            delete(account: refreshTokenAccount)
        },
        hasTokens: {
            loadTokenPair()?.accessToken != nil
        },
        getOrCreateDeviceId: {
            let keychainAccount = "deviceId"
            // 1. Already in Keychain — fast path
            if let existing = load(account: keychainAccount) {
                return existing
            }
            // 2. Migration: read from UserDefaults (legacy), move to Keychain, clear
            let legacyKey = "com.pepinillo.deviceId"
            if let legacy = UserDefaults.standard.string(forKey: legacyKey) {
                try? save(account: keychainAccount, value: legacy)
                UserDefaults.standard.removeObject(forKey: legacyKey)
                return legacy
            }
            // 3. First install: generate, persist in Keychain
            let newId = UUID().uuidString
            try? save(account: keychainAccount, value: newId)
            return newId
        }
    )

    public static let testValue = KeychainClient()

    // MARK: - Token pair helpers

    private static func loadTokenPair() -> KeychainTokenPair? {
        if let data = loadRaw(account: tokenPairAccount),
           let pair = try? JSONDecoder().decode(KeychainTokenPair.self, from: data) {
            return pair
        }
        // Migrate legacy split-token layout into the atomic pair.
        guard let access = load(account: accessTokenAccount),
              let refresh = load(account: refreshTokenAccount) else {
            return nil
        }
        let migrated = KeychainTokenPair(accessToken: access, refreshToken: refresh)
        if let data = try? JSONEncoder().encode(migrated) {
            try? saveRaw(account: tokenPairAccount, data: data)
            delete(account: accessTokenAccount)
            delete(account: refreshTokenAccount)
        }
        return migrated
    }

    // MARK: - Private Keychain helpers

    private static func save(account: String, value: String) throws {
        guard let data = value.data(using: .utf8) else { return }
        try saveRaw(account: account, data: data)
    }

    private static func saveRaw(account: String, data: Data) throws {
        delete(account: account)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }

    private static func load(account: String) -> String? {
        guard let data = loadRaw(account: account) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static func loadRaw(account: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return data
    }

    @discardableResult
    private static func delete(account: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}

// MARK: - Keychain Error

enum KeychainError: Error {
    case saveFailed(OSStatus)
}

// MARK: - DependencyValues registration

extension DependencyValues {
    public var keychainClient: KeychainClient {
        get { self[KeychainClient.self] }
        set { self[KeychainClient.self] = newValue }
    }
}