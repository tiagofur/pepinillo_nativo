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
        /// Mirrors WatchSessionState.isWaiting — true when autoStart is OFF and the engine
        /// is holding for the user to tap the "Start …" CTA.
        var isWaiting: Bool = false
        var progress: Double? = nil
        var pomodoroNumber: Int? = nil
        var linkedTaskTitle: String? = nil
        var linkedTaskID: String? = nil

        // Daily stats (mirrored from phone)
        var todayFocusMinutes: Int = 0
        var todaySessionsCompleted: Int = 0
        var currentStreakDays: Int = 0

        /// Dedupe out-of-order applicationContext vs sendMessage updates (#240).
        var lastAppliedSentAt: TimeInterval = 0
        /// Avoid false completion haptics on cold-start idle hydration (#241).
        var hadActiveSession: Bool = false

        // Local countdown anchors when the phone is unreachable (#245).
        var phaseStartDate: Date? = nil
        var phaseEndDate: Date? = nil
        var countsDown: Bool = true

        /// Mirrors AppGroupDefaults.isProUser — phone writes on subscription change (#235).
        var isProUser: Bool = false
    }

    // MARK: - Action

    enum Action: Equatable {
        // User interactions
        case startTapped
        case pauseResumeTapped
        case stopTapped
        case skipTapped
        case startNextPhaseTapped
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
                state.isProUser = Self.readIsProUser()
                return .none

            case .startTapped:
                guard !state.isSessionActive else { return .none }
                let mode = state.selectedMode
                guard mode.isFreeTier || state.isProUser else {
                    #if os(watchOS)
                    return .run { _ in
                        WKInterfaceDevice.current().play(.failure)
                    }
                    #else
                    return .none
                    #endif
                }
                return .run { [watchClient] send in
                    let delivered = await watchClient.sendCommand(.startSession(mode: mode.rawValue))
                    await send(.commandSent(.startSession(mode: mode.rawValue)))
                    #if os(watchOS)
                    if delivered {
                        WKInterfaceDevice.current().play(.start)
                    } else {
                        WKInterfaceDevice.current().play(.failure)
                    }
                    #endif
                }

            case .pauseResumeTapped:
                // No-op during the waiting hold — the engine ignores pause while waiting,
                // and we must not play a success haptic that implies it worked.
                guard state.isSessionActive, !state.isWaiting else { return .none }
                let command: WatchCommand = state.isPaused ? .resumeSession : .pauseSession
                return .run { [watchClient] send in
                    let delivered = await watchClient.sendCommand(command)
                    await send(.commandSent(command))
                    #if os(watchOS)
                    if delivered {
                        WKInterfaceDevice.current().play(.click)
                    } else {
                        WKInterfaceDevice.current().play(.failure)
                    }
                    #endif
                }

            case .startNextPhaseTapped:
                guard state.isSessionActive, state.isWaiting else { return .none }
                return .run { [watchClient] send in
                    let delivered = await watchClient.sendCommand(.startNextPhase)
                    await send(.commandSent(.startNextPhase))
                    #if os(watchOS)
                    if delivered {
                        WKInterfaceDevice.current().play(.start)
                    } else {
                        WKInterfaceDevice.current().play(.failure)
                    }
                    #endif
                }

            case .stopTapped:
                guard state.isSessionActive else { return .none }
                return .run { [watchClient] send in
                    let delivered = await watchClient.sendCommand(.stopSession)
                    await send(.commandSent(.stopSession))
                    #if os(watchOS)
                    if delivered {
                        WKInterfaceDevice.current().play(.stop)
                    } else {
                        WKInterfaceDevice.current().play(.failure)
                    }
                    #endif
                }

            case .skipTapped:
                guard state.isSessionActive else { return .none }
                return .run { [watchClient] send in
                    let delivered = await watchClient.sendCommand(.skipPhase)
                    await send(.commandSent(.skipPhase))
                    #if os(watchOS)
                    if delivered {
                        WKInterfaceDevice.current().play(.click)
                    } else {
                        WKInterfaceDevice.current().play(.failure)
                    }
                    #endif
                }

            case .modeSelected(let mode):
                guard !state.isSessionActive else { return .none }
                guard mode.isFreeTier || state.isProUser else { return .none }
                state.selectedMode = mode
                return .none

            case .sessionStateReceived(let s):
                guard s.sentAt > state.lastAppliedSentAt else { return .none }
                state.lastAppliedSentAt = s.sentAt

                let wasActive = state.hadActiveSession
                state.hadActiveSession = s.isActive

                state.isSessionActive = s.isActive
                state.isPaused = s.isPaused
                state.displayTime = s.displayTime
                state.phaseLabel = s.phaseLabel
                state.isBreakPhase = s.isBreakPhase
                state.isLongBreakPhase = s.isLongBreakPhase
                state.isWaiting = s.isWaiting
                state.progress = s.progress
                state.pomodoroNumber = s.pomodoroNumber
                state.linkedTaskTitle = s.linkedTaskTitle
                state.linkedTaskID = s.linkedTaskID
                state.phaseStartDate = s.phaseStartDate
                state.phaseEndDate = s.phaseEndDate
                state.countsDown = s.countsDown

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
                let phaseStartDate = s.phaseStartDate
                let phaseEndDate = s.phaseEndDate
                let countsDown = s.countsDown
                let sessionCompleted = wasActive && !s.isActive

                return .run { _ in
                    Self.persistSessionState(
                        isActive: isActive,
                        displayTime: displayTime,
                        modeEmoji: modeEmoji,
                        linkedTaskTitle: linkedTaskTitle,
                        phaseName: phaseName,
                        progress: progress,
                        pomodoroNumber: pomodoroNumber,
                        phaseStartDate: phaseStartDate,
                        phaseEndDate: phaseEndDate,
                        countsDown: countsDown
                    )
                    if didTransition || sessionCompleted {
                        WidgetCenter.shared.reloadAllTimelines()
                    }
                    #if os(watchOS)
                    if sessionCompleted {
                        WKInterfaceDevice.current().play(.success)
                    } else if didTransition {
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
                if connected {
                    state.isProUser = Self.readIsProUser()
                }
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

    /// Mirrors `AppGroupDefaults.isProUser` without pulling SwiftData into the watch target.
    private static func readIsProUser() -> Bool {
        appGroupDefaults?.bool(forKey: "isProUser") ?? false
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
        pomodoroNumber: Int?,
        phaseStartDate: Date?,
        phaseEndDate: Date?,
        countsDown: Bool
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

        // Prefer absolute anchors from the phone (#244); avoid reverse-engineering display strings.
        if isActive, countsDown, let start = phaseStartDate, let end = phaseEndDate, end > start {
            defaults.set(start.timeIntervalSince1970, forKey: WatchStatsKeys.phaseStartDate)
            defaults.set(end.timeIntervalSince1970, forKey: WatchStatsKeys.phaseEndDate)
        } else {
            defaults.removeObject(forKey: WatchStatsKeys.phaseStartDate)
            defaults.removeObject(forKey: WatchStatsKeys.phaseEndDate)
        }
    }
}
