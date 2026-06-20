// WatchTimerView.swift
// Pepinillo — Deep Work Companion for Apple
//
// Apple Watch timer screen. Large, glanceable timer display with progress ring,
// mode picker, controls, and linked task indicator.

import SwiftUI
import ComposableArchitecture

// MARK: - WatchTimerView

struct WatchTimerView: View {
    @Bindable var store: StoreOf<WatchTimerFeature>
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if store.isSessionActive {
            if store.isWaiting {
                waitingView
            } else {
                activeSessionView
            }
        } else {
            idleView
        }
    }

    // MARK: - Waiting for Next Phase

    private var waitingView: some View {
        VStack(spacing: 8) {
            Spacer(minLength: 0)

            // Indicate the pending phase with the mode icon
            Text(store.selectedMode.icon)
                .font(.system(size: 28))

            // phaseLabel here is the pending next phase name (set on .waitingForNextPhase) — tells the user what's next
            Text(store.phaseLabel)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Spacer(minLength: 0)

            // Phase-aware CTA — uses the isBreakPhase/isLongBreakPhase flags which
            // are now derived from the PENDING next phase in WatchSessionState.init(from:).
            let ctaLabel: String = {
                if store.isLongBreakPhase {
                    return String(localized: "Start long break",
                                  defaultValue: "Start long break")
                } else if store.isBreakPhase {
                    return String(localized: "Start break",
                                  defaultValue: "Start break")
                } else {
                    return String(localized: "Start focus",
                                  defaultValue: "Start focus")
                }
            }()

            Button {
                store.send(.startNextPhaseTapped)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 13, weight: .semibold))
                    Text(ctaLabel)
                        .font(.system(size: 15, weight: .semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .background(modeColor, in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 4)
        .padding(.bottom, 4)
    }

    // MARK: - Active Session

    @State private var showStopConfirmation = false

    private var activeSessionView: some View {
        VStack(spacing: 4) {
            // Progress ring + time (main focus area)
            ZStack {
                // Background ring track
                Circle()
                    .stroke(modeColor.opacity(0.2), lineWidth: 8)

                if let progress = store.progress {
                    Circle()
                        .trim(from: 0, to: CGFloat(progress))
                        .stroke(modeColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(reduceMotion ? nil : .linear(duration: 0.1), value: progress)
                }

                VStack(spacing: 2) {
                    // Mode emoji
                    Text(store.selectedMode.icon)
                        .font(.system(size: 16))

                    // Timer display — LARGE and prominent
                    Text(store.displayTime)
                        .font(.system(.title, design: .rounded, weight: .semibold))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .minimumScaleFactor(0.7)

                    // Pomodoro number
                    if let num = store.pomodoroNumber {
                        Text("#\(num)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 120)
            .padding(.top, -4)

            // Phase label
            Text(store.phaseLabel)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            // Linked task
            if let task = store.linkedTaskTitle {
                HStack(spacing: 3) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(modeColor)
                    Text(task)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                .lineLimit(1)
            }

            Spacer(minLength: 0)

            // Controls
            HStack(spacing: 12) {
                // Stop (with confirmation)
                Button {
                    showStopConfirmation = true
                } label: {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.red)
                        .frame(width: 36, height: 36)
                        .background(.red.opacity(0.15), in: Circle())
                }
                .buttonStyle(.plain)

                // Pause / Resume
                Button {
                    store.send(.pauseResumeTapped)
                } label: {
                    Image(systemName: store.isPaused ? "play.fill" : "pause.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(modeColor, in: Circle())
                }
                .buttonStyle(.plain)

                // Skip phase (only during break phases)
                if store.isBreakPhase {
                    Button {
                        store.send(.skipTapped)
                    } label: {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.8))
                            .frame(width: 36, height: 36)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.bottom, 2)
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
        VStack(spacing: 8) {
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

            // Linked task indicator
            if let task = store.linkedTaskTitle {
                HStack(spacing: 4) {
                    Image(systemName: "link")
                        .font(.system(size: 9))
                        .foregroundStyle(modeColor)
                    Text(task)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .lineLimit(1)
                .padding(.horizontal, 8)
            }

            // Stats row
            HStack(spacing: 10) {
                WatchStatPill(
                    icon: "timer",
                    value: formatMinutes(store.todayFocusMinutes)
                )
                if store.todaySessionsCompleted > 0 {
                    WatchStatPill(
                        icon: "checkmark.circle",
                        value: "\(store.todaySessionsCompleted)",
                        color: .green
                    )
                }
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
                HStack(spacing: 6) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 13, weight: .semibold))
                    Text(String(localized: "Start"))
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 40)
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
        let base = colorFor(store.selectedMode)
        if store.isLongBreakPhase {
            return base.longBreakVariant()
        } else if store.isBreakPhase {
            return base.shortBreakVariant()
        }
        return base
    }

    private func colorFor(_ mode: FocusMode) -> Color {
        ModeColors.color(for: mode.rawValue)
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
                    : AnyShapeStyle(.ultraThinMaterial)
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

struct WatchStatPill: View {
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

extension FocusMode {
    var shortName: String {
        switch self {
        case .pomodoro:  return String(localized: "Pomo")
        case .flowtime:  return String(localized: "Flow")
        case .timeBlock: return String(localized: "Block")
        case .stopwatch: return String(localized: "Watch")
        }
    }
}
