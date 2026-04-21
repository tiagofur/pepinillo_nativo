// AppleAuthHelper.swift
// Pepinillo — Deep Work Companion for Apple
//
// Shared nonce generation and SHA-256 hashing utilities for Sign in with Apple.
// Used by AuthView and AccountView to avoid duplicate implementations.

import CryptoKit
import Foundation
import Security

enum AppleAuthHelper {
    static func generateNonce(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remaining = length
        while remaining > 0 {
            var randoms = [UInt8](repeating: 0, count: 16)
            let status = SecRandomCopyBytes(kSecRandomDefault, randoms.count, &randoms)
            precondition(status == errSecSuccess, "Unable to generate nonce. SecRandomCopyBytes failed with \(status)")
            randoms.forEach { byte in
                guard remaining > 0 else { return }
                if byte < charset.count {
                    result.append(charset[Int(byte)])
                    remaining -= 1
                }
            }
        }
        return result
    }

    static func sha256Hex(_ input: String) -> String {
        let data = Data(input.utf8)
        let hashed = SHA256.hash(data: data)
        return hashed.compactMap { String(format: "%02x", $0) }.joined()
    }
}
