// FocusModels.swift
// Pepinillo — Deep Work Companion for Apple
//
// Core enums and value types for the multi-mode Focus Engine.
// These are pure Swift types — no framework dependencies.

import Foundation

// MARK: - Focus Mode

/// The four focus techniques Pepinillo supports.
/// Each maps 1:1 to a `FocusModeStrategy` implementation.
public enum FocusMode: String, Codable, CaseIterable, Sendable, Identifiable {
    case pomodoro
    case flowtime
    case timeBlock
    case stopwatch

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .pomodoro:  return String(localized: "Pomodoro")
        case .flowtime:  return String(localized: "Flowtime")
        case .timeBlock: return String(localized: "Block")
        case .stopwatch: return String(localized: "Stopwatch")
        }
    }

    public var icon: String {
        switch self {
        case .pomodoro:  return "🍅"
        case .flowtime:  return "🌊"
        case .timeBlock: return "📦"
        case .stopwatch: return "⏱️"
        }
    }

    public var systemImage: String {
        switch self {
        case .pomodoro:  return "timer"
        case .flowtime:  return "wind"
        case .timeBlock: return "rectangle.split.3x1"
        case .stopwatch: return "stopwatch"
        }
    }

    /// Whether this mode counts down (has a target) or counts up (open-ended).
    public var direction: TimerDirection {
        switch self {
        case .pomodoro, .timeBlock: return .countDown
        case .flowtime, .stopwatch: return .countUp
        }
    }

    /// Whether the free tier includes this mode.
    public var isFreeTier: Bool {
        switch self {
        case .pomodoro, .stopwatch: return true
        case .flowtime, .timeBlock: return false
        }
    }
}

// MARK: - Timer Direction

public enum TimerDirection: String, Codable, Sendable {
    case countDown  // Pomodoro, Time Block — shows remaining
    case countUp    // Flowtime, Stopwatch — shows elapsed
}

// MARK: - Focus Phase

/// The current phase within a focus session.
/// Different modes use different subsets of phases.
public enum FocusPhase: Codable, Sendable, Equatable, Hashable {
    // Pomodoro phases
    case work(number: Int, total: Int)   // e.g., work(number: 3, total: 4)
    case shortBreak
    case longBreak

    // Flowtime phases
    case flow                              // open-ended focus
    case flowBreak(suggestedDuration: TimeInterval) // dynamic break

    // Time Block phase
    case block                             // single continuous block

    // Stopwatch phase
    case freeform                          // just counting

    // Universal
    case idle                              // not in a session
    case paused                            // any mode can be paused

    public var isWork: Bool {
        switch self {
        case .work, .flow, .block, .freeform: return true
        default: return false
        }
    }

    public var isBreak: Bool {
        switch self {
        case .shortBreak, .longBreak, .flowBreak: return true
        default: return false
        }
    }

    public var displayName: String {
        switch self {
        case .work(let n, let t):     return String(localized: "Focus \(n)/\(t)")
        case .shortBreak:             return String(localized: "Short Break")
        case .longBreak:              return String(localized: "Long Break")
        case .flow:                   return String(localized: "Flow")
        case .flowBreak:              return String(localized: "Break")
        case .block:                  return String(localized: "Time Block")
        case .freeform:               return String(localized: "Free Focus")
        case .idle:                   return String(localized: "Ready")
        case .paused:                 return String(localized: "Paused")
        }
    }
}

// MARK: - Focus Configuration

/// User-configurable settings per focus mode.
/// These are persisted in UserPreferences (SwiftData).
public struct FocusConfig: Codable, Sendable, Equatable {
    // Pomodoro settings
    public var pomodoroDuration: TimeInterval = 25 * 60        // 25 min
    public var shortBreakDuration: TimeInterval = 5 * 60       // 5 min
    public var longBreakDuration: TimeInterval = 15 * 60       // 15 min
    public var pomodorosPerCycle: Int = 4                       // long break every N
    public var autoStartBreaks: Bool = true
    public var autoStartWork: Bool = false

    /// Next Pomodoro work number given how many work sessions were already completed today.
    /// Wraps at `pomodorosPerCycle` so a full cycle restarts at 1.
    public func nextPomodoroNumber(completedWorkSessionsToday: Int) -> Int {
        let cycle = max(1, pomodorosPerCycle)
        return (completedWorkSessionsToday % cycle) + 1
    }

    // Time Block settings
    public var defaultBlockDuration: TimeInterval = 60 * 60    // 1 hour
    public var blockMidpointCheckIn: Bool = false               // optional halfway reminder

    // Flowtime settings
    public var flowtimeMinSessionMinutes: Int = 5               // minimum before break suggestion
    public var flowtimeShowBreakSuggestion: Bool = true         // show or auto-trigger break

    // General
    public var soundEnabled: Bool = true
    public var hapticEnabled: Bool = true
    public var keepScreenOn: Bool = false

    public init() {}
    
    public init(
        pomodoroDuration: TimeInterval = 25 * 60,
        shortBreakDuration: TimeInterval = 5 * 60,
        longBreakDuration: TimeInterval = 15 * 60,
        pomodorosPerCycle: Int = 4,
        autoStartBreaks: Bool = true,
        autoStartWork: Bool = false,
        defaultBlockDuration: TimeInterval = 60 * 60,
        blockMidpointCheckIn: Bool = false,
        flowtimeMinSessionMinutes: Int = 5,
        flowtimeShowBreakSuggestion: Bool = true,
        soundEnabled: Bool = true,
        hapticEnabled: Bool = true,
        keepScreenOn: Bool = false
    ) {
        self.pomodoroDuration = pomodoroDuration
        self.shortBreakDuration = shortBreakDuration
        self.longBreakDuration = longBreakDuration
        self.pomodorosPerCycle = pomodorosPerCycle
        self.autoStartBreaks = autoStartBreaks
        self.autoStartWork = autoStartWork
        self.defaultBlockDuration = defaultBlockDuration
        self.blockMidpointCheckIn = blockMidpointCheckIn
        self.flowtimeMinSessionMinutes = flowtimeMinSessionMinutes
        self.flowtimeShowBreakSuggestion = flowtimeShowBreakSuggestion
        self.soundEnabled = soundEnabled
        self.hapticEnabled = hapticEnabled
        self.keepScreenOn = keepScreenOn
    }
    
    public static let `default` = FocusConfig()
}

// MARK: - Session State (in-memory, live)

/// Represents the current live state of an active focus session.
/// This is NOT persisted — it's the in-memory working state the FocusEngine manages.
public struct FocusSessionState: Sendable, Equatable {
    public let id: UUID
    public let mode: FocusMode
    public var phase: FocusPhase
    public var startedAt: Date
    public var elapsedSeconds: TimeInterval = 0
    public var targetDuration: TimeInterval?       // nil for count-up modes
    public var remainingSeconds: TimeInterval?     // nil for count-up modes
    public var progress: Double?                   // 0.0–1.0 for countdown, nil for count-up
    public var interruptions: Int = 0
    public var isPaused: Bool = false
    public var pausedAt: Date?
    public var totalPausedDuration: TimeInterval = 0
    public var linkedTaskID: UUID?
    public var pomodoroNumber: Int?                // only for Pomodoro mode
    public var totalPomodoros: Int?                 // pomodorosPerCycle (Pomodoro mode only)

    public var isActive: Bool { !isPaused && phase != .idle }

    /// Computed elapsed excluding paused time.
    public var effectiveElapsed: TimeInterval {
        if isPaused, let pauseStart = pausedAt {
            let pauseTime = Date.now.timeIntervalSince(pauseStart)
            return elapsedSeconds - pauseTime
        }
        return elapsedSeconds
    }
    
    public init(
        id: UUID,
        mode: FocusMode,
        phase: FocusPhase,
        startedAt: Date,
        elapsedSeconds: TimeInterval = 0,
        targetDuration: TimeInterval? = nil,
        remainingSeconds: TimeInterval? = nil,
        progress: Double? = nil,
        interruptions: Int = 0,
        isPaused: Bool = false,
        pausedAt: Date? = nil,
        totalPausedDuration: TimeInterval = 0,
        linkedTaskID: UUID? = nil,
        pomodoroNumber: Int? = nil,
        totalPomodoros: Int? = nil
    ) {
        self.id = id
        self.mode = mode
        self.phase = phase
        self.startedAt = startedAt
        self.elapsedSeconds = elapsedSeconds
        self.targetDuration = targetDuration
        self.remainingSeconds = remainingSeconds
        self.progress = progress
        self.interruptions = interruptions
        self.isPaused = isPaused
        self.pausedAt = pausedAt
        self.totalPausedDuration = totalPausedDuration
        self.linkedTaskID = linkedTaskID
        self.pomodoroNumber = pomodoroNumber
        self.totalPomodoros = totalPomodoros
    }
}

// MARK: - Engine Events

/// Events the FocusEngine emits. The TCA reducer observes these via AsyncStream.
public enum FocusEngineEvent: Sendable {
    case tick(FocusSessionState)
    case phaseCompleted(FocusPhase)
    case sessionCompleted(FocusSessionResult)
    case breakSuggested(duration: TimeInterval)
    case midpointReached
    case interrupted
    /// Emitted when auto-start is OFF for the upcoming phase.
    /// The engine is now holding — no countdown is running — waiting for the user
    /// to tap the CTA before the next phase begins.
    case waitingForNextPhase(FocusPhase)
}

// MARK: - Session Result (after completion)

/// The outcome of a completed focus session, ready to persist.
public struct FocusSessionResult: Sendable, Equatable {
    public let id: UUID
    public let mode: FocusMode
    public let phase: FocusPhase
    public let startedAt: Date
    public let endedAt: Date
    public let targetDuration: TimeInterval?
    public let actualDuration: TimeInterval
    public let wasCompleted: Bool            // did the user finish vs abandon?
    public let interruptions: Int
    public let pomodoroNumber: Int?
    public let linkedTaskID: UUID?
    public let pauseCount: Int               // how many times the user paused
    public let totalPauseDuration: TimeInterval  // total time spent in pause
    /// Session-total focus time across all focus phases (S1). For single-phase
    /// sessions this equals `actualDuration`; for multi-phase sessions (Flowtime)
    /// `actualDuration` carries only the last phase while this carries the total.
    public let totalFocusSeconds: TimeInterval

    public init(
        id: UUID,
        mode: FocusMode,
        phase: FocusPhase,
        startedAt: Date,
        endedAt: Date,
        targetDuration: TimeInterval?,
        actualDuration: TimeInterval,
        wasCompleted: Bool,
        interruptions: Int,
        pomodoroNumber: Int?,
        linkedTaskID: UUID?,
        pauseCount: Int = 0,
        totalPauseDuration: TimeInterval = 0,
        totalFocusSeconds: TimeInterval = 0
    ) {
        self.id = id
        self.mode = mode
        self.phase = phase
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.targetDuration = targetDuration
        self.actualDuration = actualDuration
        self.wasCompleted = wasCompleted
        self.interruptions = interruptions
        self.pomodoroNumber = pomodoroNumber
        self.linkedTaskID = linkedTaskID
        self.pauseCount = pauseCount
        self.totalPauseDuration = totalPauseDuration
        self.totalFocusSeconds = totalFocusSeconds
    }

    /// Copy with `actualDuration` replaced, keeping the session total.
    /// Used when persisting multi-phase session totals (S1).
    public func withActualDuration(_ duration: TimeInterval) -> FocusSessionResult {
        FocusSessionResult(
            id: id,
            mode: mode,
            phase: phase,
            startedAt: startedAt,
            endedAt: endedAt,
            targetDuration: targetDuration,
            actualDuration: duration,
            wasCompleted: wasCompleted,
            interruptions: interruptions,
            pomodoroNumber: pomodoroNumber,
            linkedTaskID: linkedTaskID,
            pauseCount: pauseCount,
            totalPauseDuration: totalPauseDuration,
            totalFocusSeconds: totalFocusSeconds
        )
    }
}
