// MacGlobalHotKey.swift
// Pepinillo — native macOS global shortcut

import Carbon
import Foundation

/// Registers one system-wide hotkey (`⌃⌥Space`) that toggles the focus timer.
///
/// Carbon is used instead of `NSEvent.addGlobalMonitorForEvents` because global
/// key monitors require Accessibility permission, while `RegisterEventHotKey`
/// works in a sandboxed app without prompting.
@MainActor
final class MacGlobalHotKey {
    static let shared = MacGlobalHotKey()

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private var isRegistered = false
    private var action: (@MainActor () -> Void)?

    private init() {}

    /// Installs or updates the action and registers the hotkey once.
    func configure(action: @escaping @MainActor () -> Void) {
        self.action = action
        registerIfNeeded()
    }

    func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
            self.eventHandlerRef = nil
        }
        isRegistered = false
    }

    private func registerIfNeeded() {
        guard !isRegistered else { return }

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let handlerStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            macGlobalHotKeyHandler,
            1,
            &eventType,
            nil,
            &eventHandlerRef
        )
        guard handlerStatus == noErr else { return }

        let hotKeyID = EventHotKeyID(signature: OSType(0x5045504E), id: 1)
        let registerStatus = RegisterEventHotKey(
            UInt32(kVK_Space),
            UInt32(controlKey | optionKey),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        guard registerStatus == noErr else {
            if let eventHandlerRef {
                RemoveEventHandler(eventHandlerRef)
                self.eventHandlerRef = nil
            }
            return
        }

        isRegistered = true
    }

    fileprivate func handle() {
        action?()
    }
}

/// Carbon invokes this on the main thread. The `Task` hop keeps the callback
/// free of captured actor-isolated state.
private let macGlobalHotKeyHandler: EventHandlerUPP = { _, _, _ in
    Task { @MainActor in
        MacGlobalHotKey.shared.handle()
    }
    return noErr
}
