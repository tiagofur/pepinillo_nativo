// EditProfileFeature.swift
// Pepinillo — Deep Work Companion for Apple
//
// TCA Reducer for editing user profile.
// Handles name, birth date, and profile image upload.

import Foundation
import ComposableArchitecture

// MARK: - EditProfileFeature

@Reducer
struct EditProfileFeature {

    // MARK: - State

    @ObservableState
    struct State: Equatable {
        var name: String = ""
        var birthDate: Date? = nil
        var imageUrl: String? = nil
        var selectedImageData: Data? = nil
        var isLoading = false
        var isUploading = false
        var errorMessage: String? = nil
    }

    // MARK: - Action

    enum Action: Equatable {
        case nameChanged(String)
        case birthDateChanged(Date?)
        case photoSelected(Data)
        case removePhoto
        case saveTapped
        case cancelTapped

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
    @Dependency(\.persistenceClient) var persistence

    // MARK: - Reducer

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .nameChanged(let name):
                state.name = name
                state.errorMessage = nil
                return .none

            case .birthDateChanged(let date):
                state.birthDate = date
                return .none

            case .photoSelected(let data):
                state.selectedImageData = data
                state.isUploading = true
                return .run { send in
                    do {
                        let response = try await apiClient.uploadProfileImage(data, "image/jpeg")
                        await send(.uploadResponse(.success(response)))
                    } catch let error as APIClientError {
                        await send(.uploadResponse(.failure(error)))
                    } catch {
                        await send(.uploadResponse(.failure(.networkError)))
                    }
                }

            case .removePhoto:
                state.selectedImageData = nil
                state.imageUrl = nil
                return .none

            case .uploadResponse(.success(let response)):
                state.isUploading = false
                state.imageUrl = response.imageUrl
                return .none

            case .uploadResponse(.failure(let error)):
                state.isUploading = false
                state.errorMessage = "Upload failed: \(error.userMessage)"
                return .none

            case .saveTapped:
                guard !state.name.isEmpty else {
                    state.errorMessage = "Name cannot be empty"
                    return .none
                }
                state.isLoading = true
                state.errorMessage = nil
                let birthDateStr: String? = state.birthDate.map {
                    ISO8601DateFormatter().string(from: $0)
                }
                let request = UpdateProfileRequest(
                    name: state.name,
                    imageUrl: state.imageUrl,
                    birthDate: birthDateStr
                )
                return .run { send in
                    do {
                        let user = try await apiClient.updateMe(request)
                        await send(.saveResponse(.success(user)))
                    } catch let error as APIClientError {
                        await send(.saveResponse(.failure(error)))
                    } catch {
                        await send(.saveResponse(.failure(.networkError)))
                    }
                }

            case .saveResponse(.success(let apiUser)):
                state.isLoading = false
                let dto = CachedUserDTO(
                    id: apiUser.id, email: apiUser.email, name: apiUser.name,
                    imageUrl: apiUser.imageUrl, birthDate: apiUser.birthDate,
                    subscriptionTier: apiUser.subscriptionTier,
                    subscriptionExpiresAt: apiUser.subscriptionExpiresAt,
                    emailVerified: apiUser.emailVerified, appleId: apiUser.appleId,
                    createdAt: apiUser.createdAt, updatedAt: apiUser.updatedAt
                )
                return .run { send in
                    try? await persistence.saveCachedUser(dto)
                    await send(.delegate(.profileUpdated(dto)))
                }

            case .saveResponse(.failure(let error)):
                state.isLoading = false
                state.errorMessage = error.userMessage
                return .none

            case .cancelTapped:
                return .send(.delegate(.dismissed))

            case .delegate:
                return .none
            }
        }
    }
}
