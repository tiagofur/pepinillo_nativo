// MacStatusBarController.swift
// Pepinillo — native macOS status item
//
// SwiftUI's `MenuBarExtra` label renders once and never re-renders (the main
// window ticks while the status item stays stale, and neither `@Observable`
// nor `ObservableObject` changes reach it). The status item is therefore
// AppKit-owned: the countdown is drawn into the button by `MacPresencePulse`,
// and the popover hosts the very same `MacMenuBarView` the MenuBarExtra used.

import AppKit
import ComposableArchitecture
import SwiftUI

/// Status-item presentation while a session runs. `countdown` (mode icon +
/// live time) is the free default; the minimal styles are Pepinillo+ (the
/// "menu bar control" tier from the Kofe-Flow parity pass). Idle always shows
/// the timer icon so the item never disappears.
enum MenuBarStatusStyle: String, CaseIterable, Sendable {
    case countdown
    case timeOnly
    case iconOnly

    /// Device-local choice (standard defaults — shell preference).
    static var current: MenuBarStatusStyle {
        MenuBarStatusStyle(
            rawValue: UserDefaults.standard.string(forKey: MacAppStorageKeys.menuBarStatusStyle) ?? ""
        ) ?? .countdown
    }

    /// The minimal styles are Pepinillo+.
    var isPro: Bool { self != .countdown }
}

@MainActor
final class MacStatusBarController: NSObject, NSPopoverDelegate {
    static private(set) var shared: MacStatusBarController?

    private var statusItem: NSStatusItem?
    private let popover = NSPopover()
    private var pulse = MacSessionPulse(focus: nil)
    private weak var store: StoreOf<AppFeature>?

    init(presence: MacPresencePulse) {
        super.init()
        Self.shared = self

        popover.behavior = .transient
        popover.delegate = self

        presence.onPulseChanged = { [weak self] pulse, focus in
            self?.sessionChanged(pulse: pulse, focus: focus)
        }

        // Dock-menu items and `applicationShouldHandleReopen` route through
        // here; the AppKit path activates the window that SwiftUI released on
        // close, and the popover content's `openWindow` bridge recreates the
        // scene window when the lookup finds nothing.
        NotificationCenter.default.addObserver(
            forName: .macOpenMainWindow,
            object: nil,
            queue: .main
        ) { [weak self] note in
            let tab = note.object as? AppFeature.Tab
            Task { @MainActor in
                self?.openMainWindow(selecting: tab)
            }
        }
    }

    /// Installs the status item once the shared store exists.
    func install(store: StoreOf<AppFeature>) {
        guard statusItem == nil else { return }
        self.store = store

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.target = self
        item.button?.action = #selector(togglePopover(_:))
        statusItem = item

        popover.contentViewController = NSHostingController(
            rootView: MacStatusBarRootView(store: store)
        )

        renderLabel()
    }

    // MARK: - Pulse

    func sessionChanged(pulse: MacSessionPulse, focus: FocusFeature.State) {
        self.pulse = pulse
        renderLabel()
        MacDockChrome.shared.sync(focus: focus, keepDisplayAwake: pulse.keepDisplayAwake)
    }

    /// Settings changed the status style. The pulse only fires on session
    /// state changes, so re-render explicitly from the cached pulse.
    func reloadStyle() {
        renderLabel()
    }

    private func renderLabel() {
        guard let button = statusItem?.button else { return }
        let style = MenuBarStatusStyle.current

        if pulse.isRunning {
            switch style {
            case .countdown, .timeOnly:
                let text = NSMutableAttributedString()
                if style == .countdown, let icon = statusIcon(pulse.modeIcon) {
                    text.append(icon)
                    text.append(NSAttributedString(string: "  "))
                }
                text.append(
                    NSAttributedString(
                        string: pulse.displayTime,
                        attributes: [
                            .font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium),
                            .foregroundColor: NSColor.labelColor,
                        ]
                    )
                )
                button.image = nil
                button.attributedTitle = text
                button.appearance = nil
            case .iconOnly:
                button.attributedTitle = NSAttributedString()
                button.image = NSImage(systemSymbolName: pulse.modeIcon, accessibilityDescription: nil)?
                    .withSymbolConfiguration(.init(pointSize: 13, weight: .regular))
            }
        } else {
            button.attributedTitle = NSAttributedString()
            button.image = NSImage(systemSymbolName: "timer", accessibilityDescription: nil)?
                .withSymbolConfiguration(.init(pointSize: 13, weight: .regular))
        }

        button.setAccessibilityLabel(String(localized: "Pepinillo"))
        button.setAccessibilityValue(
            pulse.isRunning ? pulse.displayTime : String(localized: "Ready")
        )
    }

    /// Status bar icons must render as template images; the countdown text is
    /// plain label-colored text so it adapts to light and dark menu bars.
    private func statusIcon(_ symbol: String) -> NSAttributedString? {
        guard let image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)?
            .withSymbolConfiguration(.init(pointSize: 12, weight: .regular))
        else { return nil }
        let attachment = NSTextAttachment()
        attachment.image = image
        return NSAttributedString(attachment: attachment)
    }

    // MARK: - Popover

    @objc private func togglePopover(_ sender: Any?) {
        guard let button = statusItem?.button else { return }
        if popover.isShown {
            popover.performClose(sender)
            return
        }
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        button.highlight(true)
    }

    func popoverDidClose(_ notification: Notification) {
        statusItem?.button?.highlight(false)
    }

    // MARK: - Window opening

    func openMainWindow(selecting tab: AppFeature.Tab? = nil) {
        if let tab {
            store?.send(.tabSelected(tab))
        }
        NSApp.activate(ignoringOtherApps: true)

        if let window = NSApp.windows.first(where: {
            $0.title == "Pepinillo" || $0.identifier?.rawValue == "main"
        }) {
            window.makeKeyAndOrderFront(nil)
        }
    }
}

/// Root of the status-item popover. The `openWindow` environment is only
/// available inside SwiftUI, so window (re)creation bridges through here.
private struct MacStatusBarRootView: View {
    let store: StoreOf<AppFeature>

    @Environment(\.openWindow) private var openWindow

    var body: some View {
        MacMenuBarView(store: store)
            .onReceive(NotificationCenter.default.publisher(for: .macOpenMainWindow)) { note in
                guard note.object != nil else { return }
                openWindow(id: "main")
            }
    }
}
