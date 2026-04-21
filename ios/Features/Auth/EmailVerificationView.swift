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
                    .foregroundStyle(.accent)

                Text("Check your inbox")
                    .font(.title2.bold())

                Text("We sent a 6-digit code to\n**\(store.email)**")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            // MARK: - Code field
            VStack(spacing: 12) {
                TextField("123456", text: $store.code.sending(\.codeChanged))
                    .keyboardType(.numberPad)
                    .font(.title.monospacedDigit())
                    .multilineTextAlignment(.center)
                    .padding()
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))

                if let error = store.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
                if let success = store.resendSuccessMessage {
                    Text(success)
                        .font(.caption)
                        .foregroundStyle(.green)
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
                .background(.accent)
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

            Spacer()
        }
        .padding()
    }
}
