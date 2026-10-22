// MacSettingsView.swift
// Pepinillo — native macOS settings and app-level preferences

import AppKit
import ComposableArchitecture
import ServiceManagement
import SwiftUI

// MARK: - App-level preferences

/// Preferences that belong to the macOS shell rather than the shared product
/// settings feature: launch at login and Dock visibility.
@MainActor
final class MacPreferences: ObservableObject {
    @Published private(set) var launchAtLogin: Bool
    @Published private(set) var showInDock: Bool
    @Published private(set) var errorMessage: String?

    private var isApplying = false

    private enum Keys {
        static let launchAtLogin = "mac.launchAtLogin"
        static let showInDock = "mac.showInDock"
    }

    init() {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: Keys.showInDock) == nil {
            defaults.set(true, forKey: Keys.showInDock)
        }

        launchAtLogin = SMAppService.mainApp.status == .enabled
        showInDock = defaults.bool(forKey: Keys.showInDock)
        applyDockPolicy()
    }

    func setLaunchAtLogin(_ value: Bool) {
        guard value != launchAtLogin else { return }
        launchAtLogin = value
        UserDefaults.standard.set(value, forKey: Keys.launchAtLogin)
        applyLaunchAtLogin()
    }

    func setShowInDock(_ value: Bool) {
        guard value != showInDock else { return }
        showInDock = value
        UserDefaults.standard.set(value, forKey: Keys.showInDock)
        applyDockPolicy()
    }

    func applyDockPolicy() {
        NSApp.setActivationPolicy(showInDock ? .regular : .accessory)
    }

    private func applyLaunchAtLogin() {
        guard !isApplying else { return }
        isApplying = true
        defer { isApplying = false }

        do {
            if launchAtLogin {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
            // Keep the toggle aligned with the real system state.
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}

// MARK: - Settings window

struct MacSettingsView: View {
    @Bindable var store: StoreOf<AppFeature>
    @ObservedObject var preferences: MacPreferences

    private var activeTheme: AppTheme {
        AppTheme.named(store.settings.themeName)
    }

    private var preferredColorScheme: ColorScheme? {
        switch store.settings.appearanceMode {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }

    var body: some View {
        TabView {
            general
                .tabItem { Label("General", systemImage: "gearshape") }

            appearance
                .tabItem { Label("Appearance", systemImage: "paintpalette") }
        }
        .frame(width: 480, height: 300)
        .environment(\.appTheme, activeTheme)
        .preferredColorScheme(preferredColorScheme)
        .onAppear {
            store.send(.settings(.onAppear))
        }
    }

    private var general: some View {
        Form {
            Section {
                Toggle(
                    "Launch at login",
                    isOn: Binding(
                        get: { preferences.launchAtLogin },
                        set: { preferences.setLaunchAtLogin($0) }
                    )
                )

                Toggle(
                    "Show in Dock",
                    isOn: Binding(
                        get: { preferences.showInDock },
                        set: { preferences.setShowInDock($0) }
                    )
                )
            } footer: {
                if let error = preferences.errorMessage {
                    Text(error)
                        .foregroundStyle(.red)
                } else {
                    Text("Pepinillo stays available from the menu bar when the Dock icon is hidden.")
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                LabeledContent("Global shortcut", value: "⌃⌥Space")
            } footer: {
                Text("Starts or pauses the focus timer from anywhere.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private var appearance: some View {
        Form {
            Picker(
                "Theme",
                selection: Binding(
                    get: { store.settings.themeName },
                    set: { store.send(.settings(.themeChanged($0))) }
                )
            ) {
                ForEach(AppTheme.all, id: \.name) { theme in
                    Text(theme.displayName).tag(theme.name)
                }
            }

            Picker(
                "Appearance",
                selection: Binding(
                    get: { store.settings.appearanceMode },
                    set: { store.send(.settings(.appearanceModeChanged($0))) }
                )
            ) {
                Text("System").tag("system")
                Text("Light").tag("light")
                Text("Dark").tag("dark")
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}
