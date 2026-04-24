// FocusView.swift
// Pepinillo — Deep Work Companion for Apple
//
// The main focus screen. Shows the timer circle, mode selector,
// session controls, soundscape picker, and linked task.

import SwiftUI
import ComposableArchitecture

struct FocusView: View {
    @Bindable var store: StoreOf<FocusFeature>
    let streakDays: Int
    let sessionsToday: Int
    let totalFocusMinutesToday: Int

    @Environment(\.appTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var showStopConfirmation = false

    init(
        store: StoreOf<FocusFeature>,
        streakDays: Int = 0,
        sessionsToday: Int = 0,
        totalFocusMinutesToday: Int = 0
    ) {
        self.store = store
        self.streakDays = streakDays
        self.sessionsToday = sessionsToday
        self.totalFocusMinutesToday = totalFocusMinutesToday
    }

    var body: some View {
        ZStack {
            if sizeClass == .regular {
                // MARK: - iPad: adaptive layout (landscape ↔ portrait)
                GeometryReader { geo in
                    let isWide = geo.size.width > geo.size.height

                    if isWide {
                        // Landscape: side-by-side (original layout)
                        HStack(alignment: .top, spacing: 24) {
                            focusCoreColumn
                                .frame(maxWidth: 420)
                            FocusCompanionView(
                                store: store,
                                streakDays: streakDays,
                                sessionsToday: sessionsToday,
                                totalFocusMinutesToday: totalFocusMinutesToday
                            )
                            .frame(maxWidth: .infinity)
                        }
                        .padding(.horizontal, 24)
                        .contentMaxWidth()
                    } else {
                        // Portrait: timer on top, metrics below
                        ipadPortraitLayout(in: geo.size)
                    }
                }
            } else {
                // MARK: - iPhone: single-column layout (existing behavior)
                focusCoreColumn
            }
        }
        .conditionalAnimation(.easeInOut(duration: 0.3), value: store.isRunning)
        .conditionalAnimation(.easeInOut(duration: 0.3), value: store.selectedMode)
        .conditionalAnimation(.easeInOut(duration: 0.2), value: store.selectedSoundscape)
        // Hidden buttons carry keyboard shortcuts for external keyboards / Mac
        .background {
            Group {
                Button("") {
                    if !store.isRunning { store.send(.startTapped) }
                    else if store.isPaused { store.send(.resumeTapped) }
                    else { store.send(.pauseTapped) }
                }
                .keyboardShortcut(.space, modifiers: [])

                Button("") { store.send(.stopTapped) }
                    .keyboardShortcut(".", modifiers: .command)
            }
            .hidden()
        }
        // Soundscape Picker sheet
        .sheet(
            isPresented: Binding(
                get: { store.showSoundscapePicker },
                set: { if !$0 { store.send(.soundscapePickerDismissed) } }
            )
        ) {
            SoundscapePickerView(
                currentSoundscape: store.selectedSoundscape,
                isProUser: store.isProUser,
                onSelect: { store.send(.soundscapeSelected($0)) },
                onNeedsPro: { store.send(.paywallTapped) }
            )
            .presentationDetents([.medium])
        }
        // Task Picker sheet
        .sheet(
            isPresented: Binding(
                get: { store.isTaskPickerPresented },
                set: { if !$0 { store.send(.taskPickerDismissed) } }
            )
        ) {
            TaskPickerView(
                linkedTaskID: store.linkedTaskID,
                tasks: store.availableTasks,
                onSelectTask: { id, title, emoji in
                    store.send(.linkTask(id, title, emoji))
                },
                onUnlink: {
                    store.send(.unlinkTaskTapped)
                }
            )
            .presentationDetents([.medium])
        }
        .confirmationDialog(String(localized: "focus.endsession.title", defaultValue: "End Session?"), isPresented: $showStopConfirmation, titleVisibility: .visible) {
            Button(String(localized: "focus.endsession.button", defaultValue: "End Session"), role: .destructive) {
                store.send(.stopTapped)
                HapticManager.notification(.warning)
            }
        }
        .sheet(item: $store.scope(state: \.journal, action: \.journal)) { journalStore in
            SessionJournalView(store: journalStore)
        }
    }

    // MARK: - iPad Portrait Layout (timer top, metrics bottom)

    @ViewBuilder
    private func ipadPortraitLayout(in size: CGSize) -> some View {
        VStack(spacing: 0) {
            // Top: Timer + controls — constrained to ~50% of screen
            focusCoreColumn
                .frame(maxWidth: 600, maxHeight: size.height * 0.52)

            // Separator
            Rectangle()
                .fill(.quaternary)
                .frame(height: 1)
                .padding(.horizontal, 32)

            // Bottom: Metrics cards in a 2-col adaptive grid
            ScrollView {
                FocusCompanionView(
                    store: store,
                    streakDays: streakDays,
                    sessionsToday: sessionsToday,
                    totalFocusMinutesToday: totalFocusMinutesToday,
                    layout: .grid
                )
                .frame(maxWidth: 600)
            }
            .scrollBounceBehavior(.basedOnSize)
            .frame(maxHeight: .infinity)
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Focus Core Column (mode picker + ring + picker + start)

    @ViewBuilder
    private var focusCoreColumn: some View {
        VStack(spacing: 0) {
            // Mode Selector (top)
            if !store.isRunning {
                ModePickerView(
                    selectedMode: store.selectedMode,
                    isProUser: store.isProUser,
                    onSelect: { store.send(.modeSelected($0)) }
                )
                .padding(.top, 16)
                .transition(reduceMotion ? .identity : .move(edge: .top).combined(with: .opacity))
            }

            if let suggestion = store.modeSuggestion {
                ModeIntelligenceBanner(
                    suggestion: suggestion,
                    onAccept: { store.send(.modeSuggestionAccepted) },
                    onDismiss: { store.send(.modeSuggestionDismissed) }
                )
                .padding(.horizontal, 16)
                .padding(.top, 12)
            }

            Spacer()

            // Timer Display (center) — capped at 280pt so it never inflates on iPad
            timerCircle
                .frame(maxWidth: 280, maxHeight: 280)
                .padding(.horizontal, 40)

            // Phase label
            Text(store.phaseLabel.uppercased())
                .font(.system(.subheadline, design: .rounded))
                .fontWeight(.bold)
                .tracking(2)
                .foregroundStyle(.secondary)
                .padding(.top, 16)

            // Linked task (only in single-column / iPhone layout — companion pane handles it on iPad)
            if sizeClass != .regular {
                if let taskTitle = store.linkedTaskTitle {
                    Button {
                        store.send(.taskPickerTapped)
                    } label: {
                        HStack(spacing: 8) {
                            if let emoji = store.linkedTaskEmoji {
                                Text(emoji)
                                    .font(.title3)
                            } else {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.subheadline)
                            }

                            Text(taskTitle)
                                .font(.callout.weight(.semibold))
                                .lineLimit(1)

                            Image(systemName: "chevron.down")
                                .font(.caption)
                        }
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .pepinilloGlass(cornerRadius: 16)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(String(localized: "Linked task: \(taskTitle). Tap to change or unlink."))
                    .padding(.top, 8)
                } else {
                    Button {
                        store.send(.taskPickerTapped)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "plus.circle.fill")
                                .font(.subheadline)
                            Text(String(localized: "Link Task"))
                                .font(.callout.weight(.medium))
                        }
                        .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(String(localized: "Link a task to this session"))
                    .padding(.top, 8)
                }
            }

            Spacer()

            // Custom duration for Time Block (only when idle)
            if !store.isRunning && store.selectedMode == .timeBlock {
                durationPicker
                    .padding(.bottom, 12)
                    .transition(.opacity)
            }

            // Controls (bottom) — start/pause/stop
            controlButtons
                .padding(.bottom, 24)

            // Soundscape shortcut
            HStack(spacing: 24) {
                Button {
                    store.send(.soundscapePickerTapped)
                } label: {
                    HStack(spacing: 8) {
                        Text(store.selectedSoundscape.emoji)
                            .font(.title3)
                        if store.selectedSoundscape != .none && store.isRunning {
                            AudioBarsView()
                                .frame(width: 16, height: 12)
                        }
                        Text(store.selectedSoundscape == .none
                             ? String(localized: "Sounds")
                             : store.selectedSoundscape.displayName)
                            .font(.subheadline.weight(.medium))
                    }
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .pepinilloGlass(cornerRadius: 20)
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 40)
            .padding(.bottom, 16)
        }
    }

    // MARK: - Timer Circle

    @ViewBuilder
    private var timerCircle: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(modeColor.opacity(0.15), lineWidth: 14)

            // Progress ring (only for countdown modes)
            if let progress = store.progress {
                Circle()
                    .trim(from: 0, to: CGFloat(progress))
                    .stroke(
                        modeGradient,
                        style: StrokeStyle(lineWidth: 14, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .conditionalAnimation(.linear(duration: 0.1), value: progress)
            }

            // Center content
            VStack(spacing: 8) {
                // Mode icon
                Text(store.modeIcon)
                    .font(.system(size: 40))

                // Time display
                Text(store.displayTime)
                    .font(.system(size: 64, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())

                // Pomodoro counter
                if store.activeMode == .pomodoro, let num = store.pomodoroNumber {
                    Text("\(num) / \(store.config.pomodorosPerCycle)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(timerAccessibilityLabel)
        .accessibilityValue(timerAccessibilityValue)
    }

    private var timerAccessibilityLabel: String {
        let mode = currentMode.displayName
        if store.isRunning {
            return store.isPaused
                ? String(localized: "\(mode) session paused")
                : String(localized: "\(mode) session in progress")
        }
        return String(localized: "\(mode) timer")
    }

    private var timerAccessibilityValue: String {
        var parts: [String] = [store.displayTime]
        if let progress = store.progress {
            parts.append(String(localized: "\(Int(progress * 100)) percent complete"))
        }
        if store.activeMode == .pomodoro, let num = store.pomodoroNumber {
            parts.append(String(localized: "Pomodoro \(num) of \(store.config.pomodorosPerCycle)"))
        }
        return parts.joined(separator: ", ")
    }

    // MARK: - Control Buttons

    @ViewBuilder
    private var controlButtons: some View {
        HStack(spacing: 32) {
            if store.isRunning {
                // Stop button
                Button {
                    showStopConfirmation = true
                } label: {
                    Image(systemName: "stop.fill")
                        .font(.title2)
                        .frame(width: 56, height: 56)
                        .pepinilloGlass(cornerRadius: 28)
                }
                .accessibilityLabel(String(localized: "Stop session"))

                // Pause / Resume
                Button {
                    if store.isPaused {
                        store.send(.resumeTapped)
                        HapticManager.selection()
                    } else {
                        store.send(.pauseTapped)
                        HapticManager.selection()
                    }
                } label: {
                    Image(systemName: store.isPaused ? "play.fill" : "pause.fill")
                        .font(.title)
                        .frame(width: 72, height: 72)
                        .foregroundStyle(.white)
                        .background(modeColor)
                        .clipShape(Circle())
                }
                .accessibilityLabel(store.isPaused ? String(localized: "Resume session") : String(localized: "Pause session"))

                // Skip phase (Pomodoro only — skip break)
                if store.activeMode == .pomodoro && store.phase.isBreak {
                    Button {
                        store.send(.skipPhaseTapped)
                    } label: {
                        Image(systemName: "forward.fill")
                            .font(.title2)
                            .frame(width: 56, height: 56)
                            .pepinilloGlass(cornerRadius: 28)
                    }
                    .accessibilityLabel(String(localized: "Skip to next phase"))
                }
            } else {
                // Start button — capped at 280pt so it stays modest on iPad
                Button {
                    store.send(.startTapped)
                    HapticManager.impact(.medium)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "play.fill")
                        Text(String(localized: "Start \(store.selectedMode.displayName)"))
                            .fontWeight(.semibold)
                    }
                    .font(.title3)
                    .foregroundStyle(.white)
                    .frame(maxWidth: 280)
                    .frame(height: 64)
                    .background(modeColor.gradient)
                    .clipShape(Capsule())
                    .shadow(color: modeColor.opacity(0.3), radius: 12, y: 6)
                }
                .buttonStyle(.pressable)
                .accessibilityHint(String(localized: "Double tap to start a focus session"))
            }
        }
    }

    // MARK: - Duration Picker (Time Block)

    @ViewBuilder
    private var durationPicker: some View {
        HStack {
            Text(String(localized: "Duration:"))
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Stepper(
                "\(store.customDurationMinutes) min",
                value: Binding(
                    get: { store.customDurationMinutes },
                    set: { store.send(.customDurationChanged($0)) }
                ),
                in: 5...480,
                step: 5
            )
            .font(.subheadline)
        }
        .padding(.horizontal, 40)
    }

    // MARK: - Mode Theming

    private var currentMode: FocusMode {
        store.activeMode ?? store.selectedMode
    }

    private var modeColor: Color {
        theme.color(for: currentMode, phase: store.phase)
    }

    private var modeGradient: AngularGradient {
        theme.ringGradient(for: currentMode, phase: store.phase)
    }
}

// MARK: - Audio Bars (animated playing indicator)

struct AudioBarsView: View {
    @State private var phase: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<3, id: \.self) { i in
                Capsule()
                    .fill(Color.secondary)
                    .frame(width: 3, height: reduceMotion ? barHeight(for: i) : barHeight(for: i))
                    .animation(
                        reduceMotion ? nil : .easeInOut(duration: 0.4)
                        .repeatForever()
                        .delay(Double(i) * 0.13),
                        value: phase
                    )
            }
        }
        .onAppear {
            if !reduceMotion {
                phase = 1
            }
        }
    }

    private func barHeight(for index: Int) -> CGFloat {
        if reduceMotion { return 6 }
        let heights: [CGFloat] = [6, 10, 4]
        return phase == 0 ? 3 : heights[index]
    }
}

// MARK: - Mode Picker

struct ModePickerView: View {
    let selectedMode: FocusMode
    let isProUser: Bool
    let onSelect: (FocusMode) -> Void
    @Namespace private var namespace

    var body: some View {
        HStack(spacing: 12) {
            ForEach(FocusMode.allCases) { mode in
                Button {
                    onSelect(mode)
                    HapticManager.selection()
                } label: {
                    VStack(spacing: 4) {
                        Text(mode.icon)
                            .font(.title2)
                        Text(mode.displayName)
                            .font(.caption2)
                            .fontWeight(selectedMode == mode ? .bold : .regular)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        ZStack {
                            if selectedMode == mode {
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.accentColor.opacity(0.12))
                                    .matchedGeometryEffect(id: "mode_bg", in: namespace)
                            } else {
                                Color.clear
                            }
                        }
                    )
                    .pepinilloGlass(cornerRadius: 16)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay {
                        if !mode.isFreeTier && !isProUser {
                            Image(systemName: "lock.fill")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                                .padding(6)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
    }
}
