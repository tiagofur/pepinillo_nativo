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
import AppIntents

// MARK: - Control Center Toggle

@available(iOS 18.0, *)
struct PepinilloFocusToggle: ControlWidget {
    static let kind = "com.pepinillo.control-center.focus-toggle"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetToggle(
                "Focus",
                isOn: FocusToggleValueProvider.shared.isActive,
                action: ToggleFocusIntent()
            ) { isOn in
                Label {
                    Text(isOn
                        ? String(localized: "controlcenter.focusing.label", defaultValue: "Focusing")
                        : String(localized: "controlcenter.startfocus.label", defaultValue: "Start Focus"))
                } icon: {
                    Image(systemName: isOn ? "brain.head.profile.fill" : "brain.head.profile")
                }
            }
            .tint(.purple)
        }
        // Keep brand name "Pepinillo Focus" as-is; localize only the description
        .displayName("Pepinillo Focus")
        .description(LocalizedStringResource("controlcenter.description", defaultValue: "Start or stop a focus session."))
    }
}

// MARK: - Toggle Value Provider

@available(iOS 18.0, *)
struct FocusToggleValueProvider {
    static let shared = FocusToggleValueProvider()

    /// Reads whether a session is currently active from the App Group.
    var isActive: Bool {
        AppGroupDefaults.isSessionActive
    }
}

// MARK: - Toggle Intent

@available(iOS 18.0, *)
struct ToggleFocusIntent: SetValueIntent {
    static let title: LocalizedStringResource = "Toggle Focus Session"

    @Parameter(title: "Is On")
    var value: Bool

    @MainActor
    func perform() async throws -> some IntentResult {
        if value {
            // Start session optimistically.
            // Use the last selected mode or default to pomodoro.
            // Pro modes (flowtime, timeBlock) fall back to pomodoro for free users.
            let requested = AppGroupDefaults.widgetSelectedMode ?? "pomodoro"
            let mode = widgetResolvedMode(requested: requested, isPro: AppGroupDefaults.isProUser)
            if mode == requested {
                // No downgrade: proceed (Pro user, or free user with a free mode).
                AppGroupDefaults.startWidgetSession(modeID: mode)
            } else {
                // Downgrade: a free user picked a Pro mode. Do NOT overwrite their
                // selection with pomodoro — route through the app paywall instead,
                // mirroring StartFocusFromWidgetIntent so CC and the widget grid stay
                // consistent. This preserves `widgetSelectedMode` for when they upgrade.
                AppGroupDefaults.externalCommandID = UUID().uuidString
                AppGroupDefaults.externalCommandIssuedAt = .now
                AppGroupDefaults.requestedMode = requested
                AppGroupDefaults.requestedTaskID = nil
                AppGroupDefaults.externalStartRequested = true
            }
        } else {
            // Stop current session — mirror StopFocusFromWidgetIntent exactly.
            AppGroupDefaults.externalCommandID = UUID().uuidString
            AppGroupDefaults.externalCommandIssuedAt = .now
            AppGroupDefaults.externalStopRequested = true
            AppGroupDefaults.clearActiveSession()
        }

        // Reload the Control Center widget and Home Screen widgets to reflect the state
        ControlCenter.shared.reloadControls(ofKind: PepinilloFocusToggle.kind)
        WidgetCenter.shared.reloadAllTimelines()
        
        return .result()
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
