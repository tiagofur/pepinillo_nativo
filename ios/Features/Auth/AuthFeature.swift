// AuthFeature.swift
// Pepinillo — Deep Work Companion for Apple
//
// TCA Reducer for authentication (login + register).
// Handles email/password auth, delegates authenticated user or guest mode.

import Foundation
import ComposableArchitecture

// MARK: - AuthFeature

@Reducer
struct AuthFeature {

    // MARK: - State

    @ObservableState
    struct State: Equatable {
        var mode: AuthMode = .login
        var email = ""
        var password = ""
        var name = ""
        var isLoading = false
        var errorMessage: String? = nil
        var isPasswordVisible = false
        var showMergeDialog = false
        var isSyncing = false
        @Presents var forgotPassword: ForgotPasswordFeature.State?
    }

    enum AuthMode: Equatable {
        case login, register
    }

    // MARK: - Action

    enum Action: Equatable {
        case emailChanged(String)
        case passwordChanged(String)
        case nameChanged(String)
        case togglePasswordVisibility
        case switchMode(AuthMode)
        case dismissError

        case loginTapped
        case registerTapped
        case continueAsGuestTapped
        case forgotPasswordTapped

        case authResponse(Result<AuthResponse, APIClientError>)
        case forgotPassword(PresentationAction<ForgotPasswordFeature.Action>)

        case authSucceeded(CachedUserDTO)
        case initialSyncCompleted(CachedUserDTO)
        case initialSyncFailed(String)
        case mergeTapped
        case useAccountOnlyTapped
        case dismissMergeDialog

        case delegate(Delegate)
        enum Delegate: Equatable {
            case authenticated(CachedUserDTO)
            case guestModeSelected
            case emailVerificationRequired(email: String)
        }
    }

    // MARK: - Dependencies

    @Dependency(\.apiClient) var apiClient
    @Dependency(\.keychainClient) var keychain
    @Dependency(\.persistenceClient) var persistence
    @Dependency(\.syncClient) var syncClient

    // MARK: - Reducer

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {

            case .emailChanged(let email):
                state.email = email
                state.errorMessage = nil
                return .none

            case .passwordChanged(let password):
                state.password = password
                state.errorMessage = nil
                return .none

            case .nameChanged(let name):
                state.name = name
                state.errorMessage = nil
                return .none

            case .togglePasswordVisibility:
                state.isPasswordVisible.toggle()
                return .none

            case .switchMode(let mode):
                state.mode = mode
                state.errorMessage = nil
                return .none

            case .dismissError:
                state.errorMessage = nil
                return .none

            case .loginTapped:
                guard !state.email.isEmpty, !state.password.isEmpty else {
                    state.errorMessage = "Please fill in all fields"
                    return .none
                }
                state.isLoading = true
                state.errorMessage = nil
                let request = LoginRequest(email: state.email, password: state.password)
                return .run { send in
                    do {
                        let response = try await apiClient.login(request)
                        await send(.authResponse(.success(response)))
                    } catch let error as APIClientError {
                        await send(.authResponse(.failure(error)))
                    } catch {
                        await send(.authResponse(.failure(.networkError)))
                    }
                }

            case .registerTapped:
                guard !state.name.isEmpty, !state.email.isEmpty, !state.password.isEmpty else {
                    state.errorMessage = "Please fill in all fields"
                    return .none
                }
                if let validationError = validatePassword(state.password) {
                    state.errorMessage = validationError
                    return .none
                }
                state.isLoading = true
                state.errorMessage = nil
                let request = RegisterRequest(email: state.email, name: state.name, password: state.password)
                return .run { send in
                    do {
                        let response = try await apiClient.register(request)
                        await send(.authResponse(.success(response)))
                    } catch let error as APIClientError {
                        await send(.authResponse(.failure(error)))
                    } catch {
                        await send(.authResponse(.failure(.networkError)))
                    }
                }

            case .authResponse(.success(let response)):
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
                return .run { send in
                    try await keychain.saveTokens(response.tokens.accessToken, response.tokens.refreshToken)
                    try await persistence.saveCachedUser(userDTO)
                    await send(.authSucceeded(userDTO))
                }

            case .authResponse(.failure(let error)):
                state.isLoading = false
                state.errorMessage = error.userMessage
                return .none

            case .continueAsGuestTapped:
                return .send(.delegate(.guestModeSelected))

            // MARK: - Post-auth sync flow

            case .authSucceeded(let userDTO):
                guard userDTO.emailVerified else {
                    state.isSyncing = false
                    return .send(.delegate(.emailVerificationRequired(email: userDTO.email)))
                }
                state.isSyncing = true
                return .run { [persistence, syncClient] send in
                    // Check if there's local data to merge
                    let tasks = try await persistence.fetchTasks()
                    let sessions = try await persistence.fetchSessions(Date.distantPast, Date.now)
                    let hasLocalData = !tasks.isEmpty || !sessions.isEmpty

                    if hasLocalData {
                        do {
                            let hasExistingData = try await syncClient.initialUpload()
                            if hasExistingData {
                                // Server has data too — ask user what to do
                                await send(.initialSyncCompleted(userDTO))
                            } else {
                                // No server data — local data uploaded successfully
                                await send(.delegate(.authenticated(userDTO)))
                            }
                        } catch {
                            await send(.initialSyncFailed(error.localizedDescription))
                        }
                    } else {
                        // No local data — pull everything from server
                        do {
                            try await syncClient.performInitialSync()
                            await send(.delegate(.authenticated(userDTO)))
                        } catch {
                            // Sync failed but auth succeeded — continue anyway
                            await send(.delegate(.authenticated(userDTO)))
                        }
                    }
                }

            case .initialSyncCompleted:
                state.isSyncing = false
                state.showMergeDialog = true
                // User will choose merge or account-only via dialog
                // userDTO is already cached in persistence
                return .none

            case .initialSyncFailed(let message):
                state.isSyncing = false
                state.errorMessage = "Sync failed: \(message)"
                return .none

            case .mergeTapped:
                state.showMergeDialog = false
                // Data was already uploaded via initialUpload — just continue
                return .run { [persistence] send in
                    if let user = try await persistence.fetchCachedUser() {
                        await send(.delegate(.authenticated(user)))
                    }
                }

            case .useAccountOnlyTapped:
                state.showMergeDialog = false
                state.isSyncing = true
                return .run { [syncClient, persistence] send in
                    do {
                        try await syncClient.wipeAndSync()
                    } catch {
                        // Best-effort wipe — continue regardless
                    }
                    if let user = try await persistence.fetchCachedUser() {
                        await send(.delegate(.authenticated(user)))
                    }
                }

            case .dismissMergeDialog:
                state.showMergeDialog = false
                return .none

            case .forgotPasswordTapped:
                state.forgotPassword = ForgotPasswordFeature.State(email: state.email)
                return .none

            case .forgotPassword(.presented(.delegate(.resetSuccess))):
                state.forgotPassword = nil
                return .none

            case .forgotPassword(.presented(.delegate(.dismiss))):
                state.forgotPassword = nil
                return .none

            case .forgotPassword:
                return .none

            case .delegate:
                return .none
            }
        }
        .ifLet(\.$forgotPassword, action: \.forgotPassword) {
            ForgotPasswordFeature()
        }
    }

    // MARK: - Password Validation

    private func validatePassword(_ password: String) -> String? {
        if password.count < 8 { return "Password must be at least 8 characters" }
        if !password.contains(where: { $0.isUppercase }) { return "Password needs at least one uppercase letter" }
        if !password.contains(where: { $0.isLowercase }) { return "Password needs at least one lowercase letter" }
        if !password.contains(where: { $0.isNumber }) { return "Password needs at least one number" }
        return nil
    }
}
