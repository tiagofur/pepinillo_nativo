// FocusEngine.swift
// Pepinillo — Deep Work Companion for Apple
//
// The unified focus engine that drives ALL 4 modes through a single actor.
// Uses Date arithmetic (not Timer.scheduledTimer) for drift-free accuracy.
//
// Architecture:
// - Receives a FocusModeStrategy at session start
// - Delegates all mode-specific logic to the strategy
// - Manages timing, pausing, phase transitions, and session lifecycle
// - Broadcasts state via AsyncStream for the TCA reducer to consume
//
// Why an Actor?
// - Timer state is mutable and accessed from multiple contexts (UI, background, Watch)
// - Actor isolation guarantees thread safety without manual locking
// - Swift 6 strict concurrency compatible

import Foundation

// MARK: - Engine Events
// FocusEngineEvent is defined in FocusModels.swift so it's available to all targets.

// MARK: - Focus Engine Actor

public actor FocusEngine {
    // MARK: - Private State

    private var strategy: (any FocusModeStrategy)?
    private var config: FocusConfig = .default
    private var timerTask: Task<Void, Never>?
    private var state: FocusSessionState?

    // Date-based timing (drift-free)
    private var phaseStartDate: Date?
    private var totalPausedDuration: TimeInterval = 0

    // For Pomodoro: track which number we're on across phase transitions
    private var currentPomodoroNumber: Int = 1

    // Pause tracking
    private var pauseCount: Int = 0
    private var phaseBeforePause: FocusPhase?

    // Event broadcasting
    private var eventContinuation: AsyncStream<FocusEngineEvent>.Continuation?
    private(set) var events: AsyncStream<FocusEngineEvent>?

    // MARK: - Lifecycle

    public init() {
        let (stream, continuation) = AsyncStream<FocusEngineEvent>.makeStream()
        self.events = stream
        self.eventContinuation = continuation
    }

    deinit {
        timerTask?.cancel()
        eventContinuation?.finish()
    }

    // MARK: - Public API

    /// Start a new focus session with the given mode and configuration.
    public func start(
        mode: FocusMode,
        config: FocusConfig = .default,
        linkedTaskID: UUID? = nil,
        customDuration: TimeInterval? = nil
    ) {
        // Cancel any existing session
        stop(completed: false)

        // Create a fresh event stream for the new session.
        // AsyncStream is single-consumer: once iterated and cancelled,
        // it cannot be re-iterated. A new stream is needed per session.
        eventContinuation?.finish()
        let (stream, continuation) = AsyncStream<FocusEngineEvent>.makeStream()
        self.events = stream
        self.eventContinuation = continuation

        let strategy = mode.strategy
        self.strategy = strategy
        self.config = config
        self.currentPomodoroNumber = 1

        // Use custom duration for Time Block if provided
        var effectiveConfig = config
        if let custom = customDuration, mode == .timeBlock {
            effectiveConfig.defaultBlockDuration = custom
        }
        self.config = effectiveConfig

        let initialPhase = strategy.initialPhase(config: effectiveConfig)
        let targetDuration = strategy.targetDuration(config: effectiveConfig, phase: initialPhase)

        // Pomodoro starts at work(1, total)
        let phase: FocusPhase
        if case .work(_, let total) = initialPhase {
            phase = .work(number: 1, total: total)
        } else {
            phase = initialPhase
        }

        let sessionState = FocusSessionState(
            id: UUID(),
            mode: mode,
            phase: phase,
            startedAt: Date.now,
            targetDuration: targetDuration,
            remainingSeconds: targetDuration,
            progress: targetDuration != nil ? 0.0 : nil,
            linkedTaskID: linkedTaskID,
            pomodoroNumber: mode == .pomodoro ? 1 : nil,
            totalPomodoros: mode == .pomodoro ? effectiveConfig.pomodorosPerCycle : nil
        )

        self.state = sessionState
        self.phaseStartDate = Date.now
        self.totalPausedDuration = 0

        startTicking()
    }

    /// Pause the current session.
    public func pause() {
        guard var current = state, !current.isPaused else { return }
        phaseBeforePause = current.phase
        current.isPaused = true
        current.pausedAt = Date.now
        current.phase = .paused
        state = current
        pauseCount += 1

        timerTask?.cancel()
        timerTask = nil

        emit(.tick(current))
    }

    /// Resume a paused session.
    public func resume() {
        guard var current = state, current.isPaused, let pauseStart = current.pausedAt else { return }

        let pauseDuration = Date.now.timeIntervalSince(pauseStart)
        totalPausedDuration += pauseDuration

        current.isPaused = false
        current.pausedAt = nil
        current.totalPausedDuration = totalPausedDuration

        // Restore the phase that was active before pause
        if strategy != nil {
            restorePhaseAfterPause(&current)
        }

        state = current
        startTicking()
    }

    /// Stop the current session (user-initiated or completed).
    public func stop(completed: Bool = true) {
        timerTask?.cancel()
        timerTask = nil

        guard let current = state, strategy != nil else {
            reset()
            return
        }

        let result = FocusSessionResult(
            id: current.id,
            mode: current.mode,
            phase: current.phase,
            startedAt: current.startedAt,
            endedAt: Date.now,
            targetDuration: current.targetDuration,
            actualDuration: current.elapsedSeconds,
            wasCompleted: completed,
            interruptions: current.interruptions,
            pomodoroNumber: current.pomodoroNumber,
            linkedTaskID: current.linkedTaskID,
            pauseCount: pauseCount,
            totalPauseDuration: totalPausedDuration
        )

        emit(.sessionCompleted(result))
        reset()
    }

    /// Record an interruption (phone call, notification tap, etc.)
    public func recordInterruption() {
        guard var current = state else { return }
        current.interruptions += 1
        state = current
        emit(.interrupted)
    }

    /// Skip to the next phase (e.g., skip break in Pomodoro, or end Flowtime session).
    public func skipToNextPhase() {
        guard let current = state, strategy != nil else { return }
        advancePhase(from: current.phase, elapsed: current.elapsedSeconds)
    }

    /// Get the current session state snapshot.
    public func currentState() -> FocusSessionState? {
        state
    }

    /// Update the focus configuration while a session is active.
    /// If the session is in a timed phase, adjusts targetDuration so
    /// remaining = newTarget - elapsed (timer keeps running, no restart).
    public func updateConfig(_ newConfig: FocusConfig) {
        let oldConfig = config
        config = newConfig

        guard var current = state, strategy != nil else { return }

        // Determine if the current phase is duration-sensitive (work phase uses pomodoroDuration).
        let phaseTargetChanged: Bool
        switch current.phase {
        case .work:
            phaseTargetChanged = oldConfig.pomodoroDuration != newConfig.pomodoroDuration
        case .shortBreak:
            phaseTargetChanged = oldConfig.shortBreakDuration != newConfig.shortBreakDuration
        case .longBreak:
            phaseTargetChanged = oldConfig.longBreakDuration != newConfig.longBreakDuration
        case .block:
            phaseTargetChanged = oldConfig.defaultBlockDuration != newConfig.defaultBlockDuration
        default:
            phaseTargetChanged = false
        }

        guard phaseTargetChanged, let strategy = strategy else { return }

        // Recalculate target for current phase using new config.
        guard let updatedTarget = strategy.targetDuration(config: newConfig, phase: current.phase) else { return }

        let elapsed = current.elapsedSeconds
        let newRemaining = max(0, updatedTarget - elapsed)

        current.targetDuration = updatedTarget
        current.remainingSeconds = newRemaining
        current.progress = elapsed / updatedTarget

        state = current
    }

    /// Resets the Pomodoro cycle counter when the calendar day changes.
    /// The current session (if any) continues normally — it will count as #1 of the new day.
    public func resetForNewDay() {
        currentPomodoroNumber = 1
    }

    /// Sync with an external state change (e.g. from a widget) to align internal timing anchors.
    public func syncExternalState(elapsed: TimeInterval, remaining: TimeInterval?) {
        guard var current = state, current.isPaused else { return }
        
        if let start = phaseStartDate {
            let now = Date.now
            // effectiveElapsed = now - start - totalPausedDuration
            // totalPausedDuration = now - start - effectiveElapsed
            self.totalPausedDuration = now.timeIntervalSince(start) - elapsed
            current.elapsedSeconds = elapsed
            current.remainingSeconds = remaining
            if let target = current.targetDuration, let rem = remaining {
                current.progress = 1.0 - (rem / target)
            }
            self.state = current
            emit(.tick(current))
        }
    }

    // MARK: - Private: Timing Loop

    private func startTicking() {
        timerTask?.cancel()
        timerTask = Task { [weak self] in
            // Tick at 10Hz for smooth UI updates
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(100))
                await self?.tick()
            }
        }
    }

    private func tick() {
        guard var current = state,
              !current.isPaused,
              let phaseStart = phaseStartDate,
              let strategy = strategy else { return }

        // Date arithmetic: immune to Timer drift and background suspension
        let rawElapsed = Date.now.timeIntervalSince(phaseStart)
        let effectiveElapsed = rawElapsed - totalPausedDuration
        current.elapsedSeconds = max(0, effectiveElapsed)

        // Update remaining/progress for countdown modes
        if strategy.hasTarget, let target = current.targetDuration {
            let remaining = max(0, target - effectiveElapsed)
            current.remainingSeconds = remaining
            current.progress = 1.0 - (remaining / target)

            // Check for midpoint notification (Time Block)
            if current.mode == .timeBlock,
               config.blockMidpointCheckIn,
               effectiveElapsed >= target / 2,
               (effectiveElapsed - 0.1) < target / 2 {
                emit(.midpointReached)
            }

            // Phase complete?
            if remaining <= 0 {
                current.remainingSeconds = 0
                current.progress = 1.0
                state = current
                emit(.tick(current))
                phaseComplete()
                return
            }
        }

        state = current
        emit(.tick(current))
    }

    // MARK: - Private: Phase Management

    private func phaseComplete() {
        guard let current = state, let strategy = strategy else { return }

        emit(.phaseCompleted(current.phase))

        // Should we auto-advance?
        if strategy.supportsAutoAdvance {
            advancePhase(from: current.phase, elapsed: current.elapsedSeconds)
        } else {
            // Stop and report completion
            stop(completed: true)
        }
    }

    private func advancePhase(from phase: FocusPhase, elapsed: TimeInterval) {
        guard var current = state, let strategy = strategy else { return }

        guard let nextPhase = strategy.nextPhase(after: phase, elapsed: elapsed, config: config) else {
            // No more phases — session complete
            stop(completed: true)
            return
        }

        // For Pomodoro: increment the work number
        var resolvedPhase = nextPhase
        if case .work(_, let total) = nextPhase, current.mode == .pomodoro {
            currentPomodoroNumber += 1
            resolvedPhase = .work(number: currentPomodoroNumber, total: total)
            current.pomodoroNumber = currentPomodoroNumber
        }

        // Reset phase timing
        let newTarget = strategy.targetDuration(config: config, phase: resolvedPhase)
        current.phase = resolvedPhase
        current.targetDuration = newTarget
        current.remainingSeconds = newTarget
        current.progress = newTarget != nil ? 0.0 : nil
        current.elapsedSeconds = 0

        state = current
        phaseStartDate = Date.now
        totalPausedDuration = 0

        emit(.tick(current))
    }

    private func restorePhaseAfterPause(_ current: inout FocusSessionState) {
        // Restore the exact phase that was active before the pause.
        // This correctly handles pausing during breaks (short break, long break, flow break).
        if let savedPhase = phaseBeforePause {
            current.phase = savedPhase
            phaseBeforePause = nil
        } else {
            // Fallback: restore to the default work phase for the mode
            switch current.mode {
            case .pomodoro:
                current.phase = .work(number: currentPomodoroNumber, total: config.pomodorosPerCycle)
            case .flowtime:
                current.phase = .flow
            case .timeBlock:
                current.phase = .block
            case .stopwatch:
                current.phase = .freeform
            }
        }
    }

    // MARK: - Private: Helpers

    private func emit(_ event: FocusEngineEvent) {
        eventContinuation?.yield(event)
    }

    private func reset() {
        strategy = nil
        state = nil
        phaseStartDate = nil
        totalPausedDuration = 0
        currentPomodoroNumber = 1
        pauseCount = 0
        phaseBeforePause = nil
    }
}
