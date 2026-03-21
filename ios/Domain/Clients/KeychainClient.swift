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
}

// MARK: - Live implementation

extension KeychainClient: DependencyKey {
    private static let service = "com.pepinillo.app.auth"
    private static let accessTokenAccount = "accessToken"
    private static let refreshTokenAccount = "refreshToken"

    public static let liveValue = KeychainClient(
        saveTokens: { accessToken, refreshToken in
            try save(account: accessTokenAccount, value: accessToken)
            try save(account: refreshTokenAccount, value: refreshToken)
        },
        loadAccessToken: {
            load(account: accessTokenAccount)
        },
        loadRefreshToken: {
            load(account: refreshTokenAccount)
        },
        deleteTokens: {
            delete(account: accessTokenAccount)
            delete(account: refreshTokenAccount)
        },
        hasTokens: {
            load(account: accessTokenAccount) != nil
        }
    )

    public static let testValue = KeychainClient()

    // MARK: - Private Keychain helpers

    private static func save(account: String, value: String) throws {
        guard let data = value.data(using: .utf8) else { return }
        delete(account: account)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
        ]
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }

    private static func load(account: String) -> String? {
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
        return String(data: data, encoding: .utf8)
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
