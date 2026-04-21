// MacCommands.swift
// Pepinillo — Deep Work Companion for Apple
//
// macOS / Mac Catalyst menu bar commands.
// Provides Focus, Plan, and Window menus with keyboard shortcuts.
// Injected into the WindowGroup via .commands { PepinilloCommands() }.

import SwiftUI
import ComposableArchitecture

// MARK: - Pepinillo Commands

struct PepinilloCommands: Commands {
    let store: StoreOf<AppFeature>

    var body: some Commands {
        // MARK: Focus Menu
        CommandMenu(String(localized: "menu.focus.title", defaultValue: "Focus")) {
            Button(String(localized: "menu.focus.startpause", defaultValue: "Start / Pause")) {
                let focus = store.focus
                if !focus.isRunning {
                    store.send(.focus(.startTapped))
                } else if focus.isPaused {
                    store.send(.focus(.resumeTapped))
                } else {
                    store.send(.focus(.pauseTapped))
                }
            }
            .keyboardShortcut(.space, modifiers: [])

            Button(String(localized: "menu.focus.stopsession", defaultValue: "Stop Session")) {
                store.send(.focus(.stopTapped))
            }
            .keyboardShortcut(".", modifiers: .command)
            .disabled(!store.focus.isRunning)

            Divider()

            Button(String(localized: "menu.focus.pomodoro", defaultValue: "Pomodoro")) {
                store.send(.focus(.modeSelected(.pomodoro)))
            }
            .keyboardShortcut("1", modifiers: .command)

            Button(String(localized: "menu.focus.flowtime", defaultValue: "Flowtime")) {
                store.send(.focus(.modeSelected(.flowtime)))
            }
            .keyboardShortcut("2", modifiers: .command)

            Button(String(localized: "menu.focus.timeblock", defaultValue: "Time Block")) {
                store.send(.focus(.modeSelected(.timeBlock)))
            }
            .keyboardShortcut("3", modifiers: .command)

            Button(String(localized: "menu.focus.stopwatch", defaultValue: "Stopwatch")) {
                store.send(.focus(.modeSelected(.stopwatch)))
            }
            .keyboardShortcut("4", modifiers: .command)
        }

        // MARK: Plan Menu
        CommandMenu(String(localized: "menu.plan.title", defaultValue: "Plan")) {
            Button(String(localized: "menu.plan.newtask", defaultValue: "New Task")) {
                store.send(.tabSelected(.plan))
                store.send(.tasks(.addTaskTapped))
            }
            .keyboardShortcut("n", modifiers: .command)

            Button(String(localized: "menu.plan.gotoplan", defaultValue: "Go to Plan")) {
                store.send(.tabSelected(.plan))
            }
            .keyboardShortcut("t", modifiers: [.command, .shift])
        }

        // MARK: View Menu Additions
        CommandGroup(after: .toolbar) {
            Button(String(localized: "menu.view.gotofocus", defaultValue: "Go to Focus")) {
                store.send(.tabSelected(.focus))
            }
            .keyboardShortcut("f", modifiers: [.command, .shift])

            Button(String(localized: "menu.view.gotodashboard", defaultValue: "Go to Dashboard")) {
                store.send(.tabSelected(.dashboard))
            }
            .keyboardShortcut("a", modifiers: [.command, .shift])

            Button(String(localized: "menu.view.settings", defaultValue: "Settings")) {
                store.send(.tabSelected(.account))
            }
            .keyboardShortcut(",", modifiers: .command)
        }
    }
}
