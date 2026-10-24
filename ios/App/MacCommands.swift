// MacCommands.swift
// Pepinillo — Deep Work Companion for Apple
//
// macOS / Mac Catalyst menu bar commands.
// Provides Focus, Plan, and Window menus with keyboard shortcuts.
// Injected into the WindowGroup via .commands { PepinilloCommands() }.

import SwiftUI
import ComposableArchitecture

#if os(macOS)
import AppKit
#endif

// MARK: - Focus Toggle Command

/// Single mapping shared by the menu command, the menu bar primary action, and
/// the global shortcut. Keeping the decision here prevents the three surfaces
/// from drifting apart.
enum FocusToggleCommand {
    enum Decision: Equatable {
        case start
        case pause
        case resume
        case nextPhase
    }

    static func decision(for focus: FocusFeature.State) -> Decision {
        if focus.isWaitingForNextPhase { return .nextPhase }
        if !focus.isRunning { return .start }
        if focus.isPaused { return .resume }
        return .pause
    }

    @MainActor
    static func toggle(store: StoreOf<AppFeature>) {
        toggle(focusStore: store.scope(state: \.focus, action: \.focus))
    }

    @MainActor
    static func toggle(focusStore store: StoreOf<FocusFeature>) {
        switch decision(for: store.state) {
        case .start:
            store.send(.startTapped())
        case .pause:
            store.send(.pauseTapped)
        case .resume:
            store.send(.resumeTapped)
        case .nextPhase:
            store.send(.startNextPhaseTapped)
        }
    }
}

// MARK: - Session Hot-Key Commands

/// Decisions for the extra global session shortcuts (`⌃⌥→` skip / next phase,
/// `⌃⌥X` end session). Pure so they can be tested without AppKit and cannot
/// drift from the Focus-menu equivalents.
enum MacSessionCommand {
    enum NextPhaseDecision: Equatable {
        /// Waiting hold: advance into the pending phase.
        case startNextPhase
        /// Running: skip the current phase.
        case skip
        case none
    }

    static func nextPhaseDecision(isRunning: Bool, isWaitingForNextPhase: Bool) -> NextPhaseDecision {
        if isWaitingForNextPhase { return .startNextPhase }
        if isRunning { return .skip }
        return .none
    }

    @MainActor
    static func nextPhase(store: StoreOf<AppFeature>) {
        switch nextPhaseDecision(
            isRunning: store.state.focus.isRunning,
            isWaitingForNextPhase: store.state.focus.isWaitingForNextPhase
        ) {
        case .startNextPhase:
            store.send(.focus(.startNextPhaseTapped))
        case .skip:
            store.send(.focus(.skipPhaseTapped))
        case .none:
            break
        }
    }

    enum StopDecision: Equatable {
        case stop
        case none
    }

    static func stopDecision(isRunning: Bool) -> StopDecision {
        isRunning ? .stop : .none
    }

    @MainActor
    static func stop(store: StoreOf<AppFeature>) {
        if store.state.focus.isRunning {
            store.send(.focus(.stopTapped))
        }
    }
}

// MARK: - Pepinillo Commands

extension Notification.Name {
    /// Posted by the Edit > Search Tasks command and observed by `MacPlanView`.
    static let macPlanSearchRequested = Notification.Name("pepinillo.mac.plan.search")
    /// Posted by Plan > Rename Task and observed by `MacPlanView`.
    static let macPlanRenameRequested = Notification.Name("pepinillo.mac.plan.rename")
    /// Posted by Plan > Show Inspector and observed by `MacPlanView`.
    static let macPlanInspectorToggleRequested = Notification.Name("pepinillo.mac.plan.inspector")
    /// Posted when Rename Task should focus the inspector title field.
    static let macInspectorFocusTitleRequested = Notification.Name("pepinillo.mac.inspector.focusTitle")
    /// Posted by Plan > Quick Capture and observed by `MacQuickCaptureController`
    /// (a Mac-target class, so the menu routes through a notification instead
    /// of a direct reference).
    static let macQuickCaptureToggleRequested = Notification.Name("pepinillo.mac.quickCapture.toggle")
}

struct PepinilloCommands: Commands {
    let store: StoreOf<AppFeature>

    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(after: .textEditing) {
            Button(String(localized: "Search Tasks")) {
                NotificationCenter.default.post(name: .macPlanSearchRequested, object: nil)
            }
            .keyboardShortcut("f", modifiers: .command)
        }

        // MARK: Focus Menu
        CommandMenu(String(localized: "menu.focus.title", defaultValue: "Focus")) {
            Button(String(localized: "menu.focus.startpause", defaultValue: "Start / Pause")) {
                FocusToggleCommand.toggle(store: store)
            }
            .keyboardShortcut(.return, modifiers: .command)

            Button(String(localized: "menu.focus.skipphase", defaultValue: "Skip Phase")) {
                store.send(.focus(.skipPhaseTapped))
            }
            .disabled(!store.focus.isRunning)

            Button(String(localized: "menu.focus.stopsession", defaultValue: "Stop Session")) {
                store.send(.focus(.stopTapped))
            }
            .keyboardShortcut(".", modifiers: .command)
            .disabled(!store.focus.isRunning)

            Divider()

            Button(String(localized: "menu.focus.pomodoro", defaultValue: "Pomodoro")) {
                store.send(.focus(.modeSelected(.pomodoro)))
            }
            .keyboardShortcut("1", modifiers: [.command, .option])
            .disabled(store.focus.isRunning)

            Button(String(localized: "menu.focus.flowtime", defaultValue: "Flowtime")) {
                store.send(.focus(.modeSelected(.flowtime)))
            }
            .keyboardShortcut("2", modifiers: [.command, .option])
            .disabled(store.focus.isRunning)

            Button(String(localized: "menu.focus.timeblock", defaultValue: "Time Block")) {
                store.send(.focus(.modeSelected(.timeBlock)))
            }
            .keyboardShortcut("3", modifiers: [.command, .option])
            .disabled(store.focus.isRunning)

            Button(String(localized: "menu.focus.stopwatch", defaultValue: "Stopwatch")) {
                store.send(.focus(.modeSelected(.stopwatch)))
            }
            .keyboardShortcut("4", modifiers: [.command, .option])
            .disabled(store.focus.isRunning)
        }

        // MARK: Plan Menu
        CommandMenu(String(localized: "menu.plan.title", defaultValue: "Plan")) {
            Button(String(localized: "menu.plan.newtask", defaultValue: "New Task")) {
                store.send(.tabSelected(.plan))
                store.send(.tasks(.newTaskRequested))
            }
            .keyboardShortcut("n", modifiers: .command)

            #if os(macOS)
            Button(String(localized: "Quick Capture")) {
                NotificationCenter.default.post(name: .macQuickCaptureToggleRequested, object: nil)
            }
            // The ⌃⌥T equivalent is registered globally via Carbon
            // (MacGlobalHotKey); giving the menu item the same shortcut fires
            // both paths at once when the app is frontmost and toggles the
            // panel twice.

            // The Mac capture panel lives in the macOS target only; Catalyst
            // keeps the Plan menu without it.
            #endif

            Divider()

            Button(String(localized: "Rename Task")) {
                NotificationCenter.default.post(name: .macPlanRenameRequested, object: nil)
            }
            .keyboardShortcut("r", modifiers: .command)
            .disabled(store.selectedTab != .plan)

            Button(String(localized: "Show Inspector")) {
                NotificationCenter.default.post(name: .macPlanInspectorToggleRequested, object: nil)
            }
            .keyboardShortcut("i", modifiers: [.command, .option])
            .disabled(store.selectedTab != .plan)
        }

        // MARK: View Menu Additions
        CommandGroup(after: .toolbar) {
            Button(String(localized: "menu.view.focus", defaultValue: "Focus")) {
                store.send(.tabSelected(.focus))
            }
            .keyboardShortcut("1", modifiers: .command)

            Button(String(localized: "menu.view.plan", defaultValue: "Plan")) {
                store.send(.tabSelected(.plan))
            }
            .keyboardShortcut("2", modifiers: .command)

            Button(String(localized: "menu.view.today", defaultValue: "Today")) {
                store.send(.tabSelected(.dashboard))
            }
            .keyboardShortcut("3", modifiers: .command)

            #if os(macOS)
            Divider()

            Button(String(localized: "Statistics")) {
                openWindow(id: "statistics")
            }
            .keyboardShortcut("4", modifiers: .command)
            #endif
        }

        // MARK: Help Menu
        // The macOS convention: Help ▸ "AppName Help" (⇧⌘?) as the first
        // item. The iOS app keeps its Help & Support screen in the Account
        // tab, so this group only exists on the native Mac target.
        #if os(macOS)
        CommandGroup(replacing: .help) {
            Button(String(localized: "Pepinillo Help")) {
                openWindow(id: "help")
            }
            // "?" already implies ⇧; adding .shift again registers a
            // double-shift equivalent that never matches the real ⇧⌘/ key
            // event. `.command` alone is the documented help-shortcut form.
            .keyboardShortcut("?", modifiers: .command)

            Divider()

            Button(String(localized: "Send Feedback")) {
                NSWorkspace.shared.open(HelpLinks.feedback)
            }
        }
        #endif
    }
}
