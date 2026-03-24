// AuthView.swift
// Pepinillo — Deep Work Companion for Apple
//
// Login + Register combined SwiftUI view.
// Toggles between sign-in and account creation modes.

import SwiftUI
import ComposableArchitecture

struct AuthView: View {
    @Bindable var store: StoreOf<AuthFeature>

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // MARK: Header
            Text("Pepinillo")
                .font(.largeTitle.bold())
                .foregroundStyle(.primary)

            Text("Your deep work companion")
                .font(.body)
                .foregroundStyle(.secondary)
                .padding(.top, 4)

            Spacer().frame(height: 48)

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
            .disabled(store.isLoading)
            .padding(.horizontal, 24)

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

            Spacer()
        }
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
}
