// EditProfileFeature.swift
// Pepinillo — Deep Work Companion for Apple
//
// TCA Reducer for editing user profile.
// Handles name, birth date, and profile image upload.

import Foundation
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif
import ComposableArchitecture

// MARK: - EditProfileFeature

@Reducer
struct EditProfileFeature {

    // MARK: - State

    @ObservableState
    struct State: Equatable {
        var name: String = ""
        var email: String = ""
        var imageUrl: String? = nil
        var selectedImageData: Data? = nil
        var isLoading = false
        var isUploading = false
        var errorMessage: String? = nil
        var originalUser: CachedUserDTO? = nil
    }

    // MARK: - Action

    enum Action: BindableAction, Equatable {
        case binding(BindingAction<State>)
        case photoSelected(Data)
        case removePhoto
        case saveTapped
        case cancelTapped

        case uploadBypassed
        case uploadResponse(Result<ImageUploadResponse, APIClientError>)
        case saveResponse(Result<APIUser, APIClientError>)

        case delegate(Delegate)
        enum Delegate: Equatable {
            case profileUpdated(CachedUserDTO)
            case dismissed
        }
    }

    // MARK: - Dependencies

    @Dependency(\.apiClient) var apiClient
    @Dependency(\.keychainClient) var keychain
    @Dependency(\.persistenceClient) var persistence
    @Dependency(\.dismiss) var dismiss

    // MARK: - Reducer

    var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding(\.name):
                state.errorMessage = nil
                return .none

            case .binding(\.email):
                state.errorMessage = nil
                return .none

            case .binding:
                return .none


            case .photoSelected(let data):
                state.selectedImageData = data
                state.errorMessage = nil
                state.isUploading = true
                return .run { [keychain] send in
                    guard await keychain.hasTokens() else {
                        await send(.uploadBypassed)
                        return
                    }
                    do {
                        let response = try await apiClient.uploadProfileImage(data, "image/jpeg")
                        await send(.uploadResponse(.success(response)))
                    } catch let error as APIClientError {
                        await send(.uploadResponse(.failure(error)))
                    } catch {
                        await send(.uploadResponse(.failure(.networkError)))
                    }
                }

            case .uploadBypassed:
                state.isUploading = false
                return .none

            case .removePhoto:
                state.selectedImageData = nil
                state.imageUrl = nil
                state.errorMessage = nil
                return .none

            case .uploadResponse(.success(let response)):
                state.isUploading = false
                state.imageUrl = response.imageUrl
                return .none

            case .uploadResponse(.failure(let error)):
                state.isUploading = false
                state.errorMessage = String(localized: "Upload failed: \(error.userMessage)")
                return .none

            case .saveTapped:
                let trimmedName = state.name.trimmingCharacters(in: .whitespacesAndNewlines)
                let trimmedEmail = state.email.trimmingCharacters(in: .whitespacesAndNewlines)

                guard !trimmedName.isEmpty else {
                    state.errorMessage = String(localized: "Name cannot be empty")
                    return .none
                }
                state.isLoading = true
                state.errorMessage = nil
                let originalUser = state.originalUser
                let currentImageUrl = state.imageUrl
                let selectedImageData = state.selectedImageData
                return .run { [keychain, persistence, dismiss] send in
                    let imageReference = Self.resolvedImageReference(
                        currentImageUrl: currentImageUrl,
                        selectedImageData: selectedImageData
                    )
                    let localDTO = Self.makeLocalUser(
                        originalUser: originalUser,
                        name: trimmedName,
                        email: trimmedEmail,
                        imageReference: imageReference
                    )
                    try? await persistence.saveCachedUser(localDTO)

                    guard await keychain.hasTokens() else {
                        await send(.delegate(.profileUpdated(localDTO)))
                        await dismiss()
                        return
                    }

                    do {
                        let request = UpdateProfileRequest(
                            name: trimmedName,
                            email: trimmedEmail.isEmpty ? nil : trimmedEmail,
                            imageUrl: imageReference?.hasPrefix("data:image") == true ? nil : imageReference
                        )
                        let user = try await apiClient.updateMe(request)
                        await send(.saveResponse(.success(user)))
                    } catch {
                        await send(.delegate(.profileUpdated(localDTO)))
                        await dismiss()
                    }
                }

            case .saveResponse(.success(let apiUser)):
                state.isLoading = false
                let trimmedName = state.name.trimmingCharacters(in: .whitespacesAndNewlines)
                let trimmedEmail = state.email.trimmingCharacters(in: .whitespacesAndNewlines)
                let resolvedEmail = trimmedEmail.isEmpty ? apiUser.email : trimmedEmail
                let imageReference = Self.resolvedImageReference(
                    currentImageUrl: state.imageUrl ?? apiUser.imageUrl,
                    selectedImageData: state.selectedImageData
                )
                let dto = CachedUserDTO(
                    id: apiUser.id,
                    email: resolvedEmail,
                    name: trimmedName.isEmpty ? apiUser.name : trimmedName,
                    imageUrl: imageReference,
                    subscriptionTier: apiUser.subscriptionTier,
                    subscriptionExpiresAt: apiUser.subscriptionExpiresAt,
                    emailVerified: resolvedEmail == apiUser.email ? apiUser.emailVerified : false,
                    appleId: apiUser.appleId,
                    createdAt: apiUser.createdAt, updatedAt: apiUser.updatedAt
                )
                return .run { [dismiss] send in
                    try? await persistence.saveCachedUser(dto)
                    await send(.delegate(.profileUpdated(dto)))
                    await dismiss()
                }

            case .saveResponse(.failure(let error)):
                state.isLoading = false
                state.errorMessage = error.userMessage
                return .none

            case .cancelTapped:
                return .run { send in
                    await send(.delegate(.dismissed))
                    await dismiss()
                }

            case .delegate:
                return .none
            }
        }
    }

    private static func resolvedImageReference(currentImageUrl: String?, selectedImageData: Data?) -> String? {
        if let currentImageUrl, !currentImageUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return currentImageUrl
        }

        guard let selectedImageData else {
            return nil
        }
        return dataURIString(from: selectedImageData)
    }

    private static func dataURIString(from data: Data) -> String? {
        guard let image = PlatformImage(data: data),
              let jpegData = platformJPEGData(from: image, compressionQuality: 0.78) else {
            return nil
        }
        return "data:image/jpeg;base64,\(jpegData.base64EncodedString())"
    }

    private static func makeLocalUser(
        originalUser: CachedUserDTO?,
        name: String,
        email: String,
        imageReference: String?
    ) -> CachedUserDTO {
        let now = ISO8601DateFormatter().string(from: .now)
        let preservedUser = originalUser ?? CachedUserDTO(
            id: UUID().uuidString,
            email: "",
            name: "",
            subscriptionTier: "free",
            emailVerified: false,
            createdAt: now,
            updatedAt: now
        )
        let originalEmail = preservedUser.email.trimmingCharacters(in: .whitespacesAndNewlines)

        return CachedUserDTO(
            id: preservedUser.id,
            email: email,
            name: name,
            imageUrl: imageReference,
            subscriptionTier: preservedUser.subscriptionTier,
            subscriptionExpiresAt: preservedUser.subscriptionExpiresAt,
            emailVerified: !originalEmail.isEmpty && email == originalEmail && preservedUser.emailVerified,
            appleId: preservedUser.appleId,
            createdAt: preservedUser.createdAt.isEmpty ? now : preservedUser.createdAt,
            updatedAt: now
        )
    }
}

#if canImport(UIKit)
private typealias PlatformImage = UIImage

private func platformJPEGData(from image: PlatformImage, compressionQuality: CGFloat) -> Data? {
    image.jpegData(compressionQuality: compressionQuality)
}
#elseif canImport(AppKit)
private typealias PlatformImage = NSImage

private func platformJPEGData(from image: PlatformImage, compressionQuality: CGFloat) -> Data? {
    guard let tiffRepresentation = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiffRepresentation) else {
        return nil
    }
    return bitmap.representation(
        using: .jpeg,
        properties: [.compressionFactor: compressionQuality]
    )
}
#endif
