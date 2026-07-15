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
                Text(store.step == .enterEmail
                    ? String(localized: "forgotpassword.title.enteremail", defaultValue: "Forgot Password")
                    : String(localized: "forgotpassword.title.resetpassword", defaultValue: "Reset Password"))
                    .font(.largeTitle.bold())
                    .foregroundStyle(.primary)

                Text(
                    store.step == .enterEmail
                        ? String(localized: "forgotpassword.subtitle.enteremail", defaultValue: "Enter your email and we'll send you a code to reset your password.")
                        : String(format: String(localized: "forgotpassword.subtitle.entercode", defaultValue: "Enter the code we sent to %@ and choose a new password."), store.email)
                )
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.top, SpacingTokens.xs)
                .padding(.horizontal, SpacingTokens.xl)

                Spacer().frame(height: 48)

                // MARK: Fields
                VStack(spacing: SpacingTokens.base) {
                    if store.step == .enterEmail {
                        emailFields
                    } else {
                        resetFields
                    }
                }
                .padding(.horizontal, SpacingTokens.xl)

                // MARK: Error
                if let error = store.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.top, SpacingTokens.sm)
                        .padding(.horizontal, SpacingTokens.xl)
                        .multilineTextAlignment(.center)
                        .accessibilityLabel(error)
                        .accessibilityAddTraits(.isStaticText)
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
                            Text(store.step == .enterEmail
                                ? String(localized: "forgotpassword.sendcode.button", defaultValue: "Send Code")
                                : String(localized: "forgotpassword.resetpassword.button", defaultValue: "Reset Password"))
                        }
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 52)
                }
                .buttonStyle(.borderedProminent)
                .disabled(store.isLoading)
                .padding(.horizontal, SpacingTokens.xl)

                // MARK: Resend Code (step 2 only)
                if store.step == .enterCode {
                    Button {
                        store.send(.sendCodeTapped)
                    } label: {
                        Text(String(localized: "forgotpassword.resendcode.button", defaultValue: "Resend code"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, SpacingTokens.base)
                }

                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        store.send(.backTapped)
                    } label: {
                        HStack(spacing: SpacingTokens.xs) {
                            Image(systemName: "chevron.left")
                            Text(String(localized: "forgotpassword.back.button", defaultValue: "Back"))
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
            String(localized: "forgotpassword.field.email", defaultValue: "Email"),
            text: Binding(
                get: { store.email },
                set: { store.send(.emailChanged($0)) }
            )
        )
        .textContentType(.emailAddress)
        .keyboardType(.emailAddress)
        .textInputAutocapitalization(.never)
        .textFieldStyle(.roundedBorder)
        .accessibilityLabel(String(localized: "a11y.auth.field.email.label", defaultValue: "Email address"))
    }

    // MARK: - Reset Step

    @ViewBuilder
    private var resetFields: some View {
        TextField(
            String(localized: "forgotpassword.field.resetcode", defaultValue: "Reset Code"),
            text: Binding(
                get: { store.code },
                set: { store.send(.codeChanged($0)) }
            )
        )
        .textContentType(.oneTimeCode)
        .keyboardType(.numberPad)
        .textFieldStyle(.roundedBorder)
        .accessibilityLabel(String(localized: "a11y.forgotpassword.code.label", defaultValue: "Reset code"))
        .accessibilityHint(String(localized: "a11y.forgotpassword.code.hint", defaultValue: "Enter the code sent to your email"))

        // New Password
        HStack {
            Group {
                if store.isPasswordVisible {
                    TextField(
                        String(localized: "forgotpassword.field.newpassword", defaultValue: "New Password"),
                        text: Binding(
                            get: { store.newPassword },
                            set: { store.send(.newPasswordChanged($0)) }
                        )
                    )
                    .textContentType(.newPassword)
                } else {
                    SecureField(
                        String(localized: "forgotpassword.field.newpassword", defaultValue: "New Password"),
                        text: Binding(
                            get: { store.newPassword },
                            set: { store.send(.newPasswordChanged($0)) }
                        )
                    )
                    .textContentType(.newPassword)
                }
            }
            .accessibilityLabel(String(localized: "a11y.forgotpassword.newpassword.label", defaultValue: "New password"))
            .accessibilityHint(String(localized: "a11y.auth.field.password.hint.register", defaultValue: "Must be at least 8 characters with uppercase, lowercase, and a number"))

            Button {
                store.send(.togglePasswordVisibility)
            } label: {
                Image(systemName: store.isPasswordVisible ? "eye.slash" : "eye")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(store.isPasswordVisible
                ? String(localized: "a11y.auth.password.hide", defaultValue: "Hide password")
                : String(localized: "a11y.auth.password.show", defaultValue: "Show password")
            )
        }
        .textFieldStyle(.roundedBorder)

        // Confirm Password
        HStack {
            Group {
                if store.isConfirmPasswordVisible {
                    TextField(
                        String(localized: "forgotpassword.field.confirmpassword", defaultValue: "Confirm Password"),
                        text: Binding(
                            get: { store.confirmPassword },
                            set: { store.send(.confirmPasswordChanged($0)) }
                        )
                    )
                    .textContentType(.newPassword)
                } else {
                    SecureField(
                        String(localized: "forgotpassword.field.confirmpassword", defaultValue: "Confirm Password"),
                        text: Binding(
                            get: { store.confirmPassword },
                            set: { store.send(.confirmPasswordChanged($0)) }
                        )
                    )
                    .textContentType(.newPassword)
                }
            }
            .accessibilityLabel(String(localized: "a11y.forgotpassword.confirmpassword.label", defaultValue: "Confirm new password"))

            Button {
                store.send(.toggleConfirmPasswordVisibility)
            } label: {
                Image(systemName: store.isConfirmPasswordVisible ? "eye.slash" : "eye")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(store.isConfirmPasswordVisible
                ? String(localized: "a11y.auth.password.hide", defaultValue: "Hide password")
                : String(localized: "a11y.auth.password.show", defaultValue: "Show password")
            )
        }
        .textFieldStyle(.roundedBorder)

        Text(String(localized: "forgotpassword.passwordhint", defaultValue: "Min 8 chars, with uppercase, lowercase, and a number"))
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, SpacingTokens.xs)
            .accessibilityHidden(true)
    }
}
