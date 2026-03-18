// FocusFilterIntent.swift
// Pepinillo — Deep Work Companion for Apple
//
// Implements SetFocusFilterIntent so the system Focus Modes (Do Not Disturb, Work, etc.)
// can interact with Pepinillo. When a user configures a system Focus Mode to include
// Pepinillo, they can set which focus technique should auto-start.
//
// REQUIREMENTS (Xcode setup):
//   1. Add the "Focus Filter" capability to the PepinilloIntents target
//   2. Entitlement: com.apple.developer.focus-filter
//   3. Register the intent in PepinilloApp.swift

import AppIntents
import Foundation

/// The Focus Filter configuration that appears in Settings > Focus > [Focus Mode] > Pepinillo.
struct PepinilloFocusFilter: SetFocusFilterIntent {

    static let title: LocalizedStringResource = "Pepinillo Focus"

    static let description = IntentDescription(
        "Configure how Pepinillo behaves during this Focus Mode.",
        categoryName: "Focus"
    )

    /// The focus mode to activate when this system Focus activates.
    @Parameter(title: "Focus Technique")
    var focusMode: FocusModeEntity?

    /// Optional: auto-start a session when this Focus activates.
    @Parameter(title: "Auto-start session", default: false)
    var autoStart: Bool

    /// Display representation shown in the Focus configuration UI.
    var displayRepresentation: DisplayRepresentation {
        let modeName = focusMode?.displayName ?? "Focus"
        return DisplayRepresentation(
            title: "Pepinillo: \(modeName)",
            subtitle: autoStart
                ? "Auto-starts a \(modeName) session"
                : "Sets mode to \(modeName)"
        )
    }

    /// Called by the system when the Focus Mode activates or deactivates.
    func perform() async throws -> some IntentResult {
        if let modeID = focusMode?.id {
            AppGroupDefaults.requestedMode = modeID
        }

        if autoStart {
            AppGroupDefaults.externalStartRequested = true
        }

        return .result()
    }
}
