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
    @Namespace private var glassNS
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
                headerSection
                modePickerSection
                formSection
                
                Spacer().frame(height: 20)
                
                actionsSection
                footerSection

                Spacer().frame(height: 24)
            }
        }
        .background {
            ZStack {
                Color.pepinilloSystemBackground.ignoresSafeArea()
                
                // Animated Liquid Background
                Circle()
                    .fill(theme.pomodoroColor.opacity(colorScheme == .dark ? 0.12 : 0.08))
                    .frame(width: 400, height: 400)
                    .blur(radius: 60)
                    .offset(x: -150, y: -200)
                
                Circle()
                    .fill(theme.pomodoroColor.opacity(colorScheme == .dark ? 0.08 : 0.05))
                    .frame(width: 300, height: 300)
                    .blur(radius: 50)
                    .offset(x: 150, y: 150)
            }
            .ignoresSafeArea()
        }
        .scrollDismissesKeyboard(.interactively)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: store.mode)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $store.scope(state: \.forgotPassword, action: \.forgotPassword)) { forgotPasswordStore in
            ForgotPasswordView(store: forgotPasswordStore)
                .pepinilloSheetStyle()
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
            .pepinilloSheetStyle()
        }
        .overlay {
            if store.isSyncing {
                ZStack {
                    Color.pepinilloSystemBackground.opacity(0.6)
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

    // MARK: - Sections

    @ViewBuilder
    private var headerSection: some View {
        ZStack {
            Circle()
                .fill(theme.pomodoroColor.opacity(0.12))
                .frame(width: 86, height: 86)
                .blur(radius: 12)

            Image(systemName: "leaf.fill")
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [theme.pomodoroColor, theme.pomodoroColor.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: theme.pomodoroColor.opacity(0.3), radius: 8, x: 0, y: 4)
                .adaptiveGlassCircle(id: "auth-icon", namespace: glassNS)
                .frame(width: 72, height: 72)
                .overlay {
                    Circle()
                        .stroke(theme.pomodoroColor.opacity(0.2), lineWidth: 1)
                }
        }
        .padding(.top, 10)
        .accessibilityHidden(true)

        VStack(spacing: 6) {
            Text(String(localized: "auth.welcome.title", defaultValue: "Welcome to Pepinillo"))
                .font(.system(.title2, design: .rounded).weight(.bold))
                .foregroundStyle(.primary)

            Text(String(localized: "auth.welcome.subtitle", defaultValue: "Sign in and start your next deep work session."))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 40)
        .padding(.top, 16)

        Spacer().frame(height: 24)
    }

    @ViewBuilder
    private var modePickerSection: some View {
        HStack(spacing: 0) {
            modeButton(title: String(localized: "auth.mode.signin", defaultValue: "Sign In"), mode: .login)
            modeButton(title: String(localized: "auth.mode.register", defaultValue: "Create Account"), mode: .register)
        }
        .padding(4)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay {
                    Capsule().stroke(.primary.opacity(0.08), lineWidth: 1)
                }
        )
        .padding(.horizontal, 24)
        .padding(.vertical, 10)
    }

    private func modeButton(title: String, mode: AuthFeature.AuthMode) -> some View {
        let isSelected = store.mode == mode
        return Button {
            store.send(.switchMode(mode))
        } label: {
            Text(title)
                .font(.subheadline.weight(isSelected ? .bold : .medium))
                .foregroundStyle(isSelected ? .primary : .secondary)
                .frame(maxWidth: .infinity)
                .frame(height: 36)
                .background {
                    if isSelected {
                        Capsule()
                            .fill(.primary.opacity(colorScheme == .dark ? 0.15 : 0.08))
                            .matchedGeometryEffect(id: "mode-pill", in: glassNS)
                    }
                }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var formSection: some View {
        Spacer().frame(height: 14)

        VStack(spacing: 14) {
            if store.mode == .register {
                AuthField(
                    icon: "person.fill",
                    placeholder: String(localized: "auth.field.name", defaultValue: "Name"),
                    text: Binding(get: { store.name }, set: { store.send(.nameChanged($0)) })
                )
                #if os(iOS)
                .textContentType(.name)
                #endif
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            AuthField(
                icon: "envelope.fill",
                placeholder: String(localized: "auth.field.email", defaultValue: "Email"),
                text: Binding(get: { store.email }, set: { store.send(.emailChanged($0)) })
            )
            #if os(iOS)
            .textContentType(.emailAddress)
            .keyboardType(.emailAddress)
            #endif

            AuthField(
                icon: "lock.fill",
                placeholder: String(localized: "auth.field.password", defaultValue: "Password"),
                text: Binding(get: { store.password }, set: { store.send(.passwordChanged($0)) }),
                isSecure: !store.isPasswordVisible,
                trailingIcon: store.isPasswordVisible ? "eye.slash" : "eye",
                onTrailingIconTap: { store.send(.togglePasswordVisibility) }
            )
            #if os(iOS)
            .textContentType(store.mode == .register ? .newPassword : .password)
            #endif

            if store.mode == .register {
                Text(String(localized: "auth.password.hint", defaultValue: "Use at least 8 characters, with uppercase, lowercase, and a number."))
                    .font(.caption2)
                    .foregroundStyle(.secondary.opacity(0.8))
                    .padding(.horizontal, 4)
                    .transition(.opacity)
            }
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
    }

    @ViewBuilder
    private var actionsSection: some View {
        Button {
            if store.mode == .login {
                store.send(.loginTapped)
            } else {
                store.send(.registerTapped)
            }
        } label: {
            Text(store.mode == .login
                ? String(localized: "auth.mode.signin", defaultValue: "Sign In")
                : String(localized: "auth.mode.register", defaultValue: "Create Account")
            )
            .font(.subheadline.weight(.bold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(
                theme.pomodoroColor.gradient,
                in: Capsule()
            )
            .shadow(color: theme.pomodoroColor.opacity(0.35), radius: 12, y: 6)
        }
        .buttonStyle(PepinilloButtonStyle())
        .disabled(store.isLoading)
        .padding(.horizontal, 24)
        .contentShape(Capsule())
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

                appleSignInButton
            }
            .transition(.asymmetric(
                insertion: .move(edge: .top).combined(with: .opacity),
                removal: .opacity
            ))
        }
    }

    private var appleSignInButton: some View {
        ZStack {
            HStack(spacing: 8) {
                Image(systemName: "apple.logo")
                    .font(.subheadline.weight(.semibold))
                Text(String(localized: "Continue with Apple"))
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .adaptiveGlassCapsule(id: "apple-auth-pills", namespace: glassNS)
            .overlay {
                Capsule()
                    .stroke(.secondary.opacity(colorScheme == .dark ? 0.25 : 0.15), lineWidth: 1)
            }
            .allowsHitTesting(false)

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
            .signInWithAppleButtonStyle(colorScheme == .dark ? .black : .white)
            .opacity(0.015)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
        }
        .contentShape(Capsule())
        .padding(.horizontal, 24)
    }

    @ViewBuilder
    private var footerSection: some View {
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
    }
}
