// EditProfileFeatureTests.swift
// Pepinillo — Deep Work Companion for Apple
//
// Reducer tests for EditProfileFeature local-first behavior.

import Testing
import Foundation
import ComposableArchitecture
import UIKit
@testable import Pepinillo

@Suite("EditProfileFeature")
@MainActor
struct EditProfileFeatureTests {

    @Test("Local save persists manual Apple profile fields without backend tokens")
    func localSavePersistsManualFields() async throws {
        let savedUser = LockIsolated<CachedUserDTO?>(nil)

        var state = EditProfileFeature.State()
        state.name = "Tiago"
        state.email = "tiago@example.com"
        state.originalUser = CachedUserDTO(
            id: "apple-user-123",
            email: "",
            name: "Apple User",
            subscriptionTier: "free",
            emailVerified: false,
            appleId: "apple-user-123",
            createdAt: "2026-04-21T00:00:00Z",
            updatedAt: "2026-04-21T00:00:00Z"
        )

        let store = TestStore(initialState: state) {
            EditProfileFeature()
        } withDependencies: {
            $0.keychainClient.hasTokens = { false }
            $0.persistenceClient.saveCachedUser = { savedUser.setValue($0) }
        }

        store.exhaustivity = .off

        await store.send(.saveTapped) {
            $0.isLoading = true
        }

        let localUser = try #require(savedUser.value)
        #expect(localUser.id == "apple-user-123")
        #expect(localUser.name == "Tiago")
        #expect(localUser.email == "tiago@example.com")
        #expect(localUser.appleId == "apple-user-123")

        await store.receive(.delegate(.profileUpdated(localUser)))
    }

    @Test("Photo selection bypasses backend upload when no tokens exist")
    func photoSelectionBypassesUploadWithoutTokens() async {
        let store = TestStore(initialState: EditProfileFeature.State()) {
            EditProfileFeature()
        } withDependencies: {
            $0.keychainClient.hasTokens = { false }
        }

        let imageData = UIImage(systemName: "person.fill")?.jpegData(compressionQuality: 0.8) ?? Data()

        await store.send(.photoSelected(imageData)) {
            $0.selectedImageData = imageData
            $0.isUploading = true
            $0.errorMessage = nil
        }

        await store.receive(.uploadBypassed) {
            $0.isUploading = false
        }
    }

    @Test("Routine profile save sends UpdateProfileRequest with metricsOptIn == nil and omits key from JSON (S4)")
    func routineProfileSaveDoesNotSendMetricsOptIn() async throws {
        let capturedRequest = LockIsolated<UpdateProfileRequest?>(nil)

        var state = EditProfileFeature.State()
        state.name = "Tiago"
        state.email = "tiago@example.com"
        state.originalUser = CachedUserDTO(
            id: "user-123",
            email: "tiago@example.com",
            name: "Old Name",
            subscriptionTier: "pro",
            emailVerified: true,
            createdAt: "2026-04-21T00:00:00Z",
            updatedAt: "2026-04-21T00:00:00Z",
            metricsOptIn: true
        )

        let apiUser = APIUser(
            id: "user-123",
            email: "tiago@example.com",
            name: "Tiago",
            imageUrl: nil,
            subscriptionTier: "pro",
            subscriptionExpiresAt: nil,
            emailVerified: true,
            createdAt: "2026-04-21T00:00:00Z",
            updatedAt: "2026-04-21T00:00:00Z",
            appleId: nil,
            appleEmail: nil,
            appleName: nil,
            metricsOptIn: true
        )

        let store = TestStore(initialState: state) {
            EditProfileFeature()
        } withDependencies: {
            $0.keychainClient.hasTokens = { true }
            $0.persistenceClient.saveCachedUser = { _ in }
            $0.apiClient.updateMe = { req in
                capturedRequest.setValue(req)
                return apiUser
            }
        }
        store.exhaustivity = .off

        await store.send(.saveTapped) {
            $0.isLoading = true
        }

        await store.receive(\.saveResponse.success)

        let req = try #require(capturedRequest.value)
        #expect(req.metricsOptIn == nil)

        let encoded = try JSONEncoder().encode(UpdateProfileRequest(name: "Test", email: nil, imageUrl: nil))
        let jsonString = try #require(String(data: encoded, encoding: .utf8))
        #expect(!jsonString.contains("metricsOptIn"))
    }
}