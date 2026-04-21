// EmailVerificationView.swift
// Pepinillo — Deep Work Companion for Apple
//
// Full-screen verification gate shown after email/password registration or
// login when the user's email address has not yet been confirmed.

import SwiftUI
import ComposableArchitecture

struct EmailVerificationView: View {
    @Bindable var store: StoreOf<EmailVerificationFeature>

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // MARK: - Icon + heading
            VStack(spacing: 16) {
                Image(systemName: "envelope.badge")
                    .font(.system(size: 64))
                    .foregroundStyle(Color.accentColor)
                    .accessibilityHidden(true)

                Text("Check your inbox")
                    .font(.title2.bold())

                Text("We sent a 6-digit code to\n**\(store.email)**")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .accessibilityLabel("We sent a 6-digit code to \(store.email)")
            }

            // MARK: - Code field
            VStack(spacing: 12) {
                TextField("123456", text: $store.code.sending(\.codeChanged))
                    .keyboardType(.numberPad)
                    .font(.title.monospacedDigit())
                    .multilineTextAlignment(.center)
                    .padding()
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
                    .accessibilityLabel(String(localized: "a11y.emailverification.code.label", defaultValue: "Verification code"))
                    .accessibilityHint(String(localized: "a11y.emailverification.code.hint", defaultValue: "Enter the 6-digit code from your email"))

                if let error = store.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .accessibilityLabel(error)
                        .accessibilityAddTraits(.isStaticText)
                }
                if let success = store.resendSuccessMessage {
                    Text(success)
                        .font(.caption)
                        .foregroundStyle(.green)
                        .accessibilityLabel(success)
                        .accessibilityAddTraits(.isStaticText)
                }
            }
            .padding(.horizontal)

            // MARK: - Verify button
            Button {
                store.send(.verifyTapped)
            } label: {
                Group {
                    if store.isLoading {
                        ProgressView()
                    } else {
                        Text("Verify email")
                            .fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.accentColor)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(store.isLoading || store.code.count != 6)
            .padding(.horizontal)

            // MARK: - Resend
            Button {
                store.send(.resendTapped)
            } label: {
                Group {
                    if store.isResending {
                        ProgressView()
                    } else {
                        Text("Resend code")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .disabled(store.isResending || store.isLoading)
            .accessibilityLabel(String(localized: "a11y.emailverification.resend.label", defaultValue: "Resend verification email"))
            .accessibilityHint(String(localized: "a11y.emailverification.resend.hint", defaultValue: "Sends a new verification link to your email"))

            Spacer()
        }
        .padding()
    }
}
