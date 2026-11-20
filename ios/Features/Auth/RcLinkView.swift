// RcLinkView.swift
// Pepinillo — Deep Work Companion for Apple
//
// Sheet for the #953 license bridge (mirror of EmailVerificationView):
// enter the single-use 6-digit code shown on app.pepinillo.app/account to
// bring a native store purchase to the web account. Canonical entry-point
// label (fixed in the PR-2 dual review): "Use my purchase on the Web".

import SwiftUI
import ComposableArchitecture

struct RcLinkView: View {
    @Bindable var store: StoreOf<RcLinkFeature>

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // MARK: - Icon + heading
            VStack(spacing: 16) {
                Image(systemName: "link.icloud")
                    .font(.system(size: 64))
                    .foregroundStyle(Color.accentColor)
                    .accessibilityHidden(true)

                Text(String(localized: "account.rclink.title", defaultValue: "Bring your purchase to the web"))
                    .font(.title2.bold())

                Text(String(localized: "account.rclink.explanation", defaultValue: "Bought Pepinillo+ or Everywhere in the iOS, macOS, or Android app? Enter the 6-digit code shown on app.pepinillo.app (Account) to bring your purchase to your web account."))
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
                    .accessibilityLabel(String(localized: "a11y.rclink.code.label", defaultValue: "Link code"))
                    .accessibilityHint(String(localized: "a11y.rclink.code.hint", defaultValue: "Enter the 6-digit code from the web account page"))

                if let error = store.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .accessibilityLabel(error)
                        .accessibilityAddTraits(.isStaticText)
                }
            }
            .padding(.horizontal)

            // MARK: - Claim button
            Button {
                store.send(.claimTapped)
            } label: {
                Group {
                    if store.isLoading {
                        ProgressView()
                    } else {
                        Text(String(localized: "account.rclink.claim.button", defaultValue: "Link purchase"))
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

            Spacer()
            Spacer()
        }
        .padding()
    }
}
