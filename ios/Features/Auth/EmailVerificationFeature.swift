// EmailVerificationFeature.swift
// Pepinillo — Deep Work Companion for Apple
//
// TCA Reducer for the post-registration email verification gate.
// Shown after login/register when the user's email is not yet verified.

import Foundation
import ComposableArchitecture

// MARK: - EmailVerificationFeature

@Reducer
struct EmailVerificationFeature {

    // MARK: - State

    @ObservableState
    struct State: Equatable {
        var email: String
        var code = ""
        var isLoading = false
        var isResending = false
        var errorMessage: String? = nil
        var resendSuccessMessage: String? = nil
    }

    // MARK: - Action

    enum Action: Equatable {
        case codeChanged(String)
        case verifyTapped
        case resendTapped
        case dismissError
        case signOutTapped

        case verifyResponse(Result<VerifyEmailResponse, APIClientError>)
        case resendResponse(Result<Bool, APIClientError>)

        case delegate(Delegate)
        enum Delegate: Equatable {
            case verificationSucceeded(CachedUserDTO)
            case signOutRequested
        }
    }

    // MARK: - Dependencies

    @Dependency(\.apiClient) var apiClient
    @Dependency(\.keychainClient) var keychain
    @Dependency(\.persistenceClient) var persistence

    // MARK: - Reducer

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {

            case .codeChanged(let code):
                state.code = code
                state.errorMessage = nil
                state.resendSuccessMessage = nil
                return .none

            case .verifyTapped:
                guard state.code.count == 6 else {
                    state.errorMessage = String(localized: "Enter the 6-digit code sent to your email")
                    return .none
                }
                state.isLoading = true
                state.errorMessage = nil
                let req = VerifyEmailRequest(email: state.email, code: state.code)
                return .run { send in
                    do {
                        let response = try await apiClient.verifyEmail(req)
                        await send(.verifyResponse(.success(response)))
                    } catch let error as APIClientError {
                        await send(.verifyResponse(.failure(error)))
                    } catch {
                        await send(.verifyResponse(.failure(.networkError)))
                    }
                }

            case .resendTapped:
                state.isResending = true
                state.errorMessage = nil
                state.resendSuccessMessage = nil
                let req = ResendVerificationRequest(email: state.email)
                return .run { send in
                    do {
                        try await apiClient.resendVerificationEmail(req)
                        await send(.resendResponse(.success(true)))
                    } catch let error as APIClientError {
                        await send(.resendResponse(.failure(error)))
                    } catch {
                        await send(.resendResponse(.failure(.networkError)))
                    }
                }

            case .verifyResponse(.success(let response)):
                state.isLoading = false
                let userDTO = CachedUserDTO(
                    id: response.user.id,
                    email: response.user.email,
                    name: response.user.name,
                    imageUrl: response.user.imageUrl,
                    birthDate: response.user.birthDate,
                    subscriptionTier: response.user.subscriptionTier,
                    subscriptionExpiresAt: response.user.subscriptionExpiresAt,
                    emailVerified: response.user.emailVerified,
                    appleId: response.user.appleId,
                    createdAt: response.user.createdAt,
                    updatedAt: response.user.updatedAt
                )
                return .run { [userDTO] send in
                    try await keychain.saveTokens(
                        response.tokens.accessToken,
                        response.tokens.refreshToken
                    )
                    try await persistence.saveCachedUser(userDTO)
                    await send(.delegate(.verificationSucceeded(userDTO)))
                }

            case .verifyResponse(.failure(let error)):
                state.isLoading = false
                state.errorMessage = error.userMessage
                return .none

            case .resendResponse(.success):
                state.isResending = false
                state.resendSuccessMessage = String(localized: "Code resent — check your inbox")
                return .none

            case .resendResponse(.failure(let error)):
                state.isResending = false
                state.errorMessage = error.userMessage
                return .none

            case .dismissError:
                state.errorMessage = nil
                return .none

            case .signOutTapped:
                // Escape hatch for a user who entered the wrong email or cannot
                // access the inbox. Without this the non-dismissible sheet traps
                // them; on force-quit the unverified persisted session bypassed
                // the gate entirely (#192).
                return .send(.delegate(.signOutRequested))

            case .delegate:
                return .none
            }
        }
    }
}
