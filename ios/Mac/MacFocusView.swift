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

    @State private var showStopConfirmation = false
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
        }
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
        .popover(isPresented: taskPickerPresented, arrowEdge: .bottom) {
            MacTaskPickerView(
                linkedTaskID: store.linkedTaskID,
                tasks: store.availableTasks,
                onSelectTask: { id, title, icon in
                    store.send(.linkTask(id, title, icon))
                },
                onUnlink: {
                    store.send(.unlinkTaskTapped)
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

            phaseSection
            linkedTaskChip
            primaryAction
            secondaryControls
                .animation(MotionTokens.snappy, value: store.isRunning)
            todayStats

            Spacer(minLength: 8)
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: geometry.size.height)
        .padding(.horizontal, 32)
        .padding(.vertical, 16)
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
        }
        .buttonStyle(.plain)
        .help(store.linkedTaskTitle == nil
              ? String(localized: "Link a task to this session")
              : String(localized: "Change or unlink the linked task"))
        .accessibilityLabel(store.linkedTaskTitle.map { String(localized: "Linked task: \($0)") } ?? String(localized: "Link a task"))
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

private struct MacTaskPickerView: View {
    let linkedTaskID: UUID?
    let tasks: IdentifiedArrayOf<TaskListFeature.TaskItemState>
    let onSelectTask: (UUID, String, String) -> Void
    let onUnlink: () -> Void

    @Environment(\.dismiss) private var dismiss

    private var activeTasks: [TaskListFeature.TaskItemState] {
        tasks.filter { !$0.isCompleted }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Link Task")
                    .font(.headline)
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(.link)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Divider()

            List {
                if linkedTaskID != nil {
                    Button(role: .destructive) {
                        onUnlink()
                        dismiss()
                    } label: {
                        Label("Unlink Task", systemImage: "xmark.circle")
                    }
                    .buttonStyle(.plain)
                }

                if activeTasks.isEmpty {
                    Text("No active tasks")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(activeTasks) { task in
                        Button {
                            HapticManager.selection()
                            onSelectTask(task.id, task.title, task.energyLevel.icon)
                            dismiss()
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: task.energyLevel.icon)
                                    .symbolRenderingMode(.hierarchical)
                                    .foregroundStyle(task.energyLevel.color)
                                    .frame(width: 22)
                                Text(task.title)
                                    .lineLimit(2)
                                Spacer()
                                if task.id == linkedTaskID {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(Color.accentColor)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(
                            task.title + (task.id == linkedTaskID
                                          ? String(localized: ", currently linked")
                                          : "")
                        )
                    }
                }
            }
            .listStyle(.inset)
        }
        .frame(width: 360, height: 420)
    }
}
