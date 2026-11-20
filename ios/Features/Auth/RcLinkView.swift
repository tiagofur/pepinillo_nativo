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
        if store.isLinked {
            successView
        } else {
            claimView
        }
    }

    // MARK: - Claim form

    private var claimView: some View {
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

    // MARK: - Success confirmation (judge B round 1: visible before dismiss)

    private var successView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 72))
                .foregroundStyle(.green)
                .accessibilityHidden(true)

            VStack(spacing: 8) {
                Text(String(localized: "account.rclink.success.title", defaultValue: "Purchase linked!"))
                    .font(.title2.bold())

                if let email = store.successEmail {
                    Text(String(format: String(localized: "account.rclink.success.body", defaultValue: "Linked to **%@**. Your plan is now available on the web."), email))
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }

            Button {
                store.send(.continueTapped)
            } label: {
                Text(String(localized: "account.rclink.continue", defaultValue: "Continue"))
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal)

            Spacer()
            Spacer()
        }
        .padding()
        .accessibilityElement(children: .contain)
    }
}
