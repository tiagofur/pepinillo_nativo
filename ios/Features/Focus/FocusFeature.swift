// FocusFeature.swift
// Pepinillo — Deep Work Companion for Apple
//
// TCA Reducer that orchestrates the Focus UI.
// Connects user actions → FocusClient (actor-based engine) → UI state updates.
// Engine events arrive via AsyncStream and drive all timer display updates.

import Foundation
import ComposableArchitecture
import AppIntents
import WidgetKit
#if os(iOS)
import UIKit
#endif

@Reducer
struct FocusFeature {

    // MARK: - State

    @ObservableState
    struct State: Equatable {
        // Mode selection
        var selectedMode: FocusMode = .pomodoro
        var availableModes: [FocusMode] = FocusMode.allCases

        // Active session
        var isRunning: Bool = false
        var isPaused: Bool = false
        var activeMode: FocusMode?
        var phase: FocusPhase = .idle
        var elapsedSeconds: TimeInterval = 0
        var remainingSeconds: TimeInterval?
        var progress: Double?
        var pomodoroNumber: Int?
        var interruptions: Int = 0

        // Display
        var displayTime: String = "25:00"
        var phaseLabel: String = String(localized: "Ready")
        var modeIcon: String = "🍅"

        // Task linking
        var linkedTaskID: UUID?
        var linkedTaskTitle: String?

        // Configuration
        var config: FocusConfig = .default

        // Soundscape
        var selectedSoundscape: Soundscape = .none
        var soundscapeVolume: Float = 0.5
        var showSoundscapePicker: Bool = false

        // Task picker
        var isTaskPickerPresented: Bool = false
        var availableTasks: IdentifiedArrayOf<TaskListFeature.TaskItemState> = []

        // UI
        var showModeInfo: Bool = false
        var showSettings: Bool = false
        var showPaywall: Bool = false
        var isProUser: Bool = false

        // Custom duration (Time Block)
        var customDurationMinutes: Int = 60

        // Mode Intelligence
        var modeSuggestion: ModeSuggestion?

        // Post-session journal
        @Presents var journal: SessionJournalFeature.State?
    }

    // MARK: - Actions

    enum Action: Equatable {
        // User interactions
        case modeSelected(FocusMode)
        case startTapped
        case pauseTapped
        case resumeTapped
        case stopTapped
        case skipPhaseTapped
        case linkTask(UUID?, String?)
        case customDurationChanged(Int)
        case configUpdated(FocusConfig)

        // Task picker
        case taskPickerTapped
        case taskPickerDismissed
        case unlinkTaskTapped

        // Soundscape
        case soundscapePickerTapped
        case soundscapePickerDismissed
        case soundscapeSelected(Soundscape)
        case soundscapeVolumeChanged(Float)

        // Engine events (dispatched from the observation effect)
        case timerTicked(FocusSessionState)
        case phaseCompleted(FocusPhase)
        case sessionCompleted(FocusSessionResult)
        case breakSuggested(TimeInterval)
        case midpointReached
        case interrupted

        // Navigation
        case modeInfoTapped
        case modeInfoDismissed
        case settingsTapped
        case settingsDismissed
        case paywallTapped
        case paywallDismissed

        // Mode Intelligence
        case modeSuggested(ModeSuggestion?)
        case modeSuggestionAccepted
        case modeSuggestionDismissed

        // Post-session journal
        case showJournalSheet(sessionID: UUID, modeName: String, actualDuration: TimeInterval)
        case journal(PresentationAction<SessionJournalFeature.Action>)
    }

    // MARK: - Dependencies

    @Dependency(\.focusClient) var focusClient
    @Dependency(\.persistenceClient) var persistence
    @Dependency(\.liveActivityClient) var liveActivity
    @Dependency(\.soundscapeClient) var soundscapeClient
    @Dependency(\.notificationClient) var notificationClient
    @Dependency(\.healthClient) var healthClient
    @Dependency(\.calendarClient) var calendarClient
    @Dependency(\.uuid) var uuid

    // Cancellation ID for the engine observation task
    private enum CancelID { case engineObservation }

    // MARK: - Reducer Body

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {

            // MARK: Mode Selection

            case .modeSelected(let mode):
                guard !state.isRunning else { return .none }
                if !mode.isFreeTier && !state.isProUser {
                    state.showPaywall = true
                    return .none
                }
                state.selectedMode = mode
                state.modeIcon = mode.icon
                updateIdleDisplay(&state)
                return .none

            // MARK: Session Control

            case .startTapped:
                guard !state.isRunning else { return .none }
                state.isRunning = true
                state.isPaused = false
                state.activeMode = state.selectedMode

                // Signal extensions that a session is active
                AppGroupDefaults.isSessionActive = true
                AppGroupDefaults.activeModeName = state.selectedMode.rawValue
                AppGroupDefaults.activeSessionElapsed = 0
                AppGroupDefaults.activeSessionRemaining = nil
                AppGroupDefaults.activeSessionPhase = nil
                AppGroupDefaults.activeSessionProgress = nil
                AppGroupDefaults.activeSessionPomodoroNumber = state.selectedMode == .pomodoro ? 1 : nil
                AppGroupDefaults.activeSessionTotalPomodoros = state.selectedMode == .pomodoro ? state.config.pomodorosPerCycle : nil
                AppGroupDefaults.activeSessionTaskTitle = state.linkedTaskTitle
                AppGroupDefaults.activeSessionIsPaused = false
                AppGroupDefaults.activeTaskID = state.linkedTaskID?.uuidString
                AppGroupDefaults.activeSessionTimerStart = Date.now
                if let target = state.selectedMode.strategy.targetDuration(config: state.config, phase: state.selectedMode.strategy.initialPhase(config: state.config)) {
                    AppGroupDefaults.activeSessionTimerEnd = Date.now.addingTimeInterval(target)
                } else {
                    AppGroupDefaults.activeSessionTimerEnd = nil
                }

                let initialPhase = state.selectedMode.strategy.initialPhase(config: state.config)
                state.phase = initialPhase
                state.elapsedSeconds = 0

                // Set pomodoroNumber for Pomodoro mode — will be updated from DB in the effect below
                if state.selectedMode == .pomodoro, case .work(_, _) = initialPhase {
                    // Temporary value; the real count is loaded from DB in the start effect
                    state.pomodoroNumber = state.pomodoroNumber ?? 1
                } else {
                    state.pomodoroNumber = nil
                }

                let mode = state.selectedMode
                let config = state.config
                let taskID = state.linkedTaskID
                let customDuration: TimeInterval? = mode == .timeBlock
                    ? TimeInterval(state.customDurationMinutes * 60)
                    : nil

                updateDisplayFromPhase(&state)

                // Notify widgets immediately that a session has started
                WidgetCenter.shared.reloadAllTimelines()

                let linkedTitle = state.linkedTaskTitle

                let soundscape = state.selectedSoundscape
                let soundscapeVolume = state.soundscapeVolume

                return .merge(
                    // Load today's completed pomodoro work sessions from DB
                    // so the engine starts with the correct cycle position
                    .run { [persistence] send in
                        if mode == .pomodoro {
                            let startOfDay = Calendar.current.startOfDay(for: Date.now)
                            let sessions = try await persistence.fetchSessions(startOfDay, Date.now)
                            let pomodoroWorkCount = sessions.filter {
                                $0.mode == "pomodoro" && ($0.taskID != nil || true)
                            }.count
                            // Update state via a tick — the engine will pick this up
                            // We store the DB-derived count for display
                            await send(.timerTicked(FocusSessionState(
                                id: UUID(),
                                mode: .pomodoro,
                                phase: .work(number: pomodoroWorkCount + 1, total: config.pomodorosPerCycle),
                                startedAt: Date.now,
                                pomodoroNumber: pomodoroWorkCount + 1,
                                totalPomodoros: config.pomodorosPerCycle
                            )))
                        }
                    },
                    // Start engine, then observe its events.
                    // These MUST be sequential: start() creates a fresh AsyncStream,
                    // and events() must read it after start() completes.
                    .run { [focusClient] send in
                        await focusClient.start(mode, config, taskID, customDuration)
                        let stream = await focusClient.events()
                        for await event in stream {
                            switch event {
                            case .tick(let sessionState):         await send(.timerTicked(sessionState))
                            case .phaseCompleted(let phase):      await send(.phaseCompleted(phase))
                            case .sessionCompleted(let result):   await send(.sessionCompleted(result))
                            case .breakSuggested(let duration):   await send(.breakSuggested(duration))
                            case .midpointReached:                await send(.midpointReached)
                            case .interrupted:                    await send(.interrupted)
                            }
                        }
                    }
                    .cancellable(id: CancelID.engineObservation, cancelInFlight: true),
                    // Start Live Activity if available
                    .run { [focusClient, liveActivity] _ in
                        guard liveActivity.isAvailable() else { return }
                        let snapshot = await focusClient.currentState()
                        if let s = snapshot {
                            await liveActivity.start(s, linkedTitle)
                        }
                    },
                    // Start soundscape
                    .run { [soundscapeClient] _ in
                        await soundscapeClient.play(soundscape, soundscapeVolume)
                    },
                    // Create calendar event if enabled (non-critical, errors silently ignored)
                    .run { [calendarClient, persistence] _ in
                        guard let prefs = try? await persistence.fetchPreferences(),
                              prefs.calendarIntegrationEnabled,
                              calendarClient.isAuthorized() else { return }
                        let title = linkedTitle ?? mode.displayName
                        let durationMinutes: Int
                        if let custom = customDuration {
                            durationMinutes = Int(custom / 60)
                        } else if let target = mode.strategy.targetDuration(config: config, phase: mode.strategy.initialPhase(config: config)) {
                            durationMinutes = Int(target / 60)
                        } else {
                            durationMinutes = 60 // default for open-ended modes
                        }
                        try? await calendarClient.createFocusEvent(title, Date.now, durationMinutes, mode.rawValue)
                    }
                )

            case .pauseTapped:
                guard state.isRunning, !state.isPaused else { return .none }
                state.isPaused = true
                state.phaseLabel = FocusPhase.paused.displayName
                AppGroupDefaults.activeSessionIsPaused = true
                WidgetCenter.shared.reloadTimelines(ofKind: "FocusHomeScreenWidget")
                WidgetCenter.shared.reloadTimelines(ofKind: "FocusLockScreenWidget")
                let taskTitle = state.linkedTaskTitle
                return .merge(
                    .run { _ in await focusClient.pause() },
                    .run { [liveActivity] _ in
                        let s = await focusClient.currentState()
                        if let s { await liveActivity.update(s, taskTitle) }
                    }
                )

            case .resumeTapped:
                guard state.isRunning, state.isPaused else { return .none }
                state.isPaused = false
                // Don't update phaseLabel here — the engine's next tick (within 100ms)
                // will set the correct restored phase. Setting it now would briefly
                // show "Paused" since state.phase is still .paused from the last tick.
                AppGroupDefaults.activeSessionIsPaused = false
                WidgetCenter.shared.reloadTimelines(ofKind: "FocusHomeScreenWidget")
                WidgetCenter.shared.reloadTimelines(ofKind: "FocusLockScreenWidget")
                let taskTitle = state.linkedTaskTitle
                return .merge(
                    .run { _ in await focusClient.resume() },
                    .run { [liveActivity] _ in
                        let s = await focusClient.currentState()
                        if let s { await liveActivity.update(s, taskTitle) }
                    }
                )

            case .stopTapped:
                let wasRunning = state.isRunning
                resetState(&state)
                guard wasRunning else { return .none }
                return .merge(
                    .run { _ in await focusClient.stop(false) },
                    .run { [liveActivity] _ in await liveActivity.end(false) },
                    .run { [soundscapeClient] _ in await soundscapeClient.fadeOut() },
                    .run { [notificationClient] _ in await notificationClient.clearActiveSession() },
                    .run { _ in WidgetCenter.shared.reloadAllTimelines() },
                    .cancel(id: CancelID.engineObservation)
                )

            case .skipPhaseTapped:
                return .run { _ in await focusClient.skipPhase() }

            // MARK: Task Linking

            case .linkTask(let id, let title):
                state.linkedTaskID = id
                state.linkedTaskTitle = title
                state.modeSuggestion = nil
                AppGroupDefaults.activeTaskID = id?.uuidString
                AppGroupDefaults.activeSessionTaskTitle = title
                guard let taskID = id, !state.isRunning else { return .none }
                // Query Mode Intelligence for a suggestion
                return .run { [persistence] send in
                    let calendar = Calendar.current
                    let end = Date.now
                    guard let start = calendar.date(byAdding: .day, value: -30, to: end) else {
                        await send(.modeSuggested(nil))
                        return
                    }
                    let sessions = try await persistence.fetchSessions(start, end)
                    let service = ModeIntelligenceService()
                    let suggestion = service.suggestMode(forTaskID: taskID, sessions: sessions)
                    await send(.modeSuggested(suggestion))
                }

            case .customDurationChanged(let minutes):
                state.customDurationMinutes = max(1, min(480, minutes))
                var config = state.config
                config.defaultBlockDuration = TimeInterval(state.customDurationMinutes * 60)
                state.config = config
                updateIdleDisplay(&state)
                return .none

            case .configUpdated(let config):
                state.config = config
                if !state.isRunning {
                    updateIdleDisplay(&state)
                }
                return .none

            // MARK: Engine Event Handlers

            case .timerTicked(let sessionState):
                state.elapsedSeconds = sessionState.elapsedSeconds
                state.remainingSeconds = sessionState.remainingSeconds
                state.progress = sessionState.progress
                state.phase = sessionState.phase
                state.pomodoroNumber = sessionState.pomodoroNumber

                if !state.isPaused {
                    state.phaseLabel = sessionState.phase.displayName
                }

                // Update timer display
                let mode = state.activeMode ?? state.selectedMode
                switch mode.direction {
                case .countDown:
                    if let remaining = sessionState.remainingSeconds {
                        state.displayTime = formatTime(remaining)
                    }
                case .countUp:
                    state.displayTime = formatTime(sessionState.elapsedSeconds)
                }

                let elapsed = Int(sessionState.elapsedSeconds)
                let taskTitle = state.linkedTaskTitle

                // Write live session state to AppGroupDefaults for widgets
                AppGroupDefaults.activeSessionElapsed = elapsed
                AppGroupDefaults.activeSessionRemaining = sessionState.remainingSeconds.map(Int.init)
                AppGroupDefaults.activeSessionPhase = state.phaseLabel
                AppGroupDefaults.activeSessionProgress = sessionState.progress
                AppGroupDefaults.activeSessionPomodoroNumber = sessionState.pomodoroNumber
                AppGroupDefaults.activeSessionTotalPomodoros = sessionState.totalPomodoros
                AppGroupDefaults.activeSessionTaskTitle = taskTitle

                // Update Live Activity + notification (notification every 30s)
                let displayTime = state.displayTime
                let modeName = mode.rawValue
                let phaseLabel = state.phaseLabel
                let shouldUpdateNotification = elapsed > 0 && elapsed % 30 == 0
                return .run { [liveActivity, notificationClient] _ in
                    await liveActivity.update(sessionState, taskTitle)
                    if shouldUpdateNotification {
                        await notificationClient.updateActiveSession(displayTime, modeName, phaseLabel)
                    }
                }


            case .phaseCompleted(let completedPhase):
                // Engine handles phase transition automatically;
                // we'll get updated state via the next .timerTicked.
                let hapticEnabled = state.config.hapticEnabled
                let taskTitle = state.linkedTaskTitle

                // Update widget timer dates for the new phase
                let mode = state.activeMode ?? state.selectedMode
                let config = state.config
                let nextPhase = mode.strategy.nextPhase(after: completedPhase, elapsed: 0, config: config)
                if let nextPhase, let target = mode.strategy.targetDuration(config: config, phase: nextPhase) {
                    AppGroupDefaults.activeSessionTimerStart = Date.now
                    AppGroupDefaults.activeSessionTimerEnd = Date.now.addingTimeInterval(target)
                    AppGroupDefaults.activeSessionPhase = nextPhase.displayName
                } else {
                    AppGroupDefaults.activeSessionTimerStart = Date.now
                    AppGroupDefaults.activeSessionTimerEnd = nil
                    AppGroupDefaults.activeSessionPhase = nextPhase?.displayName
                }
                WidgetCenter.shared.reloadTimelines(ofKind: "FocusHomeScreenWidget")
                WidgetCenter.shared.reloadTimelines(ofKind: "FocusLockScreenWidget")

                // For Pomodoro work phases, send a phase-end notification
                var phaseNotificationEffect: Effect<Action> = .none
                if case .work(let number, let total) = completedPhase {
                    let isLongBreak = number >= total
                    phaseNotificationEffect = .run { [notificationClient] _ in
                        await notificationClient.scheduleWorkPhaseEnd(number, isLongBreak, taskTitle)
                    }
                }

                return .merge(
                    .run { _ in
                        guard hapticEnabled else { return }
                        #if os(iOS)
                        await MainActor.run {
                            let generator = UINotificationFeedbackGenerator()
                            generator.notificationOccurred(.success)
                        }
                        #endif
                    },
                    phaseNotificationEffect
                )

            case .sessionCompleted(let result):
                let modeName = result.mode.rawValue
                let taskTitle = state.linkedTaskTitle
                let wasCompleted = result.wasCompleted
                let sessionID = result.id
                let actualDuration = result.actualDuration
                resetState(&state)

                return .merge(
                    // Check preference and present journal sheet if enabled
                    .run { [persistence] send in
                        if wasCompleted {
                            let prefs = try await persistence.fetchPreferences()
                            if prefs.showJournalAfterSession {
                                await send(.showJournalSheet(
                                    sessionID: sessionID,
                                    modeName: modeName,
                                    actualDuration: actualDuration
                                ))
                            }
                        }
                    },
                    .cancel(id: CancelID.engineObservation),
                    .run { [liveActivity] _ in await liveActivity.end(true) },
                    .run { [soundscapeClient] _ in await soundscapeClient.fadeOut() },
                    .run { [notificationClient] _ in await notificationClient.clearActiveSession() },
                    .run { _ in try await persistence.saveSession(result) },
                    .run { [notificationClient] _ in
                        await notificationClient.scheduleSessionComplete(modeName, taskTitle)
                    },
                    // Log to Apple Health if enabled
                    .run { [healthClient, persistence] _ in
                        let prefs = try await persistence.fetchPreferences()
                        guard prefs.healthLoggingEnabled, healthClient.isAuthorized() else { return }
                        try await healthClient.logMindfulMinutes(
                            result.startedAt,
                            result.endedAt
                        )
                    },
                    // Refresh widgets with updated stats
                    .run { _ in WidgetCenter.shared.reloadAllTimelines() },
                    // Donate intent for Siri Suggestions
                    .run { _ in
                        let intent = StartFocusIntent()
                        if let mode = FocusModeEntity.allModes.first(where: { $0.id == modeName }) {
                            intent.mode = mode
                        }
                        _ = try? await intent.donate()
                    }
                )

            case .breakSuggested(let duration):
                let minutes = Int(duration / 60)
                state.phaseLabel = String(localized: "Break suggested: \(minutes) min")
                return .none

            case .midpointReached:
                state.phaseLabel = String(localized: "Halfway there!")
                return .none

            case .interrupted:
                state.interruptions += 1
                return .none

            // MARK: Task Picker

            case .taskPickerTapped:
                state.isTaskPickerPresented = true
                return .none

            case .taskPickerDismissed:
                state.isTaskPickerPresented = false
                return .none

            case .unlinkTaskTapped:
                state.isTaskPickerPresented = false
                return .send(.linkTask(nil, nil))

            // MARK: Soundscape

            case .soundscapePickerTapped:
                state.showSoundscapePicker = true
                return .none

            case .soundscapePickerDismissed:
                state.showSoundscapePicker = false
                return .none

            case .soundscapeSelected(let soundscape):
                state.selectedSoundscape = soundscape
                state.showSoundscapePicker = false
                if state.isRunning {
                    let volume = state.soundscapeVolume
                    return .run { [soundscapeClient] _ in
                        await soundscapeClient.play(soundscape, volume)
                    }
                }
                return .none

            case .soundscapeVolumeChanged(let volume):
                state.soundscapeVolume = max(0, min(1, volume))
                if state.isRunning && state.selectedSoundscape != .none {
                    let v = state.soundscapeVolume
                    return .run { [soundscapeClient] _ in
                        await soundscapeClient.setVolume(v)
                    }
                }
                return .none

            // MARK: Navigation

            case .modeInfoTapped:
                state.showModeInfo = true
                return .none

            case .modeInfoDismissed:
                state.showModeInfo = false
                return .none

            case .settingsTapped:
                state.showSettings = true
                return .none

            case .settingsDismissed:
                state.showSettings = false
                return .none

            case .paywallTapped:
                state.showPaywall = true
                return .none

            case .paywallDismissed:
                state.showPaywall = false
                return .none

            // MARK: Mode Intelligence

            case .modeSuggested(let suggestion):
                state.modeSuggestion = suggestion
                return .none

            case .modeSuggestionAccepted:
                if let mode = state.modeSuggestion?.suggestedMode {
                    state.selectedMode = mode
                    state.modeIcon = mode.icon
                    updateIdleDisplay(&state)
                }
                state.modeSuggestion = nil
                return .none

            case .modeSuggestionDismissed:
                state.modeSuggestion = nil
                return .none

            // MARK: Journal

            case .showJournalSheet(let sessionID, let modeName, let actualDuration):
                let minutes = Int(actualDuration) / 60
                let seconds = Int(actualDuration) % 60
                state.journal = SessionJournalFeature.State(
                    sessionID: sessionID,
                    modeName: modeName,
                    durationFormatted: String(format: "%d:%02d", minutes, seconds)
                )
                return .none

            case .journal(.presented(.saved)):
                state.journal = nil
                return .none

            case .journal:
                return .none
            }
        }
        .ifLet(\.$journal, action: \.journal) {
            SessionJournalFeature()
        }
    }

    // MARK: - Helpers

    private func updateIdleDisplay(_ state: inout State) {
        let strategy = state.selectedMode.strategy
        let phase = strategy.initialPhase(config: state.config)
        state.phase = phase
        state.modeIcon = state.selectedMode.icon
        state.phaseLabel = FocusPhase.idle.displayName

        if let target = strategy.targetDuration(config: state.config, phase: phase) {
            state.displayTime = formatTime(target)
            state.remainingSeconds = target
        } else {
            state.displayTime = "0:00"
            state.remainingSeconds = nil
        }
        state.progress = nil
    }

    private func updateDisplayFromPhase(_ state: inout State) {
        let strategy = state.selectedMode.strategy
        let phase = strategy.initialPhase(config: state.config)

        if let target = strategy.targetDuration(config: state.config, phase: phase) {
            state.displayTime = formatTime(target)
            state.remainingSeconds = target
            state.progress = 0.0
        } else {
            state.displayTime = "0:00"
            state.remainingSeconds = nil
            state.progress = nil
        }
        state.phaseLabel = phase.displayName
    }

    private func resetState(_ state: inout State) {
        state.isRunning = false
        state.isPaused = false
        state.activeMode = nil
        state.phase = .idle
        state.elapsedSeconds = 0
        // Preserve pomodoroNumber so the next session starts with correct cycle position
        state.progress = nil
        state.linkedTaskID = nil
        state.linkedTaskTitle = nil
        state.modeSuggestion = nil
        AppGroupDefaults.isSessionActive = false
        AppGroupDefaults.clearActiveSession()
        updateIdleDisplay(&state)
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let totalSeconds = Int(max(0, seconds))
        let m = totalSeconds / 60
        let s = totalSeconds % 60
        return String(format: "%d:%02d", m, s)
    }
}
