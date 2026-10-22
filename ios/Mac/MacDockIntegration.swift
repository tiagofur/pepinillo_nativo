// MacDockIntegration.swift
// Pepinillo — native macOS Dock presence
//
// Brings the app to Dock-icon parity with the menu bar: a context menu that
// drives the same FocusFeature actions, a badge with the minutes remaining, and
// an App-Nap activity so tick delivery stays prompt while a session runs even
// when the main window is closed.

import AppKit
import ComposableArchitecture

/// Names posted by AppKit surfaces (Dock menu, Services, reopen) and observed by
/// the menu bar label, which is the only view alive for the whole app lifetime.
extension Notification.Name {
    /// Open the main window; `object` optionally carries the `AppFeature.Tab`
    /// to select before the window appears.
    static let macOpenMainWindow = Notification.Name("pepinillo.mac.openMainWindow")
}

/// Keeps the Dock badge and the process activity in sync with the focus engine.
/// Called from the menu bar label's change notifications, because the label
/// re-renders on every engine tick even when no window exists.
@MainActor
final class MacDockChrome {
    static let shared = MacDockChrome()

    private var activityToken: NSObjectProtocol?
    private var displaySleepToken: NSObjectProtocol?

    func sync(focus: FocusFeature.State, keepDisplayAwake: Bool = false) {
        let isActive = focus.isRunning && !focus.isPaused

        NSApp.dockTile.badgeLabel = badgeLabel(for: focus)

        if isActive, activityToken == nil {
            // `.userInitiated` opts the process out of App Nap while a session
            // runs. Deliberately NOT `.idleSystemSleepDisabled`: the engine is
            // wall-clock anchored, so letting the Mac sleep is safe and kind.
            activityToken = ProcessInfo.processInfo.beginActivity(
                options: .userInitiated,
                reason: "Pepinillo focus session in progress"
            )
        } else if !isActive, let token = activityToken {
            ProcessInfo.processInfo.endActivity(token)
            activityToken = nil
        }

        if isActive, keepDisplayAwake, displaySleepToken == nil {
            displaySleepToken = ProcessInfo.processInfo.beginActivity(
                options: .idleDisplaySleepDisabled,
                reason: "Pepinillo session: keep display awake"
            )
        } else if (!isActive || !keepDisplayAwake), let token = displaySleepToken {
            ProcessInfo.processInfo.endActivity(token)
            displaySleepToken = nil
        }
    }

    /// Mail-style red badge counting down the current phase, in minutes.
    /// Stopwatch counts up (no `remainingSeconds`), so it stays unbadged.
    private func badgeLabel(for focus: FocusFeature.State) -> String? {
        guard focus.isRunning, !focus.isPaused,
              let remaining = focus.remainingSeconds
        else { return nil }
        let minutes = Int(ceil(remaining / 60))
        return minutes > 0 ? String(minutes) : nil
    }
}

extension MacAppDelegate {
    /// The menu AppKit shows when the user right-clicks (or long-presses) the
    /// Dock icon. Built lazily at click time, so it always reflects live state.
    func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
        guard let store else { return nil }
        let focus = store.focus
        let menu = NSMenu()

        menu.addItem(
            Self.actionItem(
                title: Self.primaryActionTitle(for: focus),
                action: #selector(dockToggleFocus(_:))
            )
        )

        let skip = Self.actionItem(
            title: String(localized: "menu.focus.skipphase", defaultValue: "Skip Phase"),
            action: #selector(dockSkipPhase(_:))
        )
        let stop = Self.actionItem(
            title: String(localized: "menu.focus.stopsession", defaultValue: "Stop Session"),
            action: #selector(dockStopSession(_:))
        )
        menu.addItem(skip)
        menu.addItem(stop)

        menu.addItem(.separator())
        menu.addItem(
            Self.actionItem(
                title: String(localized: "menu.plan.newtask", defaultValue: "New Task"),
                action: #selector(dockNewTask(_:))
            )
        )

        menu.addItem(.separator())
        for tab in AppFeature.Tab.macSidebarSections {
            let item = Self.actionItem(
                title: tab.macTitle,
                action: #selector(dockOpenSection(_:))
            )
            item.representedObject = tab
            menu.addItem(item)
        }

        return menu
    }

    static func primaryActionTitle(for focus: FocusFeature.State) -> String {
        switch FocusToggleCommand.decision(for: focus) {
        case .start: return String(localized: "Start")
        case .pause: return String(localized: "Pause")
        case .resume: return String(localized: "Resume")
        case .nextPhase: return String(localized: "Start next phase")
        }
    }

    private static func actionItem(title: String, action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = Self.current
        return item
    }

    @objc func dockToggleFocus(_ sender: Any?) {
        guard let store else { return }
        FocusToggleCommand.toggle(store: store)
    }

    @objc func dockSkipPhase(_ sender: Any?) {
        store?.send(.focus(.skipPhaseTapped))
    }

    @objc func dockStopSession(_ sender: Any?) {
        store?.send(.focus(.stopTapped))
    }

    @objc func dockNewTask(_ sender: Any?) {
        store?.send(.tabSelected(.plan))
        store?.send(.tasks(.newTaskRequested))
        requestMainWindow(selecting: .plan)
    }

    @objc func dockOpenSection(_ sender: NSMenuItem) {
        guard let tab = sender.representedObject as? AppFeature.Tab else { return }
        store?.send(.tabSelected(tab))
        requestMainWindow(selecting: tab)
    }

    /// SwiftUI owns window creation, so opening the main window routes through
    /// the always-alive menu bar label, which holds the `openWindow` environment.
    func requestMainWindow(selecting tab: AppFeature.Tab? = nil) {
        NotificationCenter.default.post(
            name: .macOpenMainWindow,
            object: tab
        )
    }
}
