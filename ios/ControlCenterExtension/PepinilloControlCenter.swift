// PepinilloControlCenter.swift
// Pepinillo — Deep Work Companion for Apple
//
// Control Center widget (iOS 18+).
// A single toggle button that starts/stops the active focus session.
// Shows the current mode icon and remaining time when active.
//
// REQUIREMENTS (Xcode setup):
//   1. Create a new target: Control Center Extension
//   2. Add to the app's App Group: "group.com.pepinillo.app"
//   3. iOS 18.0+ deployment target

import WidgetKit
import SwiftUI

// MARK: - Control Center Toggle

@available(iOS 18.0, *)
struct PepinilloFocusToggle: ControlWidget {
    static let kind = "com.pepinillo.control-center.focus-toggle"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetToggle(
                String(localized: "Focus"),
                isOn: FocusToggleValueProvider.shared.isActive,
                action: ToggleFocusIntent()
            ) { isOn in
                Label {
                    Text(isOn ? String(localized: "Focusing") : String(localized: "Start Focus"))
                } icon: {
                    Image(systemName: isOn ? "brain.head.profile.fill" : "brain.head.profile")
                }
            }
            .tint(.purple)
        }
        .displayName(String(localized: "Pepinillo Focus"))
        .description(String(localized: "Start or stop a focus session."))
    }
}

// MARK: - Toggle Value Provider

@available(iOS 18.0, *)
struct FocusToggleValueProvider {
    static let shared = FocusToggleValueProvider()

    /// Reads whether a session is currently active from the App Group UserDefaults.
    var isActive: Bool {
        let defaults = UserDefaults(suiteName: AppGroup.id)
        return defaults?.bool(forKey: "isSessionActive") ?? false
    }
}

// MARK: - Toggle Intent

@available(iOS 18.0, *)
struct ToggleFocusIntent: ControlWidgetToggleIntent {
    static var title: LocalizedStringResource = "Toggle Focus Session"

    func perform(value: Bool) async throws {
        // Write the desired state to App Group UserDefaults.
        // The main app observes this key and starts/stops the session accordingly.
        let defaults = UserDefaults(suiteName: AppGroup.id)
        defaults?.set(value, forKey: "controlCenterToggleRequested")
        defaults?.set(value, forKey: "isSessionActive")

        // Reload the Control Center widget to reflect the new state
        ControlCenter.shared.reloadControls(ofKind: PepinilloFocusToggle.kind)
    }
}

// MARK: - Control Center Bundle

@available(iOS 18.0, *)
@main
struct PepinilloControlCenterBundle: WidgetBundle {
    var body: some Widget {
        PepinilloFocusToggle()
    }
}
