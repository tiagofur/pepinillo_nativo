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
    @Namespace private var glassNS
    // C6: breathe scale for emoji mode icon (SF Symbols use .symbolEffect, emojis use scaleEffect)
    @State private var breatheScale: CGFloat = 1.0

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
                        ipadLandscapeLayout(in: geo.size)
                    } else {
                        ipadPortraitLayout(in: geo.size)
                    }
                }
            } else {
                // MARK: - iPhone: single-column layout (existing behavior)
                focusCoreContainer
            }
        }
        .background(Color.clear)
        .scrollContentBackground(.hidden)
        .conditionalAnimation(.easeInOut(duration: 0.3), value: store.isRunning)
        .conditionalAnimation(.easeInOut(duration: 0.3), value: store.selectedMode)
        .conditionalAnimation(.easeInOut(duration: 0.2), value: store.selectedSoundscape)
        // Hidden buttons carry keyboard shortcuts for external keyboards / Mac
        .background {
            Group {
                Button("") {
                    if !store.isRunning { store.send(.startTapped()) }
                    else if store.isWaitingForNextPhase { store.send(.startNextPhaseTapped) }
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
            .focusMacSheetFrame(width: 440, height: 560)
            .pepinilloSheetStyle()
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
            .focusMacSheetFrame(width: 460, height: 560)
            .pepinilloSheetStyle()
        }
        .confirmationDialog(String(localized: "focus.endsession.title", defaultValue: "End Session?"), isPresented: $showStopConfirmation, titleVisibility: .visible) {
            Button(String(localized: "focus.endsession.button", defaultValue: "End Session"), role: .destructive) {
                store.send(.stopTapped)
                HapticManager.notification(.warning)
            }
        }
        .sheet(item: $store.scope(state: \.journal, action: \.journal)) { journalStore in
            SessionJournalView(store: journalStore)
                .pepinilloSheetStyle()
        }
    }

    // MARK: - iPad Portrait Layout (timer top, metrics bottom)

    @ViewBuilder
    private func ipadPortraitLayout(in size: CGSize) -> some View {
        VStack(spacing: 0) {
            // Top: Timer + controls — 55% of usable height, snug to the tab bar above
            focusCoreContainer
                .frame(maxWidth: 600)
                .frame(height: size.height * 0.55)
                .padding(.top, 4)

            // Separator
            Rectangle()
                .fill(.quaternary)
                .frame(height: 1)
                .padding(.horizontal, 32)
                .padding(.vertical, 12)

            // Bottom: Metrics cards in a 2-col adaptive grid — 40% remaining
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

    // MARK: - iPad Landscape Layout (mode chips header on top, two columns below)

    @ViewBuilder
    private func ipadLandscapeLayout(in size: CGSize) -> some View {
        VStack(spacing: 12) {
            modePickerHeader
                .frame(maxWidth: 720)
                .frame(maxWidth: .infinity)

            HStack(alignment: .top, spacing: 32) {
                landscapeFocusColumn
                    .frame(maxWidth: 540)
                    .frame(maxWidth: .infinity)

                FocusCompanionView(
                    store: store,
                    streakDays: streakDays,
                    sessionsToday: sessionsToday,
                    totalFocusMinutesToday: totalFocusMinutesToday
                )
                .frame(maxWidth: 380)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .contentMaxWidth()
    }

    @ViewBuilder
    private var landscapeFocusColumn: some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            GlassEffectContainer(spacing: 12) {
                focusCoreBody(timerMaxSize: 500)
            }
        } else {
            focusCoreBody(timerMaxSize: 500)
        }
    }

    // MARK: - Focus Core Container (wraps core column in GlassEffectContainer on iOS 26+)

    @ViewBuilder
    private var focusCoreContainer: some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            GlassEffectContainer(spacing: 12) {
                focusCoreColumn
            }
        } else {
            focusCoreColumn
        }
    }

    // MARK: - Focus Core Column (composed of mode picker header + body)

    @ViewBuilder
    private var focusCoreColumn: some View {
        VStack(spacing: 0) {
            modePickerHeader
            focusCoreBody(timerMaxSize: sizeClass == .regular ? 540 : 280)
        }
    }

    // MARK: - Mode Picker Header
    // Extracted so iPad landscape can render it as a top-of-screen header,
    // outside the timer column.

    @ViewBuilder
    private var modePickerHeader: some View {
        VStack(spacing: 0) {
            if !store.isRunning {
                ModePickerView(
                    selectedMode: store.selectedMode,
                    isProUser: store.isProUser,
                    onSelect: { store.send(.modeSelected($0)) },
                    glassNamespace: glassNS
                )
                .padding(.top, 4)
                .padding(.bottom, 32)
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
        }
    }

    // MARK: - Focus Core Body (timer + phase + controls + sounds, no header)

    @ViewBuilder
    private func focusCoreBody(timerMaxSize: CGFloat) -> some View {
        VStack(spacing: 0) {
            Spacer()

            // P2 item 2: Ambient radial glow behind the timer ring in light mode.
            // Matches the warmth dark mode already has from PepinilloLiquidBackground.
            // Uses ZStack overlay so the glow sits directly behind the ring.
            ZStack {
                FocusAmbientGlow(color: modeColor)

                timerCircle
                    .padding(.horizontal, 24)
            }
            .frame(maxWidth: timerMaxSize, maxHeight: timerMaxSize)
            .conditionalAnimation(.smooth(duration: 0.5), value: store.phase)

            Text(store.phaseLabel)
                .font(.system(.subheadline, design: .rounded))
                .fontWeight(.bold)
                .tracking(2)
                .foregroundStyle(.secondary)
                .padding(.top, 16)
                .id(store.phaseLabel)
                .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .bottom)))

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
                        .adaptiveGlassCapsule(id: "linked-task-button", namespace: glassNS)
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

            // Controls (bottom) — start/pause/stop (with ± duration flanking start in TimeBlock idle)
            controlButtons
                .padding(.horizontal, 16)
                .padding(.bottom, 24)

            // Soundscape shortcut stays compact-only; regular layouts use the companion card.
            if sizeClass != .regular {
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
                        .adaptiveGlassCapsule(id: "soundscape-button", namespace: glassNS)
                    }
                    .buttonStyle(.plain)
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 40)
                .padding(.bottom, 16)
            }
        }
    }

    // MARK: - Timer Circle

    // MARK: - Ring scale state (P2: spring on mode change)
    @State private var ringScale: CGFloat = 1.0

    @ViewBuilder
    private var timerCircle: some View {
        ZStack {
            // Background track ring — always visible, mode-tinted
            Circle()
                .stroke(modeColor.opacity(0.18), lineWidth: 13)

            // Count-up idle treatment: dashed tick overlay to signal "will fill".
            // lineCap .butt keeps dashes crisp; .round inflated the dash width to blobs.
            if currentMode.direction == .countUp && !(store.isRunning) {
                Circle()
                    .stroke(
                        modeColor.opacity(0.30),
                        style: StrokeStyle(lineWidth: 13, lineCap: .butt, dash: [4, 10])
                    )
            }

            // Progress arc — countdown: remaining arc; count-up: accruing arc while running
            if let ringProgress = timerRingProgress {
                Circle()
                    .trim(from: 0, to: CGFloat(ringProgress))
                    .stroke(
                        modeGradient,
                        style: StrokeStyle(lineWidth: 13, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .conditionalAnimation(.linear(duration: 0.1), value: ringProgress)
            }

            // Center content
            VStack(spacing: 4) {
                // Mode icon — smaller above digits, no overlap
                Text(store.modeIcon)
                    .font(.system(size: 28, design: .default))
                    .scaleEffect(breatheScale)
                    .conditionalAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: breatheScale)
                    .onChange(of: store.isRunning) { _, running in
                        breatheScale = running ? 1.06 : 1.0
                    }
                    .id(store.phase)
                    .transition(reduceMotion ? .opacity : .asymmetric(
                        insertion: .scale(scale: 0.7).combined(with: .opacity),
                        removal: .scale(scale: 1.3).combined(with: .opacity)
                    ))

                // Time display — dominant focal point
                Text(store.displayTime)
                    .font(NumericFont.timer())
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
        // P2 item 5: spring scale on mode change
        .scaleEffect(ringScale)
        .onChange(of: store.selectedMode) { _, _ in
            guard !reduceMotion else { return }
            withAnimation(MotionTokens.bouncy.speed(1.4)) {
                ringScale = 0.92
            }
            // Spring back after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                withAnimation(MotionTokens.bouncy) {
                    ringScale = 1.0
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(timerAccessibilityLabel)
        .accessibilityValue(timerAccessibilityValue)
    }

    // timerRingProgress:
    // • Countdown modes: fraction of time REMAINING (full at start → empty at zero)
    // • Count-up modes while running: derive a "minute-cycle" fill (resets each 60 min)
    //   so the ring is never an empty gray circle. A 4% display floor ensures a visible arc
    //   even at <2 min (raw progress would otherwise be a sub-pixel sliver).
    //   Floor applies ONLY while running and only when raw progress < floor.
    // • Count-up modes at rest: nil (dashed overlay handles the visual instead)
    private static let countUpRingDisplayFloor: Double = 0.04

    private var timerRingProgress: Double? {
        switch currentMode.direction {
        case .countDown:
            let completed = store.progress.map { min(max($0, 0), 1) } ?? 0
            return 1 - completed
        case .countUp:
            guard store.isRunning else { return nil }
            // Fill the ring as elapsed seconds progress within each 60-min cycle.
            // Cycle resets at 60 min so very long sessions remain readable.
            let elapsed = store.elapsedSeconds
            let cycle: Double = 60 * 60  // 1 hour
            let positionInCycle = elapsed.truncatingRemainder(dividingBy: cycle)
            let raw = min(positionInCycle / cycle, 1.0)
            // Apply display floor so the arc reads as "active" immediately on start.
            return max(raw, Self.countUpRingDisplayFloor)
        }
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
        if let ringProgress = timerRingProgress {
            let percentage = Int(ringProgress * 100)
            switch currentMode.direction {
            case .countDown:
                parts.append(String(localized: "\(percentage) percent remaining"))
            case .countUp:
                parts.append(String(localized: "\(percentage) percent complete"))
            }
        }
        if store.activeMode == .pomodoro, let num = store.pomodoroNumber {
            parts.append(String(localized: "Pomodoro \(num) of \(store.config.pomodorosPerCycle)"))
        }
        return parts.joined(separator: ", ")
    }

    // MARK: - Control Buttons

    @ViewBuilder
    private var controlButtons: some View {
        HStack(spacing: 12) {
            if store.isRunning && store.isWaitingForNextPhase {
                // Waiting-for-next-phase state: auto-start is OFF.
                // Show a stop button and a prominent CTA to start the next phase.
                Button {
                    showStopConfirmation = true
                } label: {
                    Image(systemName: "stop.fill")
                        .font(.title2)
                        .foregroundStyle(.white)
                        .frame(width: 56, height: 56)
                        .adaptiveGlassCircle(
                            id: "stop-button",
                            namespace: glassNS,
                            tint: .red,
                            tintOpacity: 0.50
                        )
                }
                .buttonStyle(.plain)
                .buttonBorderShape(.circle)
                .accessibilityLabel(String(localized: "Stop session"))

                Button {
                    store.send(.startNextPhaseTapped)
                    HapticManager.impact(.medium)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "play.fill")
                        Text(nextPhaseButtonLabel)
                            .fontWeight(.semibold)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .font(.title3)
                    .frame(maxWidth: 360)
                    .frame(minHeight: 64)
                    .primaryFocusActionGlass(tint: modeColor, namespace: glassNS)
                }
                .buttonStyle(.pressable)
                .accessibilityLabel(nextPhaseButtonLabel)
                .accessibilityHint(String(localized: "focus.waiting.cta.hint", defaultValue: "Double tap to start the next phase"))
            } else if store.isRunning {
                // Stop button — destructive action; red tint reads clearly in both
                // appearances and is consistent with the confirmation dialog that follows.
                Button {
                    showStopConfirmation = true
                } label: {
                    Image(systemName: "stop.fill")
                        .font(.title2)
                        .foregroundStyle(.white)
                        .frame(width: 56, height: 56)
                        .adaptiveGlassCircle(
                            id: "stop-button",
                            namespace: glassNS,
                            tint: .red,
                            tintOpacity: 0.50
                        )
                }
                .buttonStyle(.plain)
                .buttonBorderShape(.circle)
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
                        .contentTransition(.symbolEffect(.replace.byLayer))
                        .font(.title)
                        .frame(width: 72, height: 72)
                        .adaptiveGlassCircle(
                            id: "pause-resume-button",
                            namespace: glassNS,
                            tint: modeColor,
                            tintOpacity: 0.60,
                            foreground: .white
                        )
                }
                .buttonStyle(.plain)
                .buttonBorderShape(.circle)
                .accessibilityLabel(store.isPaused ? String(localized: "Resume session") : String(localized: "Pause session"))

                // Skip phase (Pomodoro only — skip break)
                if store.activeMode == .pomodoro && store.phase.isBreak {
                    Button {
                        store.send(.skipPhaseTapped)
                    } label: {
                        Image(systemName: "forward.fill")
                            .font(.title2)
                            .foregroundStyle(.primary)
                            .frame(width: 56, height: 56)
                            .adaptiveGlassCircle(id: "skip-button", namespace: glassNS)
                    }
                    .buttonStyle(.plain)
                    .buttonBorderShape(.circle)
                    .accessibilityLabel(String(localized: "Skip to next phase"))
                }
            } else {
                // − duration (TimeBlock only)
                if store.selectedMode == .timeBlock {
                    durationStepButton(systemName: "minus", delta: -5)
                        .transition(reduceMotion ? .opacity : .scale.combined(with: .opacity))
                }

                // Start button — capped at 280pt so it stays modest on iPad
                Button {
                    store.send(.startTapped())
                    HapticManager.impact(.medium)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "play.fill")
                        Text(String(localized: "Start \(store.selectedMode.displayName)"))
                            .fontWeight(.semibold)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .font(.title3)
                    .frame(maxWidth: 360)
                    .frame(minHeight: 64)
                    .primaryFocusActionGlass(tint: modeColor, namespace: glassNS)
                }
                .buttonStyle(.pressable)
                .accessibilityHint(String(localized: "Double tap to start a focus session"))

                // + duration (TimeBlock only)
                if store.selectedMode == .timeBlock {
                    durationStepButton(systemName: "plus", delta: 5)
                        .transition(reduceMotion ? .opacity : .scale.combined(with: .opacity))
                }
            }
        }
    }

    // MARK: - Duration Step Button (TimeBlock idle, flanks Start)

    @ViewBuilder
    private func durationStepButton(systemName: String, delta: Int) -> some View {
        let projected = store.customDurationMinutes + delta
        let isAtBoundary = projected < 5 || projected > 480
        Button {
            let target = store.customDurationMinutes + delta
            guard target >= 5, target <= 480 else { return }
            store.send(.customDurationChanged(target))
            HapticManager.selection()
        } label: {
            Image(systemName: systemName)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)
                .frame(width: 56, height: 56)
                .adaptiveGlassCircle(id: "duration-\(systemName)-button", namespace: glassNS)
        }
        .buttonStyle(.plain)
        .buttonBorderShape(.circle)
        .opacity(isAtBoundary ? 0.4 : 1)
        .disabled(isAtBoundary)
        .accessibilityLabel(delta < 0
            ? String(localized: "Decrease duration by 5 minutes")
            : String(localized: "Increase duration by 5 minutes"))
    }

    // MARK: - Waiting-for-next-phase CTA label

    /// The button label shown when the engine is holding between phases.
    /// Mirrors the phrasing already used in the idle start button and phase labels.
    private var nextPhaseButtonLabel: String {
        switch store.pendingNextPhase {
        case .shortBreak:
            return String(localized: "focus.waiting.start.shortbreak", defaultValue: "Start break")
        case .longBreak:
            return String(localized: "focus.waiting.start.longbreak", defaultValue: "Start long break")
        case .work, .flow, .block, .freeform:
            return String(localized: "focus.waiting.start.work", defaultValue: "Start focus")
        default:
            return String(localized: "focus.waiting.start.work", defaultValue: "Start focus")
        }
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

private extension View {
    @ViewBuilder
    func focusMacSheetFrame(width: CGFloat, height: CGFloat) -> some View {
        #if os(macOS)
        self.frame(minWidth: width, minHeight: height)
        #else
        self
        #endif
    }
}

// MARK: - Focus Ambient Glow (P2 item 2)
// Subtle radial gradient that bleeds the active mode color behind the timer ring
// in light mode. In dark mode the PepinilloLiquidBackground already provides warmth,
// so we keep opacity very low there to avoid fighting it.

private struct FocusAmbientGlow: View {
    let color: Color
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            // Light mode: 7% center opacity; dark mode: 4% (existing mesh handles the rest)
            let opacity = colorScheme == .dark ? 0.04 : 0.07
            if !reduceTransparency {
                RadialGradient(
                    gradient: Gradient(colors: [
                        color.opacity(opacity),
                        color.opacity(0)
                    ]),
                    center: .center,
                    startRadius: 0,
                    endRadius: min(size * 0.5, 280)
                )
                .frame(width: size, height: size)
                .position(x: geo.size.width / 2, y: geo.size.height / 2)
                .allowsHitTesting(false)
            }
        }
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

// MARK: - Mode Picker (P2 item 3)
// Compact glass pills sitting directly on the background — no outer card container.
// Selected pill gets the mode accent tint; unselected pills are plain glass.
// Icons: all emoji for a warm, coherent personality (🍅🌊📦⏱️).

struct ModePickerView: View {
    let selectedMode: FocusMode
    let isProUser: Bool
    let onSelect: (FocusMode) -> Void
    var glassNamespace: Namespace.ID? = nil
    @Environment(\.appTheme) private var theme
    @Namespace private var namespace

    var body: some View {
        HStack(spacing: 6) {
            ForEach(FocusMode.allCases) { mode in
                let isSelected = selectedMode == mode
                let modeAccent = theme.color(for: mode)

                Button {
                    onSelect(mode)
                    HapticManager.selection()
                } label: {
                    VStack(spacing: 3) {
                        Text(mode.icon)
                            .font(.system(size: 18))
                        Text(mode.displayName)
                            .font(.system(size: 10, weight: isSelected ? .semibold : .regular))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 4)
                    .foregroundStyle(isSelected ? modeAccent : .secondary)
                    .modePillBackground(
                        mode: mode,
                        isSelected: isSelected,
                        accent: modeAccent,
                        glassNamespace: glassNamespace,
                        matchNamespace: namespace
                    )
                    .overlay(alignment: .topTrailing) {
                        if !mode.isFreeTier && !isProUser {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(.secondary)
                                .offset(x: 2, y: -2)
                        }
                    }
                }
                .buttonStyle(.pressable)
                .accessibilityLabel(mode.displayName)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(.horizontal, 16)
    }
}

// MARK: - Mode pill glass helper (P2 item 3)

private extension View {
    // P2 item 3: pill background for the mode selector.
    // Selected: accent-tinted glass / material. Unselected: plain glass / ultraThin.
    @ViewBuilder
    func modePillBackground(
        mode: FocusMode,
        isSelected: Bool,
        accent: Color,
        glassNamespace: Namespace.ID?,
        matchNamespace: Namespace.ID
    ) -> some View {
        let cornerRadius = GlassCornerRadius.card
        if #available(iOS 26.0, macOS 26.0, *), let ns = glassNamespace {
            self
                .glassEffect(
                    .regular
                        .interactive(true)
                        .tint(isSelected ? accent.opacity(0.35) : .clear),
                    in: .rect(cornerRadius: cornerRadius)
                )
                .glassEffectID("mode-pill-\(mode.id)", in: ns)
        } else {
            // iOS 17-25: tinted material for selected, plain rounded rect for unselected
            if isSelected {
                self
                    .background(
                        ZStack {
                            RoundedRectangle(cornerRadius: cornerRadius)
                                .fill(accent.opacity(0.15))
                                .matchedGeometryEffect(id: "mode_pill_bg", in: matchNamespace)
                            RoundedRectangle(cornerRadius: cornerRadius)
                                .fill(.ultraThinMaterial)
                        }
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(accent.opacity(0.35), lineWidth: 1)
                    }
            } else {
                self.background(
                    .ultraThinMaterial,
                    in: RoundedRectangle(cornerRadius: cornerRadius)
                )
            }
        }
    }

    // P2 item 1: Solid mode-accent CTA — confident fill on both iOS generations.
    // iOS 26: tinted glass at 0.72 opacity so the mode color reads strongly
    //         over the liquid glass system while preserving the glass language.
    // iOS 17-25: solid gradient fill with drop shadow (pre-existing pattern).
    @ViewBuilder
    func primaryFocusActionGlass(tint: Color, namespace: Namespace.ID) -> some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            self
                .foregroundStyle(.white)
                .glassEffect(
                    .regular
                        .interactive(true)
                        .tint(tint.opacity(0.72)),
                    in: .capsule
                )
                .glassEffectID("start-button", in: namespace)
                .overlay {
                    Capsule()
                        .stroke(.white.opacity(0.22), lineWidth: 1)
                }
        } else {
            self
                .foregroundStyle(.white)
                .background(tint.gradient)
                .clipShape(Capsule())
                .shadow(color: tint.opacity(0.35), radius: 14, y: 7)
        }
    }
}
