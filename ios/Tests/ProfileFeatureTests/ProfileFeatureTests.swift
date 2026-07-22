// ProfileFeatureTests.swift
// Pepinillo — Deep Work Companion for Apple
//
// Reducer tests for profile refresh merge (SIWA / blank server fields).

import Testing
import Foundation
import ComposableArchitecture
@testable import Pepinillo

@Suite("ProfileFeature")
@MainActor
struct ProfileFeatureTests {

    @Test("profileRefreshed keeps local name/email when server sends blank or Apple User")
    func profileRefreshPreservesLocalIdentity() async {
        let savedUser = LockIsolated<CachedUserDTO?>(nil)

        var state = ProfileFeature.State()
        state.user = CachedUserDTO(
            id: "user-1",
            email: "tiago@example.com",
            name: "Tiago",
            subscriptionTier: "free",
            emailVerified: true,
            appleId: "apple-1",
            createdAt: "2026-01-01T00:00:00Z",
            updatedAt: "2026-01-01T00:00:00Z"
        )

        let store = TestStore(initialState: state) {
            ProfileFeature()
        } withDependencies: {
            $0.persistenceClient.saveCachedUser = { savedUser.setValue($0) }
        }

        let apiUser = APIUser(
            id: "user-1",
            email: "",
            name: "Apple User",
            imageUrl: "https://cdn.example.com/a.png",
            subscriptionTier: "pro",
            subscriptionExpiresAt: "2027-01-01T00:00:00Z",
            emailVerified: true,
            createdAt: "2026-01-01T00:00:00Z",
            updatedAt: "2026-04-01T00:00:00Z",
            appleId: "apple-1",
            appleEmail: nil,
            appleName: nil
        )

        await store.send(.profileRefreshed(.success(apiUser))) {
            $0.user = CachedUserDTO(
                id: "user-1",
                email: "tiago@example.com",
                name: "Tiago",
                imageUrl: "https://cdn.example.com/a.png",
                subscriptionTier: "pro",
                subscriptionExpiresAt: "2027-01-01T00:00:00Z",
                emailVerified: true,
                appleId: "apple-1",
                createdAt: "2026-01-01T00:00:00Z",
                updatedAt: "2026-04-01T00:00:00Z"
            )
        }

        let saved = savedUser.value
        #expect(saved?.name == "Tiago")
        #expect(saved?.email == "tiago@example.com")
        #expect(saved?.subscriptionTier == "pro")
        #expect(saved?.imageUrl == "https://cdn.example.com/a.png")
    }

    @Test("profileRefreshed prefers good server name and email over local")
    func profileRefreshPrefersServerWhenGood() async {
        var state = ProfileFeature.State()
        state.user = CachedUserDTO(
            id: "user-1",
            email: "old@example.com",
            name: "Old Name",
            subscriptionTier: "free",
            emailVerified: false
        )

        let store = TestStore(initialState: state) {
            ProfileFeature()
        } withDependencies: {
            $0.persistenceClient.saveCachedUser = { _ in }
        }

        let apiUser = APIUser(
            id: "user-1",
            email: "new@example.com",
            name: "New Name",
            imageUrl: nil,
            subscriptionTier: "free",
            subscriptionExpiresAt: nil,
            emailVerified: true,
            createdAt: "2026-01-01T00:00:00Z",
            updatedAt: "2026-04-01T00:00:00Z",
            appleId: nil,
            appleEmail: nil,
            appleName: nil
        )

        await store.send(.profileRefreshed(.success(apiUser))) {
            $0.user = CachedUserDTO(
                id: "user-1",
                email: "new@example.com",
                name: "New Name",
                imageUrl: nil,
                subscriptionTier: "free",
                subscriptionExpiresAt: nil,
                emailVerified: true,
                appleId: nil,
                createdAt: "2026-01-01T00:00:00Z",
                updatedAt: "2026-04-01T00:00:00Z"
            )
        }
    }
}
