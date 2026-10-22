// MacGlobalHotKey.swift
// Pepinillo — native macOS global shortcuts

import Carbon
import Foundation

/// Registers system-wide hotkeys (Carbon `RegisterEventHotKey`) and dispatches
/// them by id: `⌃⌥Space` toggles the focus timer, `⌃⌥T` opens Quick Capture.
///
/// Carbon is used instead of `NSEvent.addGlobalMonitorForEvents` because global
/// key monitors require Accessibility permission, while `RegisterEventHotKey`
/// works in a sandboxed app without prompting.
@MainActor
final class MacGlobalHotKey {
    static let shared = MacGlobalHotKey()

    /// Signature used for every Pepinillo hotkey id ("PEN").
    private static let signature = OSType(0x5045504E)

    enum HotKeyID {
        static let focusToggle = 1
        static let quickCapture = 2
    }

    private var hotKeyRefs: [Int: EventHotKeyRef] = [:]
    private var eventHandlerRef: EventHandlerRef?
    private var actions: [Int: @MainActor () -> Void] = [:]

    private init() {}

    /// Installs or updates the action for a hotkey and registers it once.
    func register(
        id: Int,
        keyCode: Int,
        modifiers: Int,
        action: @escaping @MainActor () -> Void
    ) {
        actions[id] = action
        guard hotKeyRefs[id] == nil else { return }
        installEventHandlerIfNeeded()

        var hotKeyRef: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: Self.signature, id: UInt32(id))
        let status = RegisterEventHotKey(
            UInt32(keyCode),
            UInt32(modifiers),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        guard status == noErr, let hotKeyRef else {
            // A conflict with another app's hotkey is the likely cause; the
            // shortcut silently stays unregistered for that combo.
            actions[id] = nil
            return
        }
        hotKeyRefs[id] = hotKeyRef
    }

    func unregisterAll() {
        for ref in hotKeyRefs.values {
            UnregisterEventHotKey(ref)
        }
        hotKeyRefs.removeAll()
        actions.removeAll()
        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
            self.eventHandlerRef = nil
        }
    }

    private func installEventHandlerIfNeeded() {
        guard eventHandlerRef == nil else { return }

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
        if handlerStatus != noErr {
            eventHandlerRef = nil
        }
    }

    fileprivate func handle(id: UInt32) {
        actions[Int(id)]?()
    }
}

/// Carbon invokes this on the main thread. The `Task` hop keeps the callback
/// free of captured actor-isolated state.
private let macGlobalHotKeyHandler: EventHandlerUPP = { _, event, _ in
    var hotKeyID = EventHotKeyID()
    if let event {
        GetEventParameter(
            event,
            EventParamName(kEventParamDirectObject),
            EventParamType(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            &hotKeyID
        )
    }
    let id = hotKeyID.id
    Task { @MainActor in
        MacGlobalHotKey.shared.handle(id: id)
    }
    return noErr
}
