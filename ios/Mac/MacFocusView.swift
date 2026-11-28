// MacFocusView.swift
// Pepinillo — native macOS Focus stage

import SwiftUI
import ComposableArchitecture

struct MacFocusView: View {
    @Bindable var store: StoreOf<FocusFeature>
    let streakDays: Int
    let sessionsToday: Int
    let totalFocusMinutesToday: Int

    @Environment(\.appTheme) private var theme

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var showStopConfirmation = false
    /// Zen stage (issue #797): pinch on the stage or View ▸ Zen Mode hides
    /// the link-task chip and today stats. Shared with the menu command.
    @AppStorage(FocusZenMode.storageKey) private var isZen = false
    /// Soundscapes popover (issue #798). Local on purpose: the reducer's
    /// `showSoundscapePicker` closes on selection, the Mac popover stays
    /// open so volume and ambience can be adjusted together.
    @State private var showSoundscapes = false
    @Namespace private var glassNS

    private var currentMode: FocusMode {
        store.activeMode ?? store.selectedMode
    }

    private var effectivePhase: FocusPhase {
        store.isWaitingForNextPhase ? (store.pendingNextPhase ?? store.phase) : store.phase
    }

    private var modeColor: Color {
        theme.color(for: currentMode, phase: effectivePhase)
    }

    private var selectedModeBinding: Binding<FocusMode> {
        Binding(
            get: { store.selectedMode },
            set: { store.send(.modeSelected($0)) }
        )
    }

    private var taskPickerPresented: Binding<Bool> {
        Binding(
            get: { store.isTaskPickerPresented },
            set: { isPresented in
                if !isPresented {
                    store.send(.taskPickerDismissed)
                }
            }
        )
    }

    var body: some View {
        GeometryReader { geometry in
            let ringSize = min(360, max(260, geometry.size.height - 300))
            let timerFont: CGFloat = ringSize >= 380 ? 84 : 72

            ScrollView {
                // iOS-parity Liquid Glass (macOS 26+): one container scopes the
                // interactive glass elements (link chip, start capsule) so they
                // share the effect and can morph; macOS 15 renders plain.
                if #available(macOS 26.0, *) {
                    GlassEffectContainer(spacing: 16) {
                        focusColumn(ringSize: ringSize, timerFont: timerFont, geometry: geometry)
                    }
                } else {
                    focusColumn(ringSize: ringSize, timerFont: timerFont, geometry: geometry)
                }
            }
            .scrollIndicators(.hidden)
            // The stage is a fixed composition, not a document: when the
            // content fits the window there is nothing to scroll (issue
            // #851) — no elastic bounce for a wheel or a stray finger. Only
            // a genuinely too-short window still scrolls.
            .scrollBounceBehavior(.basedOnSize)
        }
        // Two-finger pinch toggles Zen on touch and trackpad alike; any
        // deliberate pinch counts, direction does not matter.
        .simultaneousGesture(
            MagnifyGesture().onEnded { value in
                guard abs(value.magnification - 1) >= FocusZenMode.pinchThreshold else { return }
                isZen.toggle()
            }
        )
        .toolbar {
            // While a session runs the toolbar stays empty (the stage carries
            // the controls), mirroring the system Clock app on macOS.
            if !store.isRunning {
                ToolbarItem(placement: .principal) {
                    Picker("Focus mode", selection: selectedModeBinding) {
                        ForEach(FocusMode.allCases) { mode in
                            Text(mode.macDisplayName).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .accessibilityLabel(String(localized: "Focus mode"))
                    .help(String(localized: "Switch focus mode"))
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .macFocusLinkTaskRequested)) { _ in
            // Issue #993 (S1-S2): ⌘K abre el picker con el buscador enfocado;
            // Return enlaza la primera coincidencia (comportamiento #929).
            store.send(.taskPickerTapped)
        }
        .popover(isPresented: taskPickerPresented, arrowEdge: .bottom) {
            MacTaskPickerView(
                linkedTaskID: store.linkedTaskID,
                tasks: store.availableTasks,
                onSelectTask: { id, title, icon in
                    store.send(.linkTask(id, title, icon))
                },
                onUnlink: {
                    store.send(.unlinkTaskTapped)
                },
                // Issue #993 (S3): ⌘↩ enlaza y, si no hay sesión corriendo,
                // arranca con la tarea enlazada. La colisión con el ítem de
                // menú Start/Pause (⌘↩) queda resuelta: el monitor local del
                // picker consume el evento antes de que el menú lo reciba.
                onLinkAndStart: {
                    guard !store.isRunning else { return }
                    store.send(.startTapped())
                }
            )
        }
        .sheet(item: $store.scope(state: \.journal, action: \.journal)) { journalStore in
            SessionJournalView(store: journalStore)
                .frame(minWidth: 440, minHeight: 520)
        }
        .confirmationDialog(
            String(localized: "focus.endsession.title", defaultValue: "End Session?"),
            isPresented: $showStopConfirmation,
            titleVisibility: .visible
        ) {
            Button(String(localized: "focus.endsession.button", defaultValue: "End Session"), role: .destructive) {
                store.send(.stopTapped)
            }
        }
        .alert(
            String(localized: "focus.sessionSaveError.title", defaultValue: "Couldn't Save Session"),
            isPresented: Binding(
                get: { store.sessionSaveError != nil },
                set: { if !$0 { store.send(.sessionSaveErrorDismissed) } }
            )
        ) {
            Button("OK", role: .cancel) { store.send(.sessionSaveErrorDismissed) }
        } message: {
            if let sessionSaveError = store.sessionSaveError {
                Text(String(localized: "focus.sessionSaveError.message", defaultValue: "Your focus time was completed but couldn't be saved. \(sessionSaveError)"))
            }
        }
    }

    private func focusColumn(
        ringSize: CGFloat,
        timerFont: CGFloat,
        geometry: GeometryProxy
    ) -> some View {
        VStack(spacing: 16) {
            Spacer(minLength: 8)

            TimerCircleView(store: store, timerFontSize: timerFont)
                .frame(width: ringSize, height: ringSize)
                .modifier(MacFocusRingTouch(store: store, ringSize: ringSize))

            phaseSection
            if !isZen {
                HStack(spacing: 10) {
                    linkedTaskChip
                    soundscapeChip
                }
                .transition(.opacity)
            }
            // Duration steppers flank Start on the configurable-duration
            // modes (Time Block, Pomodoro — issue #848), mirroring the iPhone
            // stage (issue #820 — focus engine parity invariant).
            HStack(spacing: 16) {
                if showsDurationSteppers {
                    durationStepButton(systemName: "minus", delta: -5)
                }
                primaryAction
                if showsDurationSteppers {
                    durationStepButton(systemName: "plus", delta: 5)
                }
            }
            .animation(MotionTokens.snappy, value: store.selectedMode)
            secondaryControls
                .animation(MotionTokens.snappy, value: store.isRunning)
            if !isZen {
                todayStats
                    .transition(.opacity)
            }

            Spacer(minLength: 8)
        }
        .animation(reduceMotion ? nil : MotionTokens.snappy, value: isZen)
        // Padding BEFORE the height frame: `minHeight` must cover the
        // paddings, or the stage always measures viewport + 32px and the
        // ScrollView keeps a permanent scrollable delta (issue #851).
        .padding(.horizontal, 32)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
        .frame(minHeight: geometry.size.height)
    }

    /// Mirrors the iPhone control row: Skip only where it applies (active
    /// Flowtime flow, or any break) and a destructive Stop with the same
    /// end-session confirmation.
    @ViewBuilder
    private var secondaryControls: some View {
        if store.isRunning && !store.isWaitingForNextPhase {
            HStack(spacing: 12) {
                if showsSkip {
                    Button {
                        store.send(.skipPhaseTapped)
                    } label: {
                        Label(
                            String(localized: "Skip phase"),
                            systemImage: skipIcon
                        )
                    }
                    .buttonStyle(.bordered)
                    .help(String(localized: "Skip to next phase"))
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                }

                Button(role: .destructive) {
                    showStopConfirmation = true
                } label: {
                    Label(
                        String(localized: "focus.endsession.button", defaultValue: "End Session"),
                        systemImage: "stop.fill"
                    )
                }
                .buttonStyle(.bordered)
                .help(String(localized: "Stop session"))
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
    }

    /// Skip visibility, matching the iPhone control row exactly.
    private var showsSkip: Bool {
        guard store.activeMode == .flowtime else {
            return store.phase.isBreak
        }
        return store.phase == .flow || store.phase.isBreak
    }

    private var skipIcon: String {
        store.activeMode == .flowtime && store.phase == .flow
            ? "cup.and.saucer.fill"
            : "forward.fill"
    }

    private var phaseSection: some View {
        VStack(spacing: 4) {
            Text(store.phaseLabel)
                .font(.subheadline.weight(.semibold))
                .tracking(1.1)
                .foregroundStyle(.secondary)

            if store.isWaitingForNextPhase, let pending = store.pendingNextPhase {
                Text("Next: \(pending.displayName)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .multilineTextAlignment(.center)
        .accessibilityElement(children: .combine)
    }

    private var linkedTaskChip: some View {
        Button {
            store.send(.taskPickerTapped)
        } label: {
            HStack(spacing: 6) {
                if let title = store.linkedTaskTitle {
                    Image(systemName: store.linkedTaskIcon ?? "checkmark.circle.fill")
                        .foregroundStyle(modeColor)
                    Text(title)
                        .lineLimit(1)
                    Image(systemName: "chevron.down")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } else {
                    Image(systemName: "plus.circle")
                    Text("Link Task")
                }
            }
            .font(.callout)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .adaptiveGlassCapsule(id: "link-task-chip", namespace: glassNS)
            // Touch target: the glass capsule keeps its compact visual; the
            // tappable rect grows to the 36 pt minimum (invisible, stage
            // space around the chip absorbs it).
            .frame(minHeight: TouchTargets.macMinimum)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(store.linkedTaskTitle == nil
              ? String(localized: "Link a task to this session")
              : String(localized: "Change or unlink the linked task"))
        .accessibilityLabel(store.linkedTaskTitle.map { String(localized: "Linked task: \($0)") } ?? String(localized: "Link a task"))
    }

    /// Soundscapes pill beside Link Task: names the current ambience and
    /// opens the popover. Same glass capsule and 36 pt touch rect as the
    /// link chip (guide R2).
    private var soundscapeChip: some View {
        Button {
            showSoundscapes = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: store.selectedSoundscape.systemImage)
                    .foregroundStyle(store.selectedSoundscape == .none ? Color.secondary : modeColor)
                Text(store.selectedSoundscape == .none
                     ? String(localized: "Soundscape")
                     : store.selectedSoundscape.displayName)
                    .lineLimit(1)
            }
            .font(.callout)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .adaptiveGlassCapsule(id: "soundscape-chip", namespace: glassNS)
            .frame(minHeight: TouchTargets.macMinimum)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(String(localized: "Choose an ambient soundscape"))
        .accessibilityLabel(String(localized: "Soundscape: \(store.selectedSoundscape.displayName)"))
        .popover(isPresented: $showSoundscapes, arrowEdge: .bottom) {
            MacSoundscapePopover(
                currentSoundscape: store.selectedSoundscape,
                volume: store.soundscapeVolume,
                isProUser: store.isProUser,
                onSelect: { store.send(.soundscapeSelected($0)) },
                onVolumeChange: { store.send(.soundscapeVolumeChanged($0)) },
                onNeedsPro: { store.send(.paywallTapped) }
            )
        }
    }

    @ViewBuilder
    private var primaryAction: some View {
        let label = Label(primaryActionTitle, systemImage: primaryActionSymbol)
            .frame(minWidth: 200, minHeight: 34)

        if #available(macOS 26.0, *) {
            // iOS-parity hero CTA: tinted Liquid Glass capsule in the mode
            // color, morphing inside the stage's GlassEffectContainer.
            Button {
                FocusToggleCommand.toggle(focusStore: store)
            } label: {
                label.primaryFocusActionGlass(tint: modeColor, namespace: glassNS)
            }
            .buttonStyle(.pressable)
            .keyboardShortcut(.defaultAction)
            .accessibilityHint(primaryActionHint)
        } else {
            Button {
                FocusToggleCommand.toggle(focusStore: store)
            } label: {
                label
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(modeColor)
            .keyboardShortcut(.defaultAction)
            .accessibilityHint(primaryActionHint)
        }
    }

    /// The ±5 step arms on the configurable-duration modes, idle only, the
    /// same gating as the touch dial on the ring (issue #848): Time Block
    /// (5…480, `customDurationChanged`) and Pomodoro (5…120,
    /// `pomodoroDurationChanged`). It hides once a session runs or the engine
    /// waits for the next phase, exactly where iOS shows its steppers.
    private var durationStep: (range: ClosedRange<Int>, current: Int, change: (Int) -> FocusFeature.Action)? {
        guard !store.isRunning, !store.isWaitingForNextPhase else { return nil }
        switch store.selectedMode {
        case .timeBlock:
            return (5...480, store.customDurationMinutes, FocusFeature.Action.customDurationChanged)
        case .pomodoro:
            return (5...120, Int((store.config.pomodoroDuration / 60).rounded()), FocusFeature.Action.pomodoroDurationChanged)
        default:
            return nil
        }
    }

    private var showsDurationSteppers: Bool {
        durationStep != nil
    }

    /// Same per-mode bounds, same reducer action and same a11y labels as
    /// `FocusView.durationStepButton` on iOS; sized for the Mac stage
    /// density with a 36pt touch rect (guide R2).
    @ViewBuilder
    private func durationStepButton(systemName: String, delta: Int) -> some View {
        if let step = durationStep {
            let projected = step.current + delta
            let isAtBoundary = projected < step.range.lowerBound || projected > step.range.upperBound
            Button {
                let target = step.current + delta
                guard step.range.contains(target) else { return }
                store.send(step.change(target))
            } label: {
                Image(systemName: systemName)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 44, height: 44)
                    .adaptiveGlassCircle(id: "duration-\(systemName)-button", namespace: glassNS)
                    .frame(minWidth: TouchTargets.macMinimum, minHeight: TouchTargets.macMinimum)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .opacity(isAtBoundary ? 0.4 : 1)
            .disabled(isAtBoundary)
            .help(delta < 0
                  ? String(localized: "Decrease duration by 5 minutes")
                  : String(localized: "Increase duration by 5 minutes"))
            .accessibilityLabel(delta < 0
                ? String(localized: "Decrease duration by 5 minutes")
                : String(localized: "Increase duration by 5 minutes"))
        }
    }

    private var todayStats: some View {
        HStack(spacing: 20) {
            stat(value: sessionsToday, label: sessionsToday == 1 ? "session" : "sessions")
            stat(value: totalFocusMinutesToday, label: "min")
            stat(value: streakDays, label: streakDays == 1 ? "day streak" : "days streak")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    private func stat(value: Int, label: LocalizedStringKey) -> some View {
        HStack(spacing: 4) {
            Text(value, format: .number)
                .font(.system(.caption, design: .rounded).weight(.semibold))
                .monospacedDigit()
            Text(label)
        }
        .accessibilityElement(children: .combine)
    }

    private var primaryActionTitle: String {
        switch FocusToggleCommand.decision(for: store.state) {
        case .start: return String(localized: "Start")
        case .pause: return String(localized: "Pause")
        case .resume: return String(localized: "Resume")
        case .nextPhase: return String(localized: "Start Next Phase")
        }
    }

    private var primaryActionSymbol: String {
        switch FocusToggleCommand.decision(for: store.state) {
        case .start, .resume, .nextPhase: return "play.fill"
        case .pause: return "pause.fill"
        }
    }

    private var primaryActionHint: String {
        switch FocusToggleCommand.decision(for: store.state) {
        case .start: return String(localized: "Start a focus session")
        case .pause: return String(localized: "Pause the current session")
        case .resume: return String(localized: "Resume the paused session")
        case .nextPhase: return String(localized: "Start the next focus or break phase")
        }
    }
}
