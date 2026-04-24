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
    @State private var currentNonce: String = ""

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
                Spacer().frame(height: 20)

                ZStack {
                    Circle()
                        .fill(theme.pomodoroColor.opacity(colorScheme == .dark ? 0.26 : 0.16))
                        .frame(width: 72, height: 72)

                    Image(systemName: "leaf.fill")
                        .font(.system(size: 29, weight: .semibold))
                        .foregroundStyle(theme.pomodoroColor)
                }
                .accessibilityHidden(true)

                Text(String(localized: "auth.welcome.title", defaultValue: "Welcome to Pepinillo"))
                    .font(.system(.title, design: .rounded).weight(.bold))
                    .foregroundStyle(.primary)
                    .padding(.top, 14)

                Text(String(localized: "auth.welcome.subtitle", defaultValue: "Sign in and start your next deep work session."))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)

                Spacer().frame(height: 20)

                Picker(String(localized: "auth.mode.picker", defaultValue: "Authentication Mode"), selection: Binding(
                    get: { store.mode },
                    set: { store.send(.switchMode($0)) }
                )) {
                    Text(String(localized: "auth.mode.signin", defaultValue: "Sign In")).tag(AuthFeature.AuthMode.login)
                    Text(String(localized: "auth.mode.register", defaultValue: "Create Account")).tag(AuthFeature.AuthMode.register)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 24)
                .accessibilityLabel(String(localized: "a11y.auth.mode.label", defaultValue: "Authentication mode"))
                .accessibilityValue(store.mode == .login
                    ? String(localized: "auth.mode.signin", defaultValue: "Sign In")
                    : String(localized: "auth.mode.register", defaultValue: "Create Account")
                )

                Spacer().frame(height: 14)

                VStack(spacing: 12) {
                    if store.mode == .register {
                        TextField(
                            String(localized: "auth.field.name", defaultValue: "Name"),
                            text: Binding(
                                get: { store.name },
                                set: { store.send(.nameChanged($0)) }
                            )
                        )
                        .textContentType(.name)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityLabel(String(localized: "a11y.auth.field.name.label", defaultValue: "Name"))
                    }

                    TextField(
                        String(localized: "auth.field.email", defaultValue: "Email"),
                        text: Binding(
                            get: { store.email },
                            set: { store.send(.emailChanged($0)) }
                        )
                    )
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel(String(localized: "a11y.auth.field.email.label", defaultValue: "Email address"))

                    HStack(spacing: 10) {
                        Group {
                            if store.isPasswordVisible {
                                TextField(
                                    String(localized: "auth.field.password", defaultValue: "Password"),
                                    text: Binding(
                                        get: { store.password },
                                        set: { store.send(.passwordChanged($0)) }
                                    )
                                )
                                .textContentType(store.mode == .register ? .newPassword : .password)
                            } else {
                                SecureField(
                                    String(localized: "auth.field.password", defaultValue: "Password"),
                                    text: Binding(
                                        get: { store.password },
                                        set: { store.send(.passwordChanged($0)) }
                                    )
                                )
                                .textContentType(store.mode == .register ? .newPassword : .password)
                            }
                        }
                        .accessibilityLabel(String(localized: "a11y.auth.field.password.label", defaultValue: "Password"))
                        .accessibilityHint(store.mode == .register
                            ? String(localized: "a11y.auth.field.password.hint.register", defaultValue: "Must be at least 8 characters with uppercase, lowercase, and a number")
                            : String(localized: "a11y.auth.field.password.hint.login", defaultValue: "Enter your account password")
                        )

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

                    if store.mode == .register {
                        Text(String(localized: "auth.password.hint", defaultValue: "Use at least 8 characters, with uppercase, lowercase, and a number."))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .accessibilityHidden(true)
                    }
                }
                .padding(18)
                .pepinilloGlass(cornerRadius: GlassCornerRadius.card)
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(theme.pomodoroColor.opacity(colorScheme == .dark ? 0.22 : 0.16), lineWidth: 1)
                }
                .padding(.horizontal, 24)

                if let error = store.errorMessage {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .padding(.horizontal, 24)
                        .padding(.top, 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityLabel(error)
                        .accessibilityAddTraits(.isStaticText)
                }

                Spacer().frame(height: 20)

                Button {
                    if store.mode == .login {
                        store.send(.loginTapped)
                    } else {
                        store.send(.registerTapped)
                    }
                } label: {
                    HStack(spacing: 8) {
                        if store.isLoading {
                            ProgressView()
                                .tint(.white)
                                .accessibilityHidden(true)
                        }
                        Text(store.mode == .login ? String(localized: "auth.mode.signin", defaultValue: "Sign In") : String(localized: "auth.mode.register", defaultValue: "Create Account"))
                    }
                    .font(.callout.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                }
                .buttonStyle(.borderedProminent)
                .tint(theme.pomodoroColor)
                .disabled(store.isLoading)
                .padding(.horizontal, 24)
                .accessibilityLabel(store.mode == .login
                    ? String(localized: "auth.mode.signin", defaultValue: "Sign In")
                    : String(localized: "auth.mode.register", defaultValue: "Create Account")
                )

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
                        .accessibilityHidden(true)

                        SignInWithAppleButton(.continue) { request in
                            let nonce = AppleAuthHelper.generateNonce()
                            currentNonce = nonce
                            request.nonce = AppleAuthHelper.sha256Hex(nonce)
                            request.requestedScopes = [.fullName, .email]
                        } onCompletion: { result in
                            switch result {
                            case .success(let auth):
                                guard let cred = auth.credential as? ASAuthorizationAppleIDCredential else {
                                    onAppleSignInFailed?()
                                    return
                                }
                                guard !currentNonce.isEmpty else {
                                    onAppleSignInFailed?()
                                    return
                                }
                                let identityToken: String? = cred.identityToken.flatMap { String(data: $0, encoding: .utf8) }
                                onAppleSignIn?(AppleUserInfo(
                                    userID: cred.user,
                                    displayName: cred.fullName?.formatted(),
                                    email: cred.email,
                                    identityToken: identityToken,
                                    nonce: currentNonce
                                ))
                            case .failure:
                                onAppleSignInFailed?()
                            }
                        }
                        .signInWithAppleButtonStyle(.whiteOutline)
                        .frame(height: 46)
                        .padding(.horizontal, 24)
                    }
                    .transition(.asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .opacity
                    ))
                }

                if store.mode == .login {
                    Button(String(localized: "auth.forgotpassword.button", defaultValue: "Forgot your password?")) {
                        store.send(.forgotPasswordTapped)
                    }
                    .foregroundStyle(.secondary)
                    .font(.footnote)
                    .padding(.top, 10)
                    .accessibilityHint(String(localized: "a11y.auth.forgotpassword.hint", defaultValue: "Opens password recovery"))
                }

                Button {
                    store.send(.continueAsGuestTapped)
                } label: {
                    Text(String(localized: "auth.guest.button", defaultValue: "Continue without account"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 12)
                .accessibilityHint(String(localized: "a11y.auth.guest.hint", defaultValue: "Continue without signing in — data stays on this device"))

                Spacer().frame(height: 24)
            }
        }
        .background {
            LinearGradient(
                colors: [
                    theme.pomodoroColor.opacity(colorScheme == .dark ? 0.18 : 0.10),
                    Color.clear,
                ],
                startPoint: .top,
                endPoint: .center
            )
            .ignoresSafeArea()
        }
        .scrollDismissesKeyboard(.interactively)
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
                    Color(.systemBackground).opacity(0.6)
                        .ignoresSafeArea()
                        .accessibilityHidden(true)
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .accessibilityHidden(true)
                        Text("Syncing your data...")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(32)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(String(localized: "a11y.auth.syncing.label", defaultValue: "Syncing your account"))
                    .accessibilityAddTraits(.updatesFrequently)
                }
            }
        }
    }

}
