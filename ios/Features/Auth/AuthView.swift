// AuthView.swift
// Pepinillo — Deep Work Companion for Apple
//
// Login + Register combined SwiftUI view.
// Toggles between sign-in and account creation modes.

import SwiftUI
import AuthenticationServices
import ComposableArchitecture

struct AuthView: View {
    @Bindable var store: StoreOf<AuthFeature>
    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    let onAppleSignIn: ((AppleUserInfo) -> Void)?
    let onAppleSignInFailed: (() -> Void)?

    init(
        store: StoreOf<AuthFeature>,
        onAppleSignIn: ((AppleUserInfo) -> Void)? = nil,
        onAppleSignInFailed: (() -> Void)? = nil
    ) {
        self.store = store
        self.onAppleSignIn = onAppleSignIn
        self.onAppleSignInFailed = onAppleSignInFailed
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                Spacer().frame(height: 24)

                // MARK: Header
                ZStack {
                    Circle()
                        .fill(theme.pomodoroColor.opacity(colorScheme == .dark ? 0.24 : 0.14))
                        .frame(width: 70, height: 70)

                    Image(systemName: "leaf.fill")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(theme.pomodoroColor)
                }

                Text("Pepinillo")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .padding(.top, 14)

                Text("Your deep work companion")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)

                Spacer().frame(height: 32)

            // MARK: Fields
                VStack(spacing: 12) {
                    if store.mode == .register {
                        TextField(
                            "Name",
                            text: Binding(
                                get: { store.name },
                                set: { store.send(.nameChanged($0)) }
                            )
                        )
                        .textContentType(.name)
                        .textFieldStyle(.roundedBorder)
                    }

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

                    // Password with visibility toggle
                    HStack {
                        Group {
                            if store.isPasswordVisible {
                                TextField(
                                    "Password",
                                    text: Binding(
                                        get: { store.password },
                                        set: { store.send(.passwordChanged($0)) }
                                    )
                                )
                                .textContentType(store.mode == .register ? .newPassword : .password)
                            } else {
                                SecureField(
                                    "Password",
                                    text: Binding(
                                        get: { store.password },
                                        set: { store.send(.passwordChanged($0)) }
                                    )
                                )
                                .textContentType(store.mode == .register ? .newPassword : .password)
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

                    if store.mode == .register {
                        Text("Min 8 chars, with uppercase, lowercase, and a number")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.leading, 4)
                    }
                }
                .padding(18)
                .background {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .overlay {
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
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
                    if store.mode == .login {
                        store.send(.loginTapped)
                    } else {
                        store.send(.registerTapped)
                    }
                } label: {
                    Group {
                        if store.isLoading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text(store.mode == .login ? "Sign In" : "Create Account")
                        }
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                }
                .buttonStyle(.borderedProminent)
                .tint(primaryCTAColor)
                .disabled(store.isLoading)
                .padding(.horizontal, 24)
                .shadow(color: primaryCTAColor.opacity(0.24), radius: 12, x: 0, y: 8)

                if store.mode == .login, onAppleSignIn != nil {
                    VStack(spacing: 8) {
                        HStack(spacing: 10) {
                            Rectangle()
                                .fill(Color.secondary.opacity(0.25))
                                .frame(height: 1)
                            Text("or")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                            Rectangle()
                                .fill(Color.secondary.opacity(0.25))
                                .frame(height: 1)
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 12)

                        SignInWithAppleButton(.continue) { request in
                            request.requestedScopes = [.fullName, .email]
                        } onCompletion: { result in
                            switch result {
                            case .success(let auth):
                                guard let cred = auth.credential as? ASAuthorizationAppleIDCredential else {
                                    onAppleSignInFailed?()
                                    return
                                }
                                let identityToken: String? = cred.identityToken.flatMap { String(data: $0, encoding: .utf8) }
                                onAppleSignIn?(AppleUserInfo(
                                    userID: cred.user,
                                    displayName: cred.fullName?.formatted(),
                                    email: cred.email,
                                    identityToken: identityToken
                                ))
                            case .failure:
                                onAppleSignInFailed?()
                            }
                        }
                        .signInWithAppleButtonStyle(.black)
                        .frame(height: 52)
                        .padding(.horizontal, 24)
                        .padding(.top, 8)
                    }
                    .transition(.asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .opacity
                    ))
                }

                // MARK: Forgot Password (login mode only)
                if store.mode == .login {
                    Button("Forgot your password?") {
                        store.send(.forgotPasswordTapped)
                    }
                    .foregroundStyle(.secondary)
                    .font(.footnote)
                    .padding(.top, 8)
                }

                // MARK: Switch Mode
                Button {
                    store.send(.switchMode(store.mode == .login ? .register : .login))
                } label: {
                    Text(store.mode == .login
                        ? "Don't have an account? Sign up"
                        : "Already have an account? Sign in")
                        .font(.subheadline)
                }
                .padding(.top, 12)

                // MARK: Guest Mode
                Button {
                    store.send(.continueAsGuestTapped)
                } label: {
                    Text("Continue without account")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 8)

                Spacer().frame(height: 20)
            }
        }
        .background {
            LinearGradient(
                colors: [
                    theme.pomodoroColor.opacity(colorScheme == .dark ? 0.18 : 0.08),
                    Color.clear,
                ],
                startPoint: .top,
                endPoint: .center
            )
            .ignoresSafeArea()
        }
        .animation(.spring(response: 0.34, dampingFraction: 0.86), value: store.mode)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $store.scope(state: \.forgotPassword, action: \.forgotPassword)) { forgotPasswordStore in
            ForgotPasswordView(store: forgotPasswordStore)
        }
        .sheet(isPresented: Binding(
            get: { store.showMergeDialog },
            set: { _ in store.send(.dismissMergeDialog) }
        )) {
            DataMergeView(
                onMerge: { store.send(.mergeTapped) },
                onUseAccountOnly: { store.send(.useAccountOnlyTapped) }
            )
            .presentationDetents([.medium])
        }
        .overlay {
            if store.isSyncing {
                ZStack {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Syncing your data...")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(32)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                }
            }
        }
    }

    private var primaryCTAColor: Color {
        colorScheme == .light ? .black : theme.pomodoroColor
    }
}
