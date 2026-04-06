// ForgotPasswordFeature.swift
// Pepinillo — Deep Work Companion for Apple
//
// TCA Reducer for the forgot password flow (2-step: request code, then reset).

import Foundation
import ComposableArchitecture

// MARK: - ForgotPasswordFeature

@Reducer
struct ForgotPasswordFeature {

    // MARK: - Step

    enum Step: Equatable {
        case enterEmail
        case enterCode
    }

    // MARK: - State

    @ObservableState
    struct State: Equatable {
        var step: Step = .enterEmail
        var email = ""
        var code = ""
        var newPassword = ""
        var confirmPassword = ""
        var isLoading = false
        var errorMessage: String? = nil
        var isPasswordVisible = false
        var isConfirmPasswordVisible = false
    }

    // MARK: - Action

    enum Action: Equatable {
        case emailChanged(String)
        case codeChanged(String)
        case newPasswordChanged(String)
        case confirmPasswordChanged(String)
        case togglePasswordVisibility
        case toggleConfirmPasswordVisibility
        case sendCodeTapped
        case resetPasswordTapped
        case dismissError
        case backTapped

        case sendCodeResponse(Result<Bool, APIClientError>)
        case resetPasswordResponse(Result<Bool, APIClientError>)

        case delegate(Delegate)
        enum Delegate: Equatable {
            case resetSuccess
            case dismiss
        }
    }

    // MARK: - Dependencies

    @Dependency(\.apiClient) var apiClient

    // MARK: - Reducer

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {

            case .emailChanged(let email):
                state.email = email
                state.errorMessage = nil
                return .none

            case .codeChanged(let code):
                state.code = code
                state.errorMessage = nil
                return .none

            case .newPasswordChanged(let password):
                state.newPassword = password
                state.errorMessage = nil
                return .none

            case .confirmPasswordChanged(let password):
                state.confirmPassword = password
                state.errorMessage = nil
                return .none

            case .togglePasswordVisibility:
                state.isPasswordVisible.toggle()
                return .none

            case .toggleConfirmPasswordVisibility:
                state.isConfirmPasswordVisible.toggle()
                return .none

            case .dismissError:
                state.errorMessage = nil
                return .none

            case .backTapped:
                if state.step == .enterCode {
                    state.step = .enterEmail
                    state.errorMessage = nil
                    return .none
                } else {
                    return .send(.delegate(.dismiss))
                }

            case .sendCodeTapped:
                guard !state.email.isEmpty else {
                    state.errorMessage = "Please enter your email address"
                    return .none
                }
                state.isLoading = true
                state.errorMessage = nil
                let request = ForgotPasswordRequest(email: state.email)
                return .run { send in
                    do {
                        try await apiClient.forgotPassword(request)
                        await send(.sendCodeResponse(.success(true)))
                    } catch let error as APIClientError {
                        await send(.sendCodeResponse(.failure(error)))
                    } catch {
                        await send(.sendCodeResponse(.failure(.networkError)))
                    }
                }

            case .sendCodeResponse(.success):
                state.isLoading = false
                state.step = .enterCode
                state.code = ""
                return .none

            case .sendCodeResponse(.failure(let error)):
                state.isLoading = false
                state.errorMessage = error.userMessage
                return .none

            case .resetPasswordTapped:
                guard !state.code.isEmpty else {
                    state.errorMessage = "Please enter the code we sent to your email"
                    return .none
                }
                guard !state.newPassword.isEmpty else {
                    state.errorMessage = "Please enter a new password"
                    return .none
                }
                guard state.newPassword == state.confirmPassword else {
                    state.errorMessage = "Passwords do not match"
                    return .none
                }
                if let validationError = validatePassword(state.newPassword) {
                    state.errorMessage = validationError
                    return .none
                }
                state.isLoading = true
                state.errorMessage = nil
                let request = ResetPasswordRequest(
                    email: state.email,
                    code: state.code,
                    newPassword: state.newPassword
                )
                return .run { send in
                    do {
                        try await apiClient.resetPassword(request)
                        await send(.resetPasswordResponse(.success(true)))
                    } catch let error as APIClientError {
                        await send(.resetPasswordResponse(.failure(error)))
                    } catch {
                        await send(.resetPasswordResponse(.failure(.networkError)))
                    }
                }

            case .resetPasswordResponse(.success):
                state.isLoading = false
                return .send(.delegate(.resetSuccess))

            case .resetPasswordResponse(.failure(let error)):
                state.isLoading = false
                state.errorMessage = error.userMessage
                return .none

            case .delegate:
                return .none
            }
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
