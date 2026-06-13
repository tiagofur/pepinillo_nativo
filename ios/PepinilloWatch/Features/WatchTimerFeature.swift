// WatchTimerFeature.swift
// Pepinillo — Deep Work Companion for Apple
//
// TCA Reducer for the Apple Watch timer screen.
// Receives state from the iOS app via WatchConnectivity and
// provides local haptic feedback on phase transitions.

import Foundation
import ComposableArchitecture
#if os(watchOS)
import WatchKit
#endif
import WidgetKit

// MARK: - WatchTimerFeature

@Reducer
struct WatchTimerFeature {

    // MARK: - State

    @ObservableState
    struct State: Equatable {
        var isConnected: Bool = false
        var isSessionActive: Bool = false
        var isPaused: Bool = false
        var selectedMode: FocusMode = .pomodoro
        var displayTime: String = "25:00"
        var phaseLabel: String = "Ready"
        var isBreakPhase: Bool = false
        var isLongBreakPhase: Bool = false
        var progress: Double? = nil
        var pomodoroNumber: Int? = nil
        var linkedTaskTitle: String? = nil
        var linkedTaskID: String? = nil

        // Daily stats (mirrored from phone)
        var todayFocusMinutes: Int = 0
        var todaySessionsCompleted: Int = 0
        var currentStreakDays: Int = 0
    }

    // MARK: - Action

    enum Action: Equatable {
        // User interactions
        case startTapped
        case pauseResumeTapped
        case stopTapped
        case skipTapped
        case modeSelected(FocusMode)

        // Received from root (routed from WatchConnectivity)
        case sessionStateReceived(WatchSessionState)
        case statsReceived(todayMinutes: Int, sessions: Int, streak: Int)
        case connectivityChanged(Bool)

        // Commands sent to iOS
        case commandSent(WatchCommand)

        // System
        case onAppear
    }

    // MARK: - Dependencies

    @Dependency(\.watchConnectivityClient) var watchClient

    // MARK: - Reducer

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {

            case .onAppear:
                return .none

            case .startTapped:
                guard !state.isSessionActive else { return .none }
                let mode = state.selectedMode
                return .run { [watchClient] send in
                    await watchClient.sendCommand(.startSession(mode: mode.rawValue))
                    await send(.commandSent(.startSession(mode: mode.rawValue)))
                    #if os(watchOS)
                    WKInterfaceDevice.current().play(.start)
                    #endif
                }

            case .pauseResumeTapped:
                guard state.isSessionActive else { return .none }
                let command: WatchCommand = state.isPaused ? .resumeSession : .pauseSession
                return .run { [watchClient] send in
                    await watchClient.sendCommand(command)
                    await send(.commandSent(command))
                    #if os(watchOS)
                    WKInterfaceDevice.current().play(.click)
                    #endif
                }

            case .stopTapped:
                guard state.isSessionActive else { return .none }
                return .run { [watchClient] send in
                    await watchClient.sendCommand(.stopSession)
                    await send(.commandSent(.stopSession))
                    #if os(watchOS)
                    WKInterfaceDevice.current().play(.stop)
                    #endif
                }

            case .skipTapped:
                guard state.isSessionActive else { return .none }
                return .run { [watchClient] send in
                    await watchClient.sendCommand(.skipPhase)
                    await send(.commandSent(.skipPhase))
                    #if os(watchOS)
                    WKInterfaceDevice.current().play(.click)
                    #endif
                }

            case .modeSelected(let mode):
                guard !state.isSessionActive else { return .none }
                state.selectedMode = mode
                return .none

            case .sessionStateReceived(let s):
                state.isSessionActive = s.isActive
                state.isPaused = s.isPaused
                state.displayTime = s.displayTime
                state.phaseLabel = s.phaseLabel
                state.isBreakPhase = s.isBreakPhase
                state.isLongBreakPhase = s.isLongBreakPhase
                state.progress = s.progress
                state.pomodoroNumber = s.pomodoroNumber
                state.linkedTaskTitle = s.linkedTaskTitle
                state.linkedTaskID = s.linkedTaskID

                if let mode = FocusMode(rawValue: s.modeID) {
                    state.selectedMode = mode
                }

                // Persist session state for complications
                let isActive = s.isActive
                let displayTime = s.displayTime
                let modeEmoji = FocusMode(rawValue: s.modeID)?.icon ?? "🧠"
                let didTransition = s.isPhaseTransition
                let linkedTaskTitle = s.linkedTaskTitle
                let phaseName = s.phaseLabel
                let progress = s.progress
                let pomodoroNumber = s.pomodoroNumber

                return .run { _ in
                    Self.persistSessionState(
                        isActive: isActive,
                        displayTime: displayTime,
                        modeEmoji: modeEmoji,
                        linkedTaskTitle: linkedTaskTitle,
                        phaseName: phaseName,
                        progress: progress,
                        pomodoroNumber: pomodoroNumber
                    )
                    if didTransition || !isActive {
                        WidgetCenter.shared.reloadAllTimelines()
                    }
                    #if os(watchOS)
                    if !isActive {
                        // Session completed — celebrate
                        WKInterfaceDevice.current().play(.success)
                    } else if didTransition {
                        // Phase changed (focus → break or break → focus)
                        WKInterfaceDevice.current().play(.notification)
                    }
                    #endif
                }

            case .statsReceived(let minutes, let sessions, let streak):
                state.todayFocusMinutes = minutes
                state.todaySessionsCompleted = sessions
                state.currentStreakDays = streak
                return .run { _ in
                    Self.persistStats(minutes: minutes, sessions: sessions, streak: streak)
                    WidgetCenter.shared.reloadAllTimelines()
                }

            case .connectivityChanged(let connected):
                state.isConnected = connected
                return .none

            case .commandSent:
                return .none
            }
        }
    }

    // MARK: - UserDefaults Persistence (for Complications)
    //
    // Complications run in a separate process (WidgetKit extension).
    // UserDefaults.standard is NOT shared across processes.
    // All watch-side persistence MUST use the app group suite so complications
    // can read the same values the watch app writes.

    private static var appGroupDefaults: UserDefaults? {
        UserDefaults(suiteName: "group.com.pepinillo.app")
    }

    private static func persistStats(minutes: Int, sessions: Int, streak: Int) {
        guard let defaults = appGroupDefaults else { return }
        defaults.set(minutes, forKey: WatchStatsKeys.todayFocusMinutes)
        defaults.set(sessions, forKey: WatchStatsKeys.todaySessionsCompleted)
        defaults.set(streak, forKey: WatchStatsKeys.currentStreakDays)
    }

    private static func persistSessionState(
        isActive: Bool,
        displayTime: String,
        modeEmoji: String,
        linkedTaskTitle: String?,
        phaseName: String?,
        progress: Double?,
        pomodoroNumber: Int?
    ) {
        guard let defaults = appGroupDefaults else { return }
        defaults.set(isActive, forKey: WatchStatsKeys.isSessionActive)
        defaults.set(displayTime, forKey: WatchStatsKeys.displayTime)
        defaults.set(modeEmoji, forKey: WatchStatsKeys.modeEmoji)

        if let linkedTaskTitle {
            defaults.set(linkedTaskTitle, forKey: WatchStatsKeys.linkedTaskTitle)
        } else {
            defaults.removeObject(forKey: WatchStatsKeys.linkedTaskTitle)
        }

        if let phaseName {
            defaults.set(phaseName, forKey: WatchStatsKeys.phaseName)
        } else {
            defaults.removeObject(forKey: WatchStatsKeys.phaseName)
        }

        defaults.set(progress ?? 0, forKey: WatchStatsKeys.progress)

        if let pomodoroNumber {
            defaults.set(pomodoroNumber, forKey: WatchStatsKeys.pomodoroNumber)
        } else {
            defaults.removeObject(forKey: WatchStatsKeys.pomodoroNumber)
        }

        // Derive phase start/end dates from displayTime and progress for live countdown
        if isActive, let progress, progress >= 0 {
            let remainingSeconds = Self.parseDisplayTime(displayTime)
            if remainingSeconds > 0 {
                let elapsed = progress > 0 ? (remainingSeconds / (1.0 - progress)) * progress : 0
                let phaseStart = Date().addingTimeInterval(-elapsed)
                let phaseEnd = Date().addingTimeInterval(remainingSeconds)
                defaults.set(phaseStart.timeIntervalSince1970, forKey: WatchStatsKeys.phaseStartDate)
                defaults.set(phaseEnd.timeIntervalSince1970, forKey: WatchStatsKeys.phaseEndDate)
            }
        } else {
            defaults.removeObject(forKey: WatchStatsKeys.phaseStartDate)
            defaults.removeObject(forKey: WatchStatsKeys.phaseEndDate)
        }
    }

    private static func parseDisplayTime(_ displayTime: String) -> TimeInterval {
        let parts = displayTime.split(separator: ":").compactMap { Double($0) }
        guard parts.count == 2 else { return 0 }
        return parts[0] * 60 + parts[1]
    }
}
