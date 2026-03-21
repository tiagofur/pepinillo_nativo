// CachedUser.swift
// Pepinillo — Deep Work Companion for Apple
//
// SwiftData model for locally caching the authenticated user profile.
// Used by the backend sync layer to persist user data for offline access.

import Foundation
import SwiftData

@Model
public final class CachedUser {
    public var id: String
    public var email: String
    public var name: String
    public var imageUrl: String?
    public var birthDate: String?
    public var subscriptionTier: String
    public var subscriptionExpiresAt: String?
    public var emailVerified: Bool
    public var appleId: String?
    public var createdAt: String
    public var updatedAt: String

    public init() {
        self.id = ""
        self.email = ""
        self.name = ""
        self.subscriptionTier = "free"
        self.emailVerified = false
        self.createdAt = ""
        self.updatedAt = ""
    }
}
