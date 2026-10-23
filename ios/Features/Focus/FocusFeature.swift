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
        var modeIcon: String = "timer"

        // Task linking
        var linkedTaskID: UUID?
        var linkedTaskTitle: String?
        /// Identifier of the Calendar event created at session start (S2).
        var calendarEventID: String?
        var linkedTaskIcon: String?

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

        // Waiting-for-next-phase gate (auto-start OFF)
        // When true, the engine is holding between phases and waiting for user input.
        var isWaitingForNextPhase: Bool = false
        var pendingNextPhase: FocusPhase? = nil

        // Mode Intelligence
        var modeSuggestion: ModeSuggestion?

        // Post-session journal
        @Presents var journal: SessionJournalFeature.State?

        // Last Pomodoro work interval persisted in phaseCompleted (issue #171).
        // sessionCompleted uses the engine session UUID, but work intervals are saved
        // under fresh IDs — journal must link to the persisted record, not the engine.
        var lastPersistedPomodoroSessionID: UUID?
        var lastPersistedPomodoroDuration: TimeInterval?

        // Persist failure surfaced to the user (issue #75: avoid silent data loss)
        var sessionSaveError: String?
    }

    // MARK: - Actions

    enum Action: Equatable {
        // User interactions
        case modeSelected(FocusMode)
        case startTapped(timerStart: Date? = nil, timerEnd: Date? = nil)
        case pauseTapped
        case resumeTapped
        case externalPauseApplied(elapsed: TimeInterval, remaining: TimeInterval?, pausedAt: Date)
        case externalResumeApplied(elapsed: TimeInterval, remaining: TimeInterval?)
        case stopTapped
        case calendarEventCreated(String)
        case stopAbandoned(FocusSessionResult)
        case adoptGhostSession(FocusEngine.GhostResumeSpec)
        case skipPhaseTapped
        case linkTask(UUID?, String?, String?)
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
        case phaseSkipped(FocusSessionResult)
        case staleBackfillReceived(FocusSessionResult)
        case sessionCompleted(FocusSessionResult)
        case breakSuggested(TimeInterval)
        case midpointReached
        case interrupted
        case waitingForNextPhase(FocusPhase)

        // User action: advance from the waiting-for-next-phase hold
        case startNextPhaseTapped
        // Notification "+5 min": run five more minutes of work from the hold
        // after a completed work phase, instead of advancing into the break.
        case extendSessionTapped

        // Navigation
        case modeInfoTapped
        case modeInfoDismissed
        case settingsTapped
        case settingsDismissed
        case paywallTapped
        case paywallDismissed

        // Day change
        case dayChanged

        // Mode Intelligence
        case modeSuggested(ModeSuggestion?)
        case modeSuggestionAccepted
        case modeSuggestionDismissed

        // Post-session journal
        case showJournalSheet(sessionID: UUID, modeName: String, actualDuration: TimeInterval)
        case journal(PresentationAction<SessionJournalFeature.Action>)

        // Session save error dismissal (issue #75)
        case sessionSaveErrorDismissed

        // Parent coordination
        case delegate(Delegate)

        enum Delegate: Equatable {
            case sessionPersisted
            case sessionSaveFailed(String)
            case taskProgressChanged
        }
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
                state.modeIcon = mode.systemImage
                updateIdleDisplay(&state)
                AppGroupDefaults.widgetSelectedMode = mode.rawValue
                return .run { _ in
                    WidgetCenter.shared.reloadTimelines(ofKind: "FocusHomeScreenWidget")
                    WidgetCenter.shared.reloadTimelines(ofKind: "FocusLockScreenWidget")
                }

            // MARK: Session Control

            case .startTapped(let timerStart, let timerEnd):
                guard !state.isRunning else { return .none }
                if !state.selectedMode.isFreeTier && !state.isProUser {
                    state.showPaywall = true
                    return .none
                }
                state.isRunning = true
                state.isPaused = false
                state.activeMode = state.selectedMode

                AppGroupDefaults.isSessionActive = true
                AppGroupDefaults.activeModeName = state.selectedMode.rawValue
                AppGroupDefaults.widgetSelectedMode = state.selectedMode.rawValue
                AppGroupDefaults.activeSessionElapsed = 0
                AppGroupDefaults.activeSessionRemaining = nil
                AppGroupDefaults.activeSessionPhase = nil
                AppGroupDefaults.activeSessionProgress = nil
                AppGroupDefaults.activeSessionPomodoroNumber = state.selectedMode == .pomodoro ? 1 : nil
                AppGroupDefaults.activeSessionTotalPomodoros = state.selectedMode == .pomodoro ? state.config.pomodorosPerCycle : nil
                AppGroupDefaults.activeSessionTaskTitle = state.linkedTaskTitle
                AppGroupDefaults.activeSessionIsPaused = false
                AppGroupDefaults.activeSessionIsWaiting = false
                AppGroupDefaults.activeTaskID = state.linkedTaskID?.uuidString
                
                // Adopt provided anchors (from widget) or check for recent ones in defaults
                let now = Date.now
                let widgetStart = timerStart ?? AppGroupDefaults.activeSessionTimerStart
                let widgetEnd = timerEnd ?? AppGroupDefaults.activeSessionTimerEnd
                let startedFromWidget = AppGroupDefaults.activeSessionStartedFromWidget
                let shouldAdoptWidgetAnchors = timerStart != nil || startedFromWidget
                let engineTimerStart: Date?
                let engineTimerEnd: Date?
                
                if shouldAdoptWidgetAnchors, let start = widgetStart {
                    AppGroupDefaults.activeSessionTimerStart = start
                    AppGroupDefaults.activeSessionTimerEnd = widgetEnd
                    engineTimerStart = start
                    engineTimerEnd = widgetEnd
                } else {
                    AppGroupDefaults.activeSessionTimerStart = now
                    if let target = state.selectedMode.strategy.targetDuration(config: state.config, phase: state.selectedMode.strategy.initialPhase(config: state.config)) {
                        AppGroupDefaults.activeSessionTimerEnd = now.addingTimeInterval(target)
                    } else {
                        AppGroupDefaults.activeSessionTimerEnd = nil
                    }
                    engineTimerStart = nil
                    engineTimerEnd = nil
                }
                AppGroupDefaults.activeSessionStartedFromWidget = false

                if let durationMinutes = AppGroupDefaults.externalStartDurationMinutes {
                    switch state.selectedMode {
                    case .timeBlock:
                        state.customDurationMinutes = durationMinutes
                        state.config.defaultBlockDuration = TimeInterval(durationMinutes * 60)
                    case .pomodoro:
                        state.config.pomodoroDuration = TimeInterval(durationMinutes * 60)
                    default:
                        break
                    }
                    AppGroupDefaults.externalStartDurationMinutes = nil
                }
                
                let initialPhase = state.selectedMode.strategy.initialPhase(config: state.config)
                state.phase = initialPhase

                let initialTarget = state.selectedMode.strategy.targetDuration(config: state.config, phase: initialPhase)
                let initialElapsed = engineTimerStart.map { max(0, now.timeIntervalSince($0)) } ?? 0
                state.elapsedSeconds = initialElapsed

                if state.selectedMode.direction == .countDown, let initialTarget {
                    let initialRemaining = engineTimerEnd.map { max(0, $0.timeIntervalSince(now)) }
                        ?? max(0, initialTarget - initialElapsed)
                    state.remainingSeconds = initialRemaining
                    state.progress = min(max(initialElapsed / max(initialTarget, 1), 0), 1)
                    AppGroupDefaults.activeSessionRemaining = initialRemaining
                    AppGroupDefaults.activeSessionProgress = state.progress
                } else {
                    state.remainingSeconds = nil
                    state.progress = nil
                    AppGroupDefaults.activeSessionRemaining = nil
                    AppGroupDefaults.activeSessionProgress = nil
                }

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

                // Notify focus widgets and Control Center that a session has started (#231).
                WidgetSurfaceReload.reloadFocusAndControlCenter()

                let linkedTitle = state.linkedTaskTitle

                let soundscape = state.selectedSoundscape
                let soundscapeVolume = state.soundscapeVolume

                return .merge(
                    // Load today's completed pomodoro work sessions from DB, then start the engine
                    // with the seeded cycle position so long-break decisions are correct.
                    // These MUST be sequential: start() creates a fresh AsyncStream,
                    // and events() must read it after start() completes.
                    .run { [focusClient, persistence, liveActivity] send in
                        let completedWorkSessionsToday: Int
                        if mode == .pomodoro {
                            let startOfDay = Calendar.current.startOfDay(for: Date.now)
                            let sessions = try await persistence.fetchSessions(startOfDay, Date.now)
                            completedWorkSessionsToday = sessions.filter {
                                $0.mode == "pomodoro" && $0.wasCompleted
                            }.count
                        } else {
                            completedWorkSessionsToday = 0
                        }

                        await focusClient.start(
                            mode,
                            config,
                            taskID,
                            customDuration,
                            engineTimerStart,
                            engineTimerEnd,
                            completedWorkSessionsToday
                        )

                        // Start Live Activity after the engine is running (avoids nil currentState race).
                        if liveActivity.isAvailable(), let snapshot = await focusClient.currentState() {
                            await liveActivity.start(snapshot, linkedTitle)
                        }

                        let stream = await focusClient.events()
                        for await event in stream {
                            switch event {
                            case .tick(let sessionState):               await send(.timerTicked(sessionState))
                            case .phaseCompleted(let phase):            await send(.phaseCompleted(phase))
                            case .phaseSkipped(let partial):           await send(.phaseSkipped(partial))
                            case .sessionCompleted(let result):         await send(.sessionCompleted(result))
                            case .breakSuggested(let duration):         await send(.breakSuggested(duration))
                            case .midpointReached:                      await send(.midpointReached)
                            case .interrupted:                          await send(.interrupted)
                            case .waitingForNextPhase(let nextPhase):   await send(.waitingForNextPhase(nextPhase))
                            }
                        }
                    }
                    .cancellable(id: CancelID.engineObservation, cancelInFlight: true),
                    // Start soundscape
                    .run { [soundscapeClient] _ in
                        await soundscapeClient.play(soundscape, soundscapeVolume)
                    },
                    // Create calendar event if enabled (non-critical, errors silently ignored).
                    // The identifier is kept so aborting removes the event (S2).
                    .run { [calendarClient, persistence] send in
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
                        if let eventID = try? await calendarClient.createFocusEvent(title, Date.now, durationMinutes, mode.rawValue),
                           !eventID.isEmpty {
                            await send(.calendarEventCreated(eventID))
                        }
                    },
                    // Request notification permission at first session start (contextual moment).
                    // Fires at most once; denied permission doesn't affect session flow.
                    .run { [notificationClient] _ in
                        let key = "pepinillo.hasRequestedNotificationPermission"
                        guard !UserDefaults.standard.bool(forKey: key) else { return }
                        _ = await notificationClient.requestAuthorization()
                        UserDefaults.standard.set(true, forKey: key)
                    }
                )

            case .pauseTapped:
                guard !state.isWaitingForNextPhase else { return .none }
                guard state.isRunning, !state.isPaused else { return .none }
                let frozenElapsed = AppGroupDefaults.activeSessionLiveElapsed()
                let frozenRemaining = AppGroupDefaults.activeSessionLiveRemaining()
                state.isPaused = true
                state.elapsedSeconds = frozenElapsed
                state.remainingSeconds = frozenRemaining
                state.phaseLabel = FocusPhase.paused.displayName
                if let remaining = frozenRemaining {
                    let duration = max(frozenElapsed + remaining, 1)
                    state.progress = min(max(frozenElapsed / duration, 0), 1)
                    AppGroupDefaults.activeSessionProgress = state.progress
                }
                AppGroupDefaults.activeSessionElapsed = frozenElapsed
                AppGroupDefaults.activeSessionIsPaused = true
                AppGroupDefaults.activeSessionRemaining = frozenRemaining
                WidgetSurfaceReload.reloadFocusAndControlCenter()
                let taskTitle = state.linkedTaskTitle
                return .merge(
                    .run { _ in await focusClient.pause() },
                    .run { [liveActivity] _ in
                        let s = await focusClient.currentState()
                        if let s { await liveActivity.update(s, taskTitle) }
                    }
                )

            case .externalPauseApplied(let elapsed, let remaining, let pausedAt):
                // Defense-in-depth: ignore external pause/resume during the hold.
                // The engine guard is the primary line; this ensures the reducer also
                // does not mutate state or forward the call during the hold.
                guard !state.isWaitingForNextPhase else { return .none }
                guard state.isRunning else { return .none }
                state.isPaused = true
                state.elapsedSeconds = max(0, elapsed)
                state.remainingSeconds = remaining
                state.phaseLabel = FocusPhase.paused.displayName
                if let remaining {
                    let duration = max(elapsed + remaining, 1)
                    state.progress = min(max(elapsed / duration, 0), 1)
                    AppGroupDefaults.activeSessionProgress = state.progress
                } else {
                    state.progress = nil
                    AppGroupDefaults.activeSessionProgress = nil
                }
                AppGroupDefaults.activeSessionElapsed = max(0, elapsed)
                AppGroupDefaults.activeSessionRemaining = remaining
                AppGroupDefaults.activeSessionPausedAt = pausedAt
                AppGroupDefaults.activeSessionIsPaused = true
                WidgetSurfaceReload.reloadFocusAndControlCenter()
                let taskTitle = state.linkedTaskTitle
                return .merge(
                    .run { [focusClient] _ in
                        await focusClient.applyExternalPause(elapsed, remaining, pausedAt)
                    },
                    .run { [liveActivity] _ in
                        let s = await focusClient.currentState()
                        if let s { await liveActivity.update(s, taskTitle) }
                    }
                )

            case .resumeTapped:
                guard !state.isWaitingForNextPhase else { return .none }
                guard state.isRunning, state.isPaused else { return .none }
                state.isPaused = false
                AppGroupDefaults.activeSessionIsPaused = false
                AppGroupDefaults.activeSessionPausedAt = nil
                
                // Recalculate anchors to prevent drift after pause
                if let remaining = state.remainingSeconds {
                    AppGroupDefaults.activeSessionTimerEnd = Date.now.addingTimeInterval(remaining)
                    let duration = max(state.elapsedSeconds + remaining, 1)
                    AppGroupDefaults.activeSessionProgress = min(max(state.elapsedSeconds / duration, 0), 1)
                    AppGroupDefaults.activeSessionRemaining = nil
                }
                AppGroupDefaults.activeSessionTimerStart = Date.now.addingTimeInterval(-state.elapsedSeconds)
                AppGroupDefaults.activeSessionElapsed = state.elapsedSeconds
                
                WidgetSurfaceReload.reloadFocusAndControlCenter()
                let taskTitle = state.linkedTaskTitle
                return .merge(
                    .run { _ in await focusClient.resume() },
                    .run { [liveActivity] _ in
                        let s = await focusClient.currentState()
                        if let s { await liveActivity.update(s, taskTitle) }
                    }
                )

            case .externalResumeApplied(let elapsed, let remaining):
                // Defense-in-depth: ignore external resume during the hold.
                guard !state.isWaitingForNextPhase else { return .none }
                guard state.isRunning else { return .none }
                state.isPaused = false
                state.elapsedSeconds = max(0, elapsed)
                state.remainingSeconds = remaining
                state.phaseLabel = state.phase.displayName
                AppGroupDefaults.activeSessionElapsed = max(0, elapsed)
                AppGroupDefaults.activeSessionRemaining = nil
                AppGroupDefaults.activeSessionIsPaused = false
                AppGroupDefaults.activeSessionPausedAt = nil
                if let remaining {
                    AppGroupDefaults.activeSessionTimerEnd = Date.now.addingTimeInterval(remaining)
                    let duration = max(elapsed + remaining, 1)
                    state.progress = min(max(elapsed / duration, 0), 1)
                    AppGroupDefaults.activeSessionProgress = state.progress
                } else {
                    state.progress = nil
                    AppGroupDefaults.activeSessionProgress = nil
                }
                AppGroupDefaults.activeSessionTimerStart = Date.now.addingTimeInterval(-elapsed)
                WidgetSurfaceReload.reloadFocusAndControlCenter()
                let taskTitle = state.linkedTaskTitle
                return .merge(
                    .run { [focusClient] _ in
                        await focusClient.applyExternalResume(elapsed, remaining)
                    },
                    .run { [liveActivity] _ in
                        let s = await focusClient.currentState()
                        if let s { await liveActivity.update(s, taskTitle) }
                    }
                )

            case .calendarEventCreated(let eventID):
                state.calendarEventID = eventID
                return .none

            case .stopTapped:
                let wasRunning = state.isRunning
                let calendarEventID = state.calendarEventID
                resetState(&state)
                guard wasRunning else { return .none }
                // S7: cancel observation FIRST, then take the abandon directly.
                // abandonSession() never emits to the stream, so there is no
                // terminal event to lose; the old #170 race (cancel dropping a
                // buffered .sessionCompleted) cannot happen by construction.
                // A later startTapped observes a fresh stream: nothing is
                // dropped and nothing is delivered twice.
                return .merge(
                    .cancel(id: CancelID.engineObservation),
                    .run { [focusClient] send in
                        if let result = await focusClient.abandonSession() {
                            await send(.stopAbandoned(result))
                        }
                    },
                    .run { [calendarClient, calendarEventID] _ in
                        // S2: remove the calendar event created at session start;
                        // aborting left a phantom busy block in the real calendar.
                        if let calendarEventID = calendarEventID {
                            try? await calendarClient.removeFocusEvent(calendarEventID)
                        }
                    },
                    .run { [liveActivity] _ in await liveActivity.end(false) },
                    .run { [soundscapeClient] _ in await soundscapeClient.fadeOut() },
                    .run { [notificationClient] _ in await notificationClient.clearActiveSession() },
                    .run { _ in
                        WidgetSurfaceReload.reloadFocusTasksAndControlCenter()
                    }
                )

            case .skipPhaseTapped:
                return .run { _ in await focusClient.skipPhase() }

            // MARK: Task Linking

            case .linkTask(let id, let title, let icon):
                state.linkedTaskID = id
                state.linkedTaskTitle = title
                state.linkedTaskIcon = icon
                state.modeSuggestion = nil
                AppGroupDefaults.activeTaskID = id?.uuidString
                AppGroupDefaults.activeSessionTaskTitle = title
                
                // Only focus widgets show the linked task title while a session is idle/active;
                // dashboard and tasks widgets are unaffected by task linking.
                let reloadWidgetEffect: Effect<Action> = .run { _ in
                    WidgetCenter.shared.reloadTimelines(ofKind: "FocusHomeScreenWidget")
                    WidgetCenter.shared.reloadTimelines(ofKind: "FocusLockScreenWidget")
                }

                guard let taskID = id, !state.isRunning else {
                    return reloadWidgetEffect
                }
                
                // Query Mode Intelligence for a suggestion
                return .merge(
                    reloadWidgetEffect,
                    .run { [persistence] send in
                        let calendar = Calendar.current
                        let end = Date.now
                        guard let start = calendar.date(byAdding: .day, value: -30, to: end) else {
                            await send(.modeSuggested(nil))
                            return
                        }
                        let sessions: [SessionRecordDTO]
                        do {
                            sessions = try await persistence.fetchSessions(start, end)
                        } catch {
                            // Optional intelligence must never break the flow (S1).
                            await send(.modeSuggested(nil))
                            return
                        }
                        let service = ModeIntelligenceService()
                        let suggestion = service.suggestMode(forTaskID: taskID, sessions: sessions)
                        await send(.modeSuggested(suggestion))
                    }
                )

            case .customDurationChanged(let minutes):
                state.customDurationMinutes = max(1, min(480, minutes))
                var config = state.config
                config.defaultBlockDuration = TimeInterval(state.customDurationMinutes * 60)
                state.config = config
                updateIdleDisplay(&state)
                return .none

            case .configUpdated(let config):
                state.config = config
                
                // Sync cached durations for widget proactive starts
                AppGroupDefaults.pomodoroDuration = config.pomodoroDuration
                AppGroupDefaults.blockDuration = config.defaultBlockDuration
                
                if state.isRunning {
                    // Propagate new config to the engine so the active timer
                    // reflects any duration changes made in Settings in real-time.
                    return .run { [focusClient] _ in
                        await focusClient.updateConfig(config)
                    }
                } else {
                    updateIdleDisplay(&state)
                }
                return .none

            // MARK: Engine Event Handlers

            case .timerTicked(let sessionState):
                let previousPhase = state.phase
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

                let elapsed = sessionState.elapsedSeconds
                let taskTitle = state.linkedTaskTitle

                // Throttled write to AppGroupDefaults for widgets (every 1.0s or state changes)
                // We use floor to check if a second has passed since the last write
                let lastElapsed = AppGroupDefaults.activeSessionElapsed
                let significantChange = abs(elapsed - lastElapsed) >= 1.0 || state.isPaused

                var effects: [Effect<Action>] = []
                if sessionState.phase.isBreak, !previousPhase.isBreak,
                   let breakMinutes = breakDurationMinutes(for: sessionState.phase, config: state.config) {
                    effects.append(.run { [notificationClient] _ in
                        await notificationClient.scheduleBreakEnd(breakMinutes)
                    })
                }

                // Throttle Live Activity to 1Hz (ActivityKit rate limits; display shows whole seconds).
                // Notification update already runs every 30s.
                guard significantChange else {
                    return effects.isEmpty ? .none : .merge(effects)
                }

                // Capture all values up-front so the effect runs off the main actor.
                // Previously these 8 cross-process App-Group writes ran synchronously
                // on the main actor (TCA reducer) at ~1Hz for the whole session (issue #84).
                let remaining = sessionState.remainingSeconds
                let phaseLabel = state.phaseLabel
                let progress = sessionState.progress
                let pomodoroNumber = state.pomodoroNumber
                let totalPomodoros = sessionState.totalPomodoros
                let displayTime = state.displayTime
                let modeName = mode.rawValue
                let shouldUpdateNotification = Int(elapsed) > 0 && Int(elapsed) % 30 == 0 && Int(elapsed) != Int(lastElapsed)

                effects.append(.run { [liveActivity, notificationClient] _ in
                    // App-Group writes (off the main actor now)
                    AppGroupDefaults.activeSessionElapsed = elapsed
                    AppGroupDefaults.activeSessionRemaining = remaining
                    AppGroupDefaults.activeSessionPhase = phaseLabel
                    AppGroupDefaults.activeSessionProgress = progress
                    AppGroupDefaults.activeSessionPomodoroNumber = pomodoroNumber
                    AppGroupDefaults.activeSessionTotalPomodoros = totalPomodoros
                    AppGroupDefaults.activeSessionTaskTitle = taskTitle

                    await liveActivity.update(sessionState, taskTitle)
                    if shouldUpdateNotification {
                        await notificationClient.updateActiveSession(displayTime, modeName, phaseLabel)
                    }
                })

                return effects.isEmpty ? .none : .merge(effects)

            case .phaseSkipped(let partial):
                // S3: persist partial credit for a skipped Pomodoro work phase.
                // The session continues into the next phase: no teardown, no
                // journal, no completion effects — just the abandoned interval.
                return .run { [persistence] send in
                    do {
                        try await persistence.saveSession(partial)
                        await send(.delegate(.sessionPersisted))
                    } catch {
                        await send(.delegate(.sessionSaveFailed(error.localizedDescription)))
                    }
                }

            case .staleBackfillReceived(let backfill):
                // S6: persist a backfilled record for a stale widget/CC/Siri start
                // whose optimistic countdown was served while the app was away.
                // Historical data only: no teardown (nothing is running), no
                // journal, no notifications — just the unrecorded interval.
                return .run { [persistence] send in
                    do {
                        try await persistence.saveSession(backfill)
                        await send(.delegate(.sessionPersisted))
                    } catch {
                        await send(.delegate(.sessionSaveFailed(error.localizedDescription)))
                    }
                }

            case .stopAbandoned(let result):
                // S7: persist an abandon taken directly from the engine (see
                // stopTapped). The stream carries no copy, so this cannot
                // double-persist. Hold stops carry no new interval (S4).
                // No teardown/journal: stopTapped already ran those, and the
                // abandon was never completed.
                guard !result.isHoldStop else { return .none }
                return .run { [persistence] send in
                    do {
                        try await persistence.saveSession(result)
                        await send(.delegate(.sessionPersisted))
                    } catch {
                        await send(.delegate(.sessionSaveFailed(error.localizedDescription)))
                    }
                }

            case .adoptGhostSession(let spec):
                // Sprint-5 T3: resume a killed session. State mirrors a fresh
                // start (the running session owns the mode); engine math was
                // resolved in T1/T2. Observation + Live Activity + soundscape
                // restart like startTapped (keep event mapping in sync with it);
                // no calendar event (the original may still exist) and no
                // notification ask (one-time, already handled).
                state.isRunning = true
                state.activeMode = spec.mode
                state.selectedMode = spec.mode
                state.phase = spec.phase
                state.linkedTaskID = spec.linkedTaskID
                state.linkedTaskTitle = nil
                if case .work(let number, _) = spec.phase {
                    state.pomodoroNumber = number
                } else {
                    state.pomodoroNumber = nil
                }
                updateDisplayFromPhase(&state)
                WidgetSurfaceReload.reloadFocusTasksAndControlCenter()
                let config = state.config
                let soundscape = state.selectedSoundscape
                let soundscapeVolume = state.soundscapeVolume
                return .merge(
                    .run { [focusClient, liveActivity, spec, config] send in
                        await focusClient.adoptGhostSession(
                            spec.mode,
                            config,
                            spec.phase,
                            spec.elapsed,
                            spec.linkedTaskID
                        )
                        if liveActivity.isAvailable(), let snapshot = await focusClient.currentState() {
                            await liveActivity.start(snapshot, nil)
                        }
                        let stream = await focusClient.events()
                        for await event in stream {
                            switch event {
                            case .tick(let sessionState):               await send(.timerTicked(sessionState))
                            case .phaseCompleted(let phase):            await send(.phaseCompleted(phase))
                            case .phaseSkipped(let partial):           await send(.phaseSkipped(partial))
                            case .sessionCompleted(let result):         await send(.sessionCompleted(result))
                            case .breakSuggested(let duration):         await send(.breakSuggested(duration))
                            case .midpointReached:                      await send(.midpointReached)
                            case .interrupted:                          await send(.interrupted)
                            case .waitingForNextPhase(let nextPhase):   await send(.waitingForNextPhase(nextPhase))
                            }
                        }
                    }
                    .cancellable(id: CancelID.engineObservation, cancelInFlight: true),
                    .run { [soundscapeClient] _ in
                        await soundscapeClient.play(soundscape, soundscapeVolume)
                    },
                    .run { [spec] _ in
                        // Refresh widget anchors from adopted wall-clock state so
                        // countdown families show live time, not ghost values.
                        // (Per-tick writes take over within a second after this.)
                        let now = Date.now
                        AppGroupDefaults.isSessionActive = true
                        AppGroupDefaults.activeModeName = spec.mode.rawValue
                        AppGroupDefaults.activeSessionElapsed = spec.elapsed
                        if let remaining = spec.remaining {
                            AppGroupDefaults.activeSessionTimerStart = now.addingTimeInterval(-spec.elapsed)
                            AppGroupDefaults.activeSessionTimerEnd = now.addingTimeInterval(remaining)
                            AppGroupDefaults.activeSessionRemaining = remaining
                        } else {
                            AppGroupDefaults.activeSessionTimerStart = now.addingTimeInterval(-spec.elapsed)
                            AppGroupDefaults.activeSessionTimerEnd = nil
                            AppGroupDefaults.activeSessionRemaining = nil
                        }
                        AppGroupDefaults.activeSessionIsPaused = false
                        AppGroupDefaults.activeSessionIsWaiting = false
                        WidgetSurfaceReload.reloadFocusTasksAndControlCenter()
                    }
                )

            case .phaseCompleted(let completedPhase):
                // Engine handles phase transition automatically;
                // we'll get updated state via the next .timerTicked.
                let soundEnabled = state.config.soundEnabled
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

                // For Pomodoro work phases, persist the completed work interval immediately
                // so stats update in real time without waiting for the full cycle to end.
                // saveSession internally handles task.completedPomodoros, so we do NOT
                // call incrementTaskPomodoros separately to avoid double-counting.
                var phaseNotificationEffect: Effect<Action> = .none
                var intervalPersistEffect: Effect<Action> = .none
                var healthLogEffect: Effect<Action> = .none
                if case .work(let number, let total) = completedPhase, mode == .pomodoro {
                    let isLongBreak = number >= total
                    phaseNotificationEffect = .run { [notificationClient] _ in
                        await notificationClient.scheduleWorkPhaseEnd(number, isLongBreak, taskTitle)
                    }
                    // Capture values for the persistence effect
                    let workDuration = state.elapsedSeconds
                    let intervalStartedAt = Date.now.addingTimeInterval(-workDuration)
                    let sessionID = UUID()
                    state.lastPersistedPomodoroSessionID = sessionID
                    state.lastPersistedPomodoroDuration = workDuration
                    let linkedTaskID = state.linkedTaskID
                    let pomNumber = number
                    let intervalResult = FocusSessionResult(
                        id: sessionID,
                        mode: .pomodoro,
                        phase: .work(number: pomNumber, total: total),
                        startedAt: intervalStartedAt,
                        endedAt: Date.now,
                        targetDuration: config.pomodoroDuration,
                        actualDuration: workDuration,
                        wasCompleted: true,
                        interruptions: state.interruptions,
                        pomodoroNumber: pomNumber,
                        linkedTaskID: linkedTaskID
                    )
                    intervalPersistEffect = .run { [persistence] send in
                        do {
                            try await persistence.saveSession(intervalResult)
                            await send(.delegate(.sessionPersisted))
                        } catch {
                            await send(.delegate(.sessionSaveFailed(error.localizedDescription)))
                        }
                    }
                    healthLogEffect = .run { [healthClient, persistence] _ in
                        let prefs = try await persistence.fetchPreferences()
                        guard prefs.healthLoggingEnabled, healthClient.isAuthorized() else { return }
                        try await healthClient.logMindfulMinutes(intervalStartedAt, Date.now)
                    }
                }

                return .merge(
                    .run { _ in
                        await MainActor.run {
                            HapticManager.phaseComplete(soundEnabled: soundEnabled, hapticEnabled: hapticEnabled)
                        }
                    },
                    phaseNotificationEffect,
                    intervalPersistEffect,
                    healthLogEffect
                )

            case .sessionCompleted(let result):
                let modeName = result.mode.rawValue
                let taskTitle = state.linkedTaskTitle
                let wasCompleted = result.wasCompleted
                let sessionID = result.id
                let actualDuration = result.actualDuration
                // S1: multi-phase sessions (Flowtime) accumulate focus across phases in
                // totalFocusSeconds — persist and display the session total, not the
                // last phase alone. Pomodoro keeps per-interval semantics because its
                // completed work intervals already persist in phaseCompleted.
                let sessionTotal = result.mode == .pomodoro ? actualDuration : result.totalFocusSeconds
                // Completed Pomodoro cycles persist work in phaseCompleted under a
                // separate UUID; journal must target that record and its focus duration.
                let journalSessionID: UUID
                let journalDuration: TimeInterval
                if result.mode == .pomodoro, wasCompleted {
                    journalSessionID = state.lastPersistedPomodoroSessionID ?? sessionID
                    journalDuration = state.lastPersistedPomodoroDuration ?? actualDuration
                } else {
                    journalSessionID = sessionID
                    journalDuration = sessionTotal
                }
                resetState(&state)

                // Pomodoro: full work intervals are persisted in phaseCompleted. Natural
                // cycle completion needs no extra record. Manual stop mid-work persists
                // partial progress (wasCompleted=false) so stats reflect abandoned pomodoros.
                // Non-pomodoro modes always persist here (complete or abandoned).
                let persistEffect: Effect<Action>
                switch result.mode {
                case .pomodoro:
                    if wasCompleted {
                        persistEffect = .none
                    } else if case .work = result.phase, !result.isHoldStop {
                        persistEffect = .run { [persistence] send in
                            do {
                                try await persistence.saveSession(result)
                                await send(.delegate(.sessionPersisted))
                            } catch {
                                await send(.delegate(.sessionSaveFailed(error.localizedDescription)))
                            }
                        }
                    } else {
                        persistEffect = .none
                    }
                default:
                    if result.isHoldStop {
                        // S4: stop during a hold carries no new interval — never persist.
                        persistEffect = .none
                    } else {
                        persistEffect = .run { [persistence, sessionTotal] send in
                            do {
                                try await persistence.saveSession(result.withActualDuration(sessionTotal))
                                await send(.delegate(.sessionPersisted))
                            } catch {
                                await send(.delegate(.sessionSaveFailed(error.localizedDescription)))
                            }
                        }
                    }
                }

                var completionEffects: [Effect<Action>] = [
                    // Check preference and present journal sheet if enabled
                    .run { [persistence] send in
                        if wasCompleted {
                            let prefs = try await persistence.fetchPreferences()
                            if prefs.showJournalAfterSession {
                                await send(.showJournalSheet(
                                    sessionID: journalSessionID,
                                    modeName: modeName,
                                    actualDuration: journalDuration
                                ))
                            }
                        }
                    },
                    .cancel(id: CancelID.engineObservation),
                    .run { [liveActivity] _ in await liveActivity.end(wasCompleted) },
                    .run { [soundscapeClient] _ in await soundscapeClient.fadeOut() },
                    .run { [notificationClient] _ in await notificationClient.clearActiveSession() },
                    persistEffect,
                    .run { _ in
                        WidgetSurfaceReload.reloadFocusTasksAndControlCenter()
                    }
                ]

                if wasCompleted {
                    completionEffects.append(contentsOf: [
                        .run { [notificationClient] _ in
                            await notificationClient.scheduleSessionComplete(modeName, taskTitle)
                        },
                        // Donate intent for Siri Suggestions
                        .run { _ in
                            let intent = StartFocusIntent()
                            if let mode = FocusModeEntity.allModes.first(where: { $0.id == modeName }) {
                                intent.mode = mode
                            }
                            _ = try? await intent.donate()
                        }
                    ])
                }

                // Pomodoro work intervals log in phaseCompleted; other modes log focused time only.
                if wasCompleted, result.mode != .pomodoro, sessionTotal > 0 {
                    let end = result.endedAt
                    let start = end.addingTimeInterval(-sessionTotal)
                    completionEffects.append(
                        .run { [healthClient, persistence] _ in
                            let prefs = try await persistence.fetchPreferences()
                            guard prefs.healthLoggingEnabled, healthClient.isAuthorized() else { return }
                            try await healthClient.logMindfulMinutes(start, end)
                        }
                    )
                }

                return .merge(completionEffects)

            case .breakSuggested(let duration):
                let minutes = Int(duration / 60)
                state.phaseLabel = String(localized: "Break suggested: \(minutes) min")
                return .none

            case .midpointReached:
                state.phaseLabel = String(localized: "Halfway there!")
                let soundEnabled = state.config.soundEnabled
                let hapticEnabled = state.config.hapticEnabled
                return .run { _ in
                    await MainActor.run {
                        HapticManager.feedbackPulse(soundEnabled: soundEnabled, hapticEnabled: hapticEnabled)
                    }
                }

            case .interrupted:
                state.interruptions += 1
                return .none

            case .waitingForNextPhase(let nextPhase):
                // Engine is now holding — tick timer is suspended. Update UI state so the
                // view can show the CTA button for the pending next phase.
                state.isWaitingForNextPhase = true
                state.pendingNextPhase = nextPhase
                // Show the pending phase label so the user knows what's coming next.
                state.phaseLabel = nextPhase.displayName

                // Seed the hold UI from the pending phase target so the timer does not show 0:00.
                let mode = state.activeMode ?? state.selectedMode
                if let target = mode.strategy.targetDuration(config: state.config, phase: nextPhase) {
                    state.displayTime = formatTime(target)
                    state.remainingSeconds = target
                    state.progress = 0.0
                }

                // FIX 1: Clear the countdown anchors written by .phaseCompleted so
                // widgets do not display a phantom live countdown for the pending phase
                // while we are in the hold (no timer is running). The widget sees
                // timerEnd = nil and isPaused = true, which it treats as a paused/waiting
                // state rather than a ticking countdown.
                AppGroupDefaults.activeSessionTimerEnd = nil
                AppGroupDefaults.activeSessionTimerStart = nil
                AppGroupDefaults.activeSessionRemaining = nil
                AppGroupDefaults.activeSessionProgress = nil

                // Update widget/AppGroup so the lock screen widget reflects the hold state.
                AppGroupDefaults.activeSessionPhase = nextPhase.displayName
                AppGroupDefaults.activeSessionIsPaused = true
                // Signal to widget intents and widget views that the engine is in the
                // waiting hold, so they suppress pause/resume controls and intents.
                AppGroupDefaults.activeSessionIsWaiting = true
                WidgetCenter.shared.reloadTimelines(ofKind: "FocusHomeScreenWidget")
                WidgetCenter.shared.reloadTimelines(ofKind: "FocusLockScreenWidget")

                // FIX 2: Build a synthetic waiting state for the Live Activity so it shows
                // the PENDING phase as paused/waiting, not the completed phase at 0:00.
                let waitingState: FocusSessionState? = state.activeMode.map { mode in
                    let target = mode.strategy.targetDuration(config: state.config, phase: nextPhase)
                    return FocusSessionState(
                        id: UUID(),
                        mode: mode,
                        phase: nextPhase,
                        startedAt: Date.now,
                        elapsedSeconds: 0,
                        targetDuration: target,
                        remainingSeconds: target,
                        progress: 0.0,
                        isPaused: true,
                        pomodoroNumber: state.pomodoroNumber,
                        totalPomodoros: state.config.pomodorosPerCycle
                    )
                }
                let taskTitle = state.linkedTaskTitle
                return .run { [liveActivity] _ in
                    if let ws = waitingState {
                        await liveActivity.update(ws, taskTitle)
                    }
                }

            case .startNextPhaseTapped:
                guard state.isWaitingForNextPhase, let pending = state.pendingNextPhase else { return .none }
                state.isWaitingForNextPhase = false
                state.pendingNextPhase = nil

                // Update widget anchors for the new phase before the engine emits its first tick.
                // Also clear the isPaused and isWaiting flags set during the hold.
                let mode = state.activeMode ?? state.selectedMode
                let config = state.config
                AppGroupDefaults.activeSessionIsPaused = false
                AppGroupDefaults.activeSessionIsWaiting = false
                if let target = mode.strategy.targetDuration(config: config, phase: pending) {
                    AppGroupDefaults.activeSessionTimerStart = Date.now
                    AppGroupDefaults.activeSessionTimerEnd = Date.now.addingTimeInterval(target)
                    AppGroupDefaults.activeSessionPhase = pending.displayName
                }
                WidgetCenter.shared.reloadTimelines(ofKind: "FocusHomeScreenWidget")
                WidgetCenter.shared.reloadTimelines(ofKind: "FocusLockScreenWidget")

                let hapticEnabled = state.config.hapticEnabled
                return .merge(
                    .run { [focusClient] _ in await focusClient.startNextPhase() },
                    .run { _ in
                        guard hapticEnabled else { return }
                        #if os(iOS)
                        await MainActor.run {
                            let generator = UIImpactFeedbackGenerator(style: .medium)
                            generator.impactOccurred()
                        }
                        #endif
                    }
                )

            case .extendSessionTapped:
                // Same hold as startNextPhaseTapped, but the engine swaps the
                // pending break for a five-minute work interval. Guarded on
                // `.isBreak` so it only fires after a completed work phase —
                // the only place the "+5 min" notification action exists.
                guard state.isWaitingForNextPhase,
                      let pending = state.pendingNextPhase,
                      pending.isBreak else { return .none }
                state.isWaitingForNextPhase = false
                state.pendingNextPhase = nil

                let extensionMinutes: TimeInterval = 5 * 60
                AppGroupDefaults.activeSessionIsPaused = false
                AppGroupDefaults.activeSessionIsWaiting = false
                AppGroupDefaults.activeSessionTimerStart = Date.now
                AppGroupDefaults.activeSessionTimerEnd = Date.now.addingTimeInterval(extensionMinutes)
                let extendedPhase = FocusPhase.work(
                    number: state.pomodoroNumber ?? 1,
                    total: state.config.pomodorosPerCycle
                )
                AppGroupDefaults.activeSessionPhase = extendedPhase.displayName
                AppGroupDefaults.activeSessionRemaining = extensionMinutes
                AppGroupDefaults.activeSessionProgress = 0.0
                WidgetCenter.shared.reloadTimelines(ofKind: "FocusHomeScreenWidget")
                WidgetCenter.shared.reloadTimelines(ofKind: "FocusLockScreenWidget")

                return .run { [focusClient] _ in
                    await focusClient.extendNextPhase(extensionMinutes)
                }

            case .delegate(.sessionSaveFailed(let message)):
                // Surface persist failure to the user instead of dropping it silently (issue #75)
                state.sessionSaveError = message
                return .none

            case .delegate:
                return .none

            case .sessionSaveErrorDismissed:
                state.sessionSaveError = nil
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
                return .send(.linkTask(nil, nil, nil))

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

            // MARK: Day Change

            case .dayChanged:
                // Reset stale cycle position — re-seeded from DB on next startTapped
                state.pomodoroNumber = nil
                return .run { _ in await focusClient.resetForNewDay() }

            // MARK: Mode Intelligence

            case .modeSuggested(let suggestion):
                state.modeSuggestion = suggestion
                return .none

            case .modeSuggestionAccepted:
                if let mode = state.modeSuggestion?.suggestedMode {
                    state.selectedMode = mode
                    state.modeIcon = mode.systemImage
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
        state.modeIcon = state.selectedMode.systemImage
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
        let phase = state.phase
        state.phaseLabel = phase.displayName
        
        if state.isRunning {
            if strategy.direction == .countDown {
                let remaining = state.remainingSeconds ?? 0
                state.displayTime = formatTime(remaining)
            } else {
                state.displayTime = formatTime(state.elapsedSeconds)
            }
        } else {
            // Idle state: show the target for the initial phase
            let initial = strategy.initialPhase(config: state.config)
            if let target = strategy.targetDuration(config: state.config, phase: initial) {
                state.displayTime = formatTime(target)
                state.remainingSeconds = target
            } else {
                state.displayTime = "0:00"
                state.remainingSeconds = nil
            }
            state.progress = nil
        }
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
        state.isWaitingForNextPhase = false
        state.pendingNextPhase = nil
        state.lastPersistedPomodoroSessionID = nil
        state.lastPersistedPomodoroDuration = nil
        state.calendarEventID = nil
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

    private func breakDurationMinutes(for phase: FocusPhase, config: FocusConfig) -> Int? {
        let seconds: TimeInterval?
        switch phase {
        case .shortBreak:
            seconds = config.shortBreakDuration
        case .longBreak:
            seconds = config.longBreakDuration
        case .flowBreak(let duration):
            seconds = duration
        default:
            seconds = nil
        }
        guard let seconds else { return nil }
        return max(1, Int(seconds / 60))
    }
}
