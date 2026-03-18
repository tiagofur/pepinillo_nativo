// WatchTimerFeature.swift
// Pepinillo — Deep Work Companion for Apple
//
// TCA Reducer for the Apple Watch timer screen.
// Receives state from the iOS app via WatchConnectivity and
// provides local haptic feedback on phase transitions.

import Foundation
import ComposableArchitecture
import WatchKit
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
                    WKInterfaceDevice.current().play(.start)
                }

            case .pauseResumeTapped:
                guard state.isSessionActive else { return .none }
                let command: WatchCommand = state.isPaused ? .resumeSession : .pauseSession
                return .run { [watchClient] send in
                    await watchClient.sendCommand(command)
                    await send(.commandSent(command))
                    WKInterfaceDevice.current().play(.click)
                }

            case .stopTapped:
                guard state.isSessionActive else { return .none }
                return .run { [watchClient] send in
                    await watchClient.sendCommand(.stopSession)
                    await send(.commandSent(.stopSession))
                    WKInterfaceDevice.current().play(.stop)
                }

            case .skipTapped:
                guard state.isSessionActive else { return .none }
                return .run { [watchClient] send in
                    await watchClient.sendCommand(.skipPhase)
                    await send(.commandSent(.skipPhase))
                    WKInterfaceDevice.current().play(.click)
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

                return .run { _ in
                    Self.persistSessionState(
                        isActive: isActive,
                        displayTime: displayTime,
                        modeEmoji: modeEmoji
                    )
                    if didTransition || !isActive {
                        WidgetCenter.shared.reloadAllTimelines()
                    }
                    if didTransition {
                        WKInterfaceDevice.current().play(.notification)
                    }
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

    private static func persistStats(minutes: Int, sessions: Int, streak: Int) {
        let defaults = UserDefaults.standard
        defaults.set(minutes, forKey: WatchStatsKeys.todayFocusMinutes)
        defaults.set(sessions, forKey: WatchStatsKeys.todaySessionsCompleted)
        defaults.set(streak, forKey: WatchStatsKeys.currentStreakDays)
    }

    private static func persistSessionState(isActive: Bool, displayTime: String, modeEmoji: String) {
        let defaults = UserDefaults.standard
        defaults.set(isActive, forKey: WatchStatsKeys.isSessionActive)
        defaults.set(displayTime, forKey: WatchStatsKeys.displayTime)
        defaults.set(modeEmoji, forKey: WatchStatsKeys.modeEmoji)
    }
}
