// MacServicesProvider.swift
// Pepinillo — native macOS Services integration
//
// Registers an "Add Task to Pepinillo" service so selected text in any app
// (Safari, Notes, Mail…) becomes a Pepinillo task from the app's Services
// submenu. The entry point is declared in `NSServices` (Mac/Info.plist).

import AppKit
import ComposableArchitecture

@MainActor
final class MacServicesProvider: NSObject {
    private let store: StoreOf<AppFeature>

    init(store: StoreOf<AppFeature>) {
        self.store = store
    }

    /// Selector shape required by `NSServices` (`NSMessage` = `addTask`).
    /// Services deliver the selection on the main thread.
    @objc func addTask(
        _ pasteboard: NSPasteboard,
        userData: String,
        error: AutoreleasingUnsafeMutablePointer<NSString>
    ) {
        let candidates = pasteboard.readObjects(forClasses: [NSString.self]) as? [String] ?? []

        // Collapse multi-line selections into a single-line task title.
        let normalized = (candidates.first ?? "")
            .replacingOccurrences(of: "\r\n", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !normalized.isEmpty else { return }
        let bounded = String(normalized.prefix(200))

        store.send(.tabSelected(.plan))
        store.send(.tasks(.newTaskTitleChanged(bounded)))
        store.send(.tasks(.addTaskTapped))
    }
}
