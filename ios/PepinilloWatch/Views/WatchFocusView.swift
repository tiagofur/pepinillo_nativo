// WatchFocusView.swift
// Pepinillo — Deep Work Companion for Apple
//
// Apple Watch focus screen. Compact timer display, mode picker,
// start/pause/stop controls. Mirrors iOS session state via WatchConnectivity.

import SwiftUI
import ComposableArchitecture

// MARK: - WatchFocusView

struct WatchFocusView: View {
    @Bindable var store: StoreOf<WatchFocusFeature>
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 8) {
            if store.isSessionActive {
                activeSessionView
            } else {
                idleView
            }
        }
        .onAppear { store.send(.onAppear) }
    }

    // MARK: - Active Session

    @State private var showStopConfirmation = false

    private var activeSessionView: some View {
        VStack(spacing: 6) {
            // Progress ring + time
            ZStack {
                // Background ring track
                Circle()
                    .stroke(modeColor.opacity(0.2), lineWidth: 6)

                if let progress = store.progress {
                    Circle()
                        .trim(from: 0, to: CGFloat(progress))
                        .stroke(modeColor, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(reduceMotion ? nil : .linear(duration: 0.1), value: progress)
                }

                VStack(spacing: 2) {
                    // Mode emoji
                    Text(store.selectedMode.icon)
                        .font(.system(size: 14))

                    Text(store.displayTime)
                        .font(.system(.title2, design: .rounded, weight: .medium))
                        .monospacedDigit()
                        .contentTransition(.numericText())

                    if let num = store.pomodoroNumber {
                        Text("#\(num)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(height: 90)

            // Phase label
            Text(store.phaseLabel)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            // Linked task
            if let task = store.linkedTaskTitle {
                Text(task)
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }

            // Controls
            HStack(spacing: 12) {
                // Stop (with confirmation)
                Button {
                    showStopConfirmation = true
                } label: {
                    Image(systemName: "stop.fill")
                        .font(.caption)
                        .foregroundStyle(.red)
                        .frame(width: 32, height: 32)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .buttonStyle(.plain)

                // Pause / Resume
                Button {
                    store.send(.pauseResumeTapped)
                } label: {
                    Image(systemName: store.isPaused ? "play.fill" : "pause.fill")
                        .font(.callout)
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(modeColor, in: Circle())
                }
                .buttonStyle(.plain)

                // Skip phase
                Button {
                    store.send(.skipTapped)
                } label: {
                    Image(systemName: "forward.fill")
                        .font(.caption)
                        .foregroundStyle(.white)
                        .frame(width: 32, height: 32)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .confirmationDialog(
            String(localized: "End Session?"),
            isPresented: $showStopConfirmation,
            titleVisibility: .visible
        ) {
            Button(String(localized: "End Session"), role: .destructive) {
                store.send(.stopTapped)
            }
        }
    }

    // MARK: - Idle View

    @State private var crownModeIndex: Double = 0

    private var idleView: some View {
        VStack(spacing: 10) {
            // Mode selector (horizontal scroll)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(FocusMode.allCases) { mode in
                        WatchModeChip(
                            mode: mode,
                            isSelected: store.selectedMode == mode,
                            modeColor: colorFor(mode)
                        ) {
                            store.send(.modeSelected(mode))
                        }
                    }
                }
                .padding(.horizontal, 4)
            }

            // Stats row
            HStack(spacing: 12) {
                WatchStatPill(
                    icon: "timer",
                    value: formatMinutes(store.todayFocusMinutes)
                )
                if store.currentStreakDays > 0 {
                    WatchStatPill(
                        icon: "flame.fill",
                        value: "\(store.currentStreakDays)d",
                        color: .orange
                    )
                }
            }

            // Start button
            Button {
                store.send(.startTapped)
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "play.fill")
                        .font(.caption)
                    Text(String(localized: "Start"))
                        .font(.caption)
                        .fontWeight(.semibold)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 36)
                .background(modeColor, in: Capsule())
            }
            .buttonStyle(.plain)

            // Connectivity indicator
            if !store.isConnected {
                HStack(spacing: 4) {
                    Image(systemName: "iphone.slash")
                        .font(.system(size: 9))
                    Text(String(localized: "iPhone disconnected"))
                        .font(.system(size: 9))
                }
                .foregroundStyle(.secondary)
            }
        }
        // Digital Crown to cycle through modes
        .focusable()
        .digitalCrownRotation(
            $crownModeIndex,
            from: 0,
            through: Double(FocusMode.allCases.count - 1),
            by: 1,
            sensitivity: .low
        )
        .onChange(of: crownModeIndex) { _, newValue in
            let index = Int(newValue.rounded()) % FocusMode.allCases.count
            let mode = FocusMode.allCases[index]
            if mode != store.selectedMode {
                store.send(.modeSelected(mode))
            }
        }
        .onAppear {
            if let index = FocusMode.allCases.firstIndex(of: store.selectedMode) {
                crownModeIndex = Double(index)
            }
        }
    }

    // MARK: - Helpers

    private var modeColor: Color {
        colorFor(store.selectedMode)
    }

    private func colorFor(_ mode: FocusMode) -> Color {
        switch mode {
        case .pomodoro:  return ModeColors.pomodoro
        case .flowtime:  return ModeColors.flowtime
        case .timeBlock: return ModeColors.timeBlock
        case .stopwatch: return ModeColors.stopwatch
        }
    }

    private func formatMinutes(_ minutes: Int) -> String {
        if minutes >= 60 {
            let h = minutes / 60
            let m = minutes % 60
            return m > 0 ? "\(h)h\(m)m" : "\(h)h"
        }
        return "\(minutes)m"
    }
}

// MARK: - Supporting Watch Views

private struct WatchModeChip: View {
    let mode: FocusMode
    let isSelected: Bool
    let modeColor: Color
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 2) {
                Text(mode.icon)
                    .font(.body)
                Text(mode.shortName)
                    .font(.system(size: 9))
                    .fontWeight(isSelected ? .semibold : .regular)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                isSelected
                    ? AnyShapeStyle(modeColor.opacity(0.25))
                    : AnyShapeStyle(Color.white.opacity(0.08))
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                isSelected
                    ? RoundedRectangle(cornerRadius: 8)
                        .stroke(modeColor.opacity(0.5), lineWidth: 1)
                    : nil
            )
        }
        .buttonStyle(.plain)
    }
}

private struct WatchStatPill: View {
    let icon: String
    let value: String
    var color: Color = .accentColor

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 9))
                .foregroundStyle(color)
            Text(value)
                .font(.system(size: 11, weight: .medium))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.ultraThinMaterial, in: Capsule())
    }
}

// MARK: - FocusMode.shortName (Watch-only display helper)

private extension FocusMode {
    var shortName: String {
        switch self {
        case .pomodoro:  return String(localized: "Pomo")
        case .flowtime:  return String(localized: "Flow")
        case .timeBlock: return String(localized: "Block")
        case .stopwatch: return String(localized: "Watch")
        }
    }
}
