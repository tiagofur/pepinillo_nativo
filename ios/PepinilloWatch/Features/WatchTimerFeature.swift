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

/// Optimistic start payload: the timer screen shows a local count-up the
/// moment the user taps Start, while the command may still be sitting in
/// the lazily-delivered transferUserInfo queue (phone locked/backgrounded
/// — up to the command TTL). Reconciled by the first authoritative
/// session state (or cleared with a failure haptic on timeout).
struct WatchPendingStart: Equatable {
    let mode: FocusMode
    let startedAt: Date
}

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

        /// Non-nil between tapping Start and the phone's authoritative
        /// session state arriving.
        var pendingStart: WatchPendingStart? = nil

        /// The countdown anchor the expiry watchdog is currently armed for
        /// (#880). Dedupes 1Hz re-arming on unchanged anchors; cleared when
        /// the session leaves the live-countdown state.
        var expiryWatchdogAnchor: Date? = nil
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
        /// Phone pushed the Pepinillo+ flag over WatchConnectivity (#976) —
        /// the App Group mirror only shares within the phone itself.
        case premiumStateReceived(Bool)

        // Commands sent to iOS
        case commandSent(WatchCommand)

        // System
        case onAppear
        case pendingStartTimedOut
        /// The countdown anchor expired (end passed) — #880 self-heal check.
        case phaseAnchorExpired(Date)
    }

    // MARK: - Dependencies

    @Dependency(\.watchConnectivityClient) var watchClient
    @Dependency(\.continuousClock) var clock

    private enum CancelID { case pendingStart, anchorWatchdog }

    /// Give-up window for an optimistic start: the phone drops queued
    /// commands older than `commandTTLSeconds` (S7), so a confirmation has
    /// TTL + margin seconds to arrive before we admit the start failed.
    static let pendingStartTimeoutSeconds: TimeInterval = 330

    /// #880 RC2: how long a countdown anchor may sit past its end before the
    /// watch assumes the next-phase push was lost and asks the phone for a
    /// fresh snapshot. Healthy transitions land within ~1s.
    static let anchorExpiryGraceSeconds: TimeInterval = 3

    /// #880 RC2: retry cadence while the anchor stays expired.
    static let anchorRetrySeconds: TimeInterval = 5

    /// #880 RC2: fires `phaseAnchorExpired` once the countdown anchor is
    /// `anchorExpiryGraceSeconds` past. Uses the injected clock so tests
    /// advance time deterministically.
    private static func anchorWatchdogEffect(
        end: Date,
        clock: any Clock<Duration>
    ) -> Effect<Action> {
        .run { send in
            let delay = max(0, end.timeIntervalSinceNow) + anchorExpiryGraceSeconds
            try? await clock.sleep(for: .seconds(delay))
            await send(.phaseAnchorExpired(end))
        }
        .cancellable(id: CancelID.anchorWatchdog, cancelInFlight: true)
    }

    /// #880 RC2: while the anchor stays expired, re-check on the retry cadence —
    /// the loop dies on the guard as soon as a fresh anchor (or an inactive
    /// state) lands.
    private static func anchorRetryEffect(
        end: Date,
        clock: any Clock<Duration>
    ) -> Effect<Action> {
        .run { send in
            try? await clock.sleep(for: .seconds(anchorRetrySeconds))
            await send(.phaseAnchorExpired(end))
        }
        .cancellable(id: CancelID.anchorWatchdog, cancelInFlight: true)
    }

    // MARK: - Reducer

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {

            case .onAppear:
                state.isProUser = Self.readIsProUser()
                return .none

            case .pendingStartTimedOut:
                // No authoritative state within the TTL window — the start
                // never stuck. Clear the optimistic screen with a failure cue.
                state.pendingStart = nil
                #if os(watchOS)
                return .merge(
                    .cancel(id: CancelID.pendingStart),
                    .run { _ in
                        WKInterfaceDevice.current().play(.failure)
                    }
                )
                #else
                return .cancel(id: CancelID.pendingStart)
                #endif

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
                // Optimistic start: the command may ride the lazily-delivered
                // transferUserInfo queue for up to the TTL when the phone is
                // locked — the timer screen must not stare at idle meanwhile.
                state.pendingStart = WatchPendingStart(mode: mode, startedAt: Date.now)
                return .merge(
                    .run { [watchClient] send in
                        _ = await watchClient.sendCommand(.startSession(mode: mode.rawValue))
                        await send(.commandSent(.startSession(mode: mode.rawValue)))
                        #if os(watchOS)
                        // Both transports mean "accepted": sendMessage reached
                        // the phone, transferUserInfo is guaranteed delivery.
                        WKInterfaceDevice.current().play(.start)
                        #endif
                    },
                    Self.pendingStartTimeoutEffect()
                )

            case .pauseResumeTapped:
                // No-op during the waiting hold — the engine ignores pause while waiting,
                // and we must not play a success haptic that implies it worked.
                guard state.isSessionActive, state.pendingStart == nil, !state.isWaiting else { return .none }
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
                guard state.isSessionActive, state.pendingStart == nil, state.isWaiting else { return .none }
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
                guard state.isSessionActive, state.pendingStart == nil else { return .none }
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
                guard state.isSessionActive, state.pendingStart == nil else { return .none }
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

                // An authoritative update resolves any optimistic start:
                // active = the start landed (release the give-up timer);
                // inactive = the queued command was dropped/refused.
                let wasPendingStart = state.pendingStart != nil
                state.pendingStart = nil

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
                // SF Symbol name — emoji retired for theme parity with
                // iPhone/Mac. The legacy `watch.modeEmoji` defaults key
                // keeps its name (only the key-prefix test reads it).
                let modeEmoji = FocusMode(rawValue: s.modeID)?.systemImage ?? "brain"
                let didTransition = s.isPhaseTransition
                let linkedTaskTitle = s.linkedTaskTitle
                let phaseName = s.phaseLabel
                let progress = s.progress
                let pomodoroNumber = s.pomodoroNumber
                let phaseStartDate = s.phaseStartDate
                let phaseEndDate = s.phaseEndDate
                let countsDown = s.countsDown
                let isPaused = s.isPaused
                let sessionCompleted = wasActive && !s.isActive

                let persistEffect = Effect<Action>.run { _ in
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
                        countsDown: countsDown,
                        isPaused: isPaused
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

                // #880 RC2: arm the expiry watchdog on live countdown anchors.
                // If the authoritative next-phase push never lands (lost
                // transition), self-heal by asking the phone for a fresh
                // snapshot instead of counting overtime forever.
                var effects: [Effect<Action>] = [persistEffect]
                let liveCountdown = s.isActive && !s.isWaiting && !s.isPaused
                    && s.countsDown && s.phaseEndDate != nil
                if liveCountdown, let end = s.phaseEndDate,
                   end != state.expiryWatchdogAnchor {
                    state.expiryWatchdogAnchor = end
                    effects.append(Self.anchorWatchdogEffect(end: end, clock: clock))
                } else if !liveCountdown {
                    // Left the live-countdown state (pause, hold, stop, count-up):
                    // drop any armed watchdog and its anchor.
                    state.expiryWatchdogAnchor = nil
                    effects.append(.cancel(id: CancelID.anchorWatchdog))
                }

                guard wasPendingStart else { return .merge(effects) }
                effects.insert(.cancel(id: CancelID.pendingStart), at: 0)
                if !s.isActive {
                    // The optimistic start did not stick (stale-dropped or
                    // refused phone-side) — say so.
                    #if os(watchOS)
                    effects.append(.run { _ in
                        WKInterfaceDevice.current().play(.failure)
                    })
                    #endif
                }
                return .merge(effects)

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

            case .premiumStateReceived(let isPro):
                state.isProUser = isPro
                // Persist so launches and future reads (onAppear /
                // connectivityChanged) see the flag before the next push.
                Self.appGroupDefaults?.set(isPro, forKey: "isProUser")
                return .none

            case .phaseAnchorExpired(let end):
                // The countdown anchor is past with no authoritative follow-up:
                // the transition push was lost. Ask the phone for a fresh
                // snapshot and keep retrying while the session stays stuck on
                // the expired anchor (#880 RC2).
                guard state.isSessionActive, !state.isWaiting, !state.isPaused,
                      state.countsDown, state.phaseEndDate == end,
                      end.timeIntervalSinceNow <= 0
                else { return .none }
                return .merge(
                    .run { [watchClient] _ in
                        _ = await watchClient.sendCommand(.requestSession)
                    },
                    Self.anchorRetryEffect(end: end, clock: clock)
                )

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
    /// Give-up timer for an optimistic start (command TTL + margin),
    /// cancelled the moment authoritative state resolves it.
    private static func pendingStartTimeoutEffect() -> Effect<Action> {
        .run { send in
            try? await Task.sleep(for: .seconds(Self.pendingStartTimeoutSeconds))
            await send(.pendingStartTimedOut)
        }
        .cancellable(id: CancelID.pendingStart)
    }

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
        countsDown: Bool,
        isPaused: Bool
    ) {
        guard let defaults = appGroupDefaults else { return }
        defaults.set(isActive, forKey: WatchStatsKeys.isSessionActive)
        defaults.set(isPaused, forKey: WatchStatsKeys.isPaused)
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
