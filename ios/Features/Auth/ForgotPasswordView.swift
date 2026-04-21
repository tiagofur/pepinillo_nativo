// ForgotPasswordView.swift
// Pepinillo — Deep Work Companion for Apple
//
// Two-step forgot password flow: request code → reset password.

import SwiftUI
import ComposableArchitecture

struct ForgotPasswordView: View {
    @Bindable var store: StoreOf<ForgotPasswordFeature>

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Spacer()

                // MARK: Header
                Text(store.step == .enterEmail ? "Forgot Password" : "Reset Password")
                    .font(.largeTitle.bold())
                    .foregroundStyle(.primary)

                Text(
                    store.step == .enterEmail
                        ? "Enter your email and we'll send you a code to reset your password."
                        : "Enter the code we sent to \(store.email) and choose a new password."
                )
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.top, 4)
                .padding(.horizontal, 24)

                Spacer().frame(height: 48)

                // MARK: Fields
                VStack(spacing: 12) {
                    if store.step == .enterEmail {
                        emailFields
                    } else {
                        resetFields
                    }
                }
                .padding(.horizontal, 24)

                // MARK: Error
                if let error = store.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.top, 8)
                        .padding(.horizontal, 24)
                        .multilineTextAlignment(.center)
                }

                Spacer().frame(height: 24)

                // MARK: Primary Button
                Button {
                    if store.step == .enterEmail {
                        store.send(.sendCodeTapped)
                    } else {
                        store.send(.resetPasswordTapped)
                    }
                } label: {
                    Group {
                        if store.isLoading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text(store.step == .enterEmail ? "Send Code" : "Reset Password")
                        }
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                }
                .buttonStyle(.borderedProminent)
                .disabled(store.isLoading)
                .padding(.horizontal, 24)

                // MARK: Resend Code (step 2 only)
                if store.step == .enterCode {
                    Button {
                        store.send(.sendCodeTapped)
                    } label: {
                        Text("Resend code")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 12)
                }

                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        store.send(.backTapped)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                        .foregroundStyle(.primary)
                    }
                }
            }
        }
    }

    // MARK: - Email Step

    @ViewBuilder
    private var emailFields: some View {
        TextField(
            "Email",
            text: Binding(
                get: { store.email },
                set: { store.send(.emailChanged($0)) }
            )
        )
        .textContentType(.emailAddress)
        .keyboardType(.emailAddress)
        .textInputAutocapitalization(.never)
        .textFieldStyle(.roundedBorder)
    }

    // MARK: - Reset Step

    @ViewBuilder
    private var resetFields: some View {
        TextField(
            "Reset Code",
            text: Binding(
                get: { store.code },
                set: { store.send(.codeChanged($0)) }
            )
        )
        .textContentType(.oneTimeCode)
        .keyboardType(.numberPad)
        .textFieldStyle(.roundedBorder)

        // New Password
        HStack {
            Group {
                if store.isPasswordVisible {
                    TextField(
                        "New Password",
                        text: Binding(
                            get: { store.newPassword },
                            set: { store.send(.newPasswordChanged($0)) }
                        )
                    )
                    .textContentType(.newPassword)
                } else {
                    SecureField(
                        "New Password",
                        text: Binding(
                            get: { store.newPassword },
                            set: { store.send(.newPasswordChanged($0)) }
                        )
                    )
                    .textContentType(.newPassword)
                }
            }

            Button {
                store.send(.togglePasswordVisibility)
            } label: {
                Image(systemName: store.isPasswordVisible ? "eye.slash" : "eye")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .textFieldStyle(.roundedBorder)

        // Confirm Password
        HStack {
            Group {
                if store.isConfirmPasswordVisible {
                    TextField(
                        "Confirm Password",
                        text: Binding(
                            get: { store.confirmPassword },
                            set: { store.send(.confirmPasswordChanged($0)) }
                        )
                    )
                    .textContentType(.newPassword)
                } else {
                    SecureField(
                        "Confirm Password",
                        text: Binding(
                            get: { store.confirmPassword },
                            set: { store.send(.confirmPasswordChanged($0)) }
                        )
                    )
                    .textContentType(.newPassword)
                }
            }

            Button {
                store.send(.toggleConfirmPasswordVisibility)
            } label: {
                Image(systemName: store.isConfirmPasswordVisible ? "eye.slash" : "eye")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .textFieldStyle(.roundedBorder)

        Text("Min 8 chars, with uppercase, lowercase, and a number")
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 4)
    }
}
