// MacCommands.swift
// Pepinillo — Deep Work Companion for Apple
//
// macOS / Mac Catalyst menu bar commands.
// Provides Focus, Plan, and Window menus with keyboard shortcuts.
// Injected into the WindowGroup via .commands { PepinilloCommands() }.

import SwiftUI
import ComposableArchitecture

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

// MARK: - Pepinillo Commands

extension Notification.Name {
    /// Posted by the Edit > Search Tasks command and observed by `MacPlanView`.
    static let macPlanSearchRequested = Notification.Name("pepinillo.mac.plan.search")
}

struct PepinilloCommands: Commands {
    let store: StoreOf<AppFeature>

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
        }
    }
}
