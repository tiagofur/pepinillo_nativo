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

        installDockTileViewIfNeeded()
        (NSApp.dockTile.contentView as? MacDockTileView)?.progress = isActive ? focus.progress : nil
        // The dock tile has no display cycle of its own: per its header, the
        // redraw of the content view must be requested on the tile itself.
        NSApp.dockTile.display()
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

    /// The dock tile draws the icon itself once a content view is set, so the
    /// progress-arc view must be installed even when nothing is running.
    private func installDockTileViewIfNeeded() {
        guard NSApp.dockTile.contentView == nil else { return }
        let size = NSApp.dockTile.size
        let view = MacDockTileView(
            frame: NSRect(x: 0, y: 0, width: size.width, height: size.height)
        )
        NSApp.dockTile.contentView = view
        NSApp.dockTile.display()
    }
}

/// Draws the app icon with a session-progress ring around it. The dock tile
/// stops drawing the default icon once a content view is installed, so the
/// icon is rendered here; `progress == nil` shows the bare icon.
final class MacDockTileView: NSView {
    /// Fraction of the current phase elapsed, or nil when idle.
    var progress: Double? {
        didSet { needsDisplay = true }
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.clear.setFill()
        bounds.fill()

        if let icon = NSApp.applicationIconImage {
            let iconSide = min(bounds.width, bounds.height) - 8
            let iconRect = NSRect(
                x: (bounds.width - iconSide) / 2,
                y: (bounds.height - iconSide) / 2,
                width: iconSide,
                height: iconSide
            )
            icon.draw(in: iconRect, from: .zero, operation: .sourceOver, fraction: 1)
        }

        guard let progress else { return }
        let clamped = max(0, min(1, progress))
        let arcRect = bounds.insetBy(dx: 2, dy: 2)
        let radius = arcRect.width / 2 - 1.5
        let center = NSPoint(x: arcRect.midX, y: arcRect.midY)

        let track = NSBezierPath()
        track.appendArc(withCenter: center, radius: radius, startAngle: 90, endAngle: -270, clockwise: false)
        track.lineWidth = 3
        NSColor.quaternaryLabelColor.setStroke()
        track.stroke()

        guard clamped > 0.005 else { return }
        let arc = NSBezierPath()
        arc.appendArc(
            withCenter: center,
            radius: radius,
            startAngle: 90,
            endAngle: 90 - clamped * 360,
            clockwise: true
        )
        arc.lineWidth = 3
        arc.lineCapStyle = .round
        NSColor.controlAccentColor.setStroke()
        arc.stroke()
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
