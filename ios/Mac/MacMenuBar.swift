// MacMenuBar.swift
// Pepinillo — native macOS menu bar presence
//
// The menu bar is the always-available surface: it shows the live countdown
// and drives the same FocusFeature actions as the main window.

import AppKit
import ComposableArchitecture
import SwiftUI

// MARK: - Label

struct MacMenuBarLabel: View {
    let store: StoreOf<AppFeature>?

    var body: some View {
        if let store {
            let focus = store.focus
            if focus.isRunning {
                Label(focus.displayTime, systemImage: focus.modeIcon)
                    .monospacedDigit()
            } else {
                Image(systemName: "timer")
            }
        } else {
            Image(systemName: "timer")
        }
    }
}

// MARK: - Popover

struct MacMenuBarView: View {
    @Bindable var store: StoreOf<AppFeature>

    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings

    private var focus: FocusFeature.State { store.focus }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            time
            primaryAction
            secondaryActions
            Divider()
            todayStats
            Divider()
            footer
        }
        .padding(14)
        .frame(width: 320)
    }

    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: focus.selectedMode.systemImage)
                .foregroundStyle(.secondary)
            Text(focus.selectedMode.displayName)
                .font(.headline)
            Spacer()
            Text(focus.phaseLabel)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var time: some View {
        Text(focus.displayTime)
            .font(.system(size: 44, weight: .medium, design: .rounded))
            .monospacedDigit()
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 2)
    }

    @ViewBuilder
    private var primaryAction: some View {
        if focus.isWaitingForNextPhase {
            primaryButton("Start next phase", systemImage: "play.fill") {
                FocusToggleCommand.toggle(store: store)
            }
        } else if !focus.isRunning {
            primaryButton("Start", systemImage: "play.fill") {
                FocusToggleCommand.toggle(store: store)
            }
        } else if focus.isPaused {
            primaryButton("Resume", systemImage: "play.fill") {
                FocusToggleCommand.toggle(store: store)
            }
        } else {
            primaryButton("Pause", systemImage: "pause.fill") {
                FocusToggleCommand.toggle(store: store)
            }
        }
    }

    private func primaryButton(
        _ title: LocalizedStringKey,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
    }

    @ViewBuilder
    private var secondaryActions: some View {
        if focus.isRunning {
            HStack {
                Button("Skip") { store.send(.focus(.skipPhaseTapped)) }
                Button("Stop") { store.send(.focus(.stopTapped)) }
            }
            .buttonStyle(.link)
            .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    private var todayStats: some View {
        HStack(spacing: 18) {
            stat(value: "\(store.analytics.sessionsCompleted)", label: "sessions")
            stat(value: "\(store.analytics.totalFocusMinutes)", label: "min")
            stat(value: "\(store.analytics.currentStreakDays)", label: "streak")
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private func stat(value: String, label: LocalizedStringKey) -> some View {
        VStack(spacing: 1) {
            Text(value)
                .font(.system(.body, design: .rounded).weight(.semibold))
                .monospacedDigit()
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(minWidth: 52)
    }

    private var footer: some View {
        HStack {
            Button("Open Pepinillo") {
                openWindow(id: "main")
                NSApp.activate(ignoringOtherApps: true)
            }
            .buttonStyle(.link)

            Spacer()

            Menu {
                Button("Settings…") { openSettings() }
                Divider()
                Button("Quit Pepinillo") { NSApplication.shared.terminate(nil) }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
    }
}
