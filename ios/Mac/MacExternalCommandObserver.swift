// MacExternalCommandObserver.swift
// Pepinillo — live widget/Siri/Control Center command bridge for macOS
//
// WidgetKit buttons, Siri intents, and Control Center toggles run in their
// extension processes and never open the app. On iOS the commands are consumed
// when the app becomes active again; on macOS the app regularly lives in the
// background (menu bar, closed window) for a whole session, so those commands
// would sit unconsumed until someone focuses the window.
//
// External surfaces post the `com.pepinillo.app.externalCommand` Darwin
// notification whenever they change command flags (posted from the
// `AppGroupDefaults` setters). This observer forwards each signal into
// `AppFeature.consumeExternalCommands` on the main actor, so widget taps
// control the running app instantly — and the app's own re-publish (anchors +
// WidgetCenter reloads) flows back to the widget the same moment.

import AppKit
import ComposableArchitecture
import OSLog

private let macExternalCommandLogger = Logger(
    subsystem: "com.pepinillo.app",
    category: "mac-external-commands"
)

@MainActor
final class MacExternalCommandObserver {
    private var store: StoreOf<AppFeature>?

    func install(store: StoreOf<AppFeature>) {
        self.store = store

        // The C callback cannot capture context; the observer pointer carries
        // `self` back out. The observer is retained by this Mac-side installer
        // for the lifetime of the store, so unretained is safe.
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        let raw = Unmanaged.passUnretained(self).toOpaque()
        CFNotificationCenterAddObserver(
            center,
            raw,
            { _, observer, _, _, _ in
                guard let observer else { return }
                let instance = Unmanaged<MacExternalCommandObserver>
                    .fromOpaque(observer)
                    .takeUnretainedValue()
                instance.signalReceived()
            },
            AppGroupDefaults.externalCommandDarwinNotification as CFString,
            nil,
            .deliverImmediately
        )
        macExternalCommandLogger.debug(
            "External command observer installed (\(AppGroupDefaults.externalCommandDarwinNotification, privacy: .public))"
        )
    }

    /// Darwin callbacks arrive on an arbitrary queue; hop to the main actor
    /// before touching the store. Refresh the suite cache first — the signal
    /// can beat the local cfprefsd cache update, and consuming stale flags
    /// would drop the command that triggered the wake-up.
    nonisolated private func signalReceived() {
        Task { @MainActor in
            macExternalCommandLogger.info("External command signal received")
            AppGroupDefaults.refreshFromOtherProcesses()
            self.consume()
        }
    }

    private func consume() {
        guard let store else { return }
        store.send(.consumeExternalCommands)
    }
}
