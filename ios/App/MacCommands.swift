// MacCommands.swift
// Pepinillo — Deep Work Companion for Apple
//
// macOS / Mac Catalyst menu bar commands.
// Provides Focus, Tasks, and Window menus with keyboard shortcuts.
// Injected into the WindowGroup via .commands { PepinilloCommands() }.

import SwiftUI
import ComposableArchitecture

// MARK: - Pepinillo Commands

struct PepinilloCommands: Commands {
    let store: StoreOf<AppFeature>

    var body: some Commands {
        // MARK: Focus Menu
        CommandMenu("Focus") {
            Button("Start / Pause") {
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

            Button("Stop Session") {
                store.send(.focus(.stopTapped))
            }
            .keyboardShortcut(".", modifiers: .command)
            .disabled(!store.focus.isRunning)

            Divider()

            Button("Pomodoro") {
                store.send(.focus(.modeSelected(.pomodoro)))
            }
            .keyboardShortcut("1", modifiers: .command)

            Button("Flowtime") {
                store.send(.focus(.modeSelected(.flowtime)))
            }
            .keyboardShortcut("2", modifiers: .command)

            Button("Time Block") {
                store.send(.focus(.modeSelected(.timeBlock)))
            }
            .keyboardShortcut("3", modifiers: .command)

            Button("Stopwatch") {
                store.send(.focus(.modeSelected(.stopwatch)))
            }
            .keyboardShortcut("4", modifiers: .command)
        }

        // MARK: Tasks Menu
        CommandMenu("Tasks") {
            Button("New Task") {
                store.send(.tabSelected(.tasks))
                store.send(.tasks(.addTaskTapped))
            }
            .keyboardShortcut("n", modifiers: .command)

            Button("Go to Tasks") {
                store.send(.tabSelected(.tasks))
            }
            .keyboardShortcut("t", modifiers: [.command, .shift])
        }

        // MARK: View Menu Additions
        CommandGroup(after: .toolbar) {
            Button("Go to Focus") {
                store.send(.tabSelected(.focus))
            }
            .keyboardShortcut("f", modifiers: [.command, .shift])

            Button("Go to Analytics") {
                store.send(.tabSelected(.analytics))
            }
            .keyboardShortcut("a", modifiers: [.command, .shift])

            Button("Settings") {
                store.send(.settingsDrawerTapped)
            }
            .keyboardShortcut(",", modifiers: .command)
        }
    }
}
