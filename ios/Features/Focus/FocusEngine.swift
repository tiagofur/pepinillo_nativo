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

    // Waiting-for-next-phase gate (auto-start OFF)
    // When set, the tick loop is suspended and the user must call startNextPhase().
    private var pendingNextPhase: FocusPhase?

    // Pause tracking
    private var pauseCount: Int = 0
    private var phaseBeforePause: FocusPhase?

    // Flowtime: emit breakSuggested once per flow phase when threshold is reached
    private var breakSuggestionEmitted = false

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
        customDuration: TimeInterval? = nil,
        timerStart: Date? = nil,
        timerEnd: Date? = nil,
        completedWorkSessionsToday: Int = 0
    ) {
        // Cancel any existing session
        stop(completed: false)

        // Create a fresh event stream for the new session.
        eventContinuation?.finish()
        let (stream, continuation) = AsyncStream<FocusEngineEvent>.makeStream()
        self.events = stream
        self.eventContinuation = continuation

        let strategy = mode.strategy
        self.strategy = strategy
        self.config = config

        // Use custom duration for Time Block if provided
        var effectiveConfig = config
        if let custom = customDuration, mode == .timeBlock {
            effectiveConfig.defaultBlockDuration = custom
        }
        self.config = effectiveConfig

        let seededPomodoroNumber = mode == .pomodoro
            ? effectiveConfig.nextPomodoroNumber(completedWorkSessionsToday: completedWorkSessionsToday)
            : 1
        self.currentPomodoroNumber = seededPomodoroNumber

        let initialPhase = strategy.initialPhase(config: effectiveConfig)
        let targetDuration = strategy.targetDuration(config: effectiveConfig, phase: initialPhase)

        // Pomodoro starts at work(N, total) where N reflects today's completed sessions.
        let phase: FocusPhase
        if case .work(_, let total) = initialPhase, mode == .pomodoro {
            phase = .work(number: seededPomodoroNumber, total: total)
        } else if case .work(_, let total) = initialPhase {
            phase = .work(number: 1, total: total)
        } else {
            phase = initialPhase
        }

        // Calculate initial elapsed/remaining if started from widget anchors
        let now = Date.now
        let effectiveStart = timerStart ?? now
        let effectiveElapsed = now.timeIntervalSince(effectiveStart)
        let effectiveRemaining: TimeInterval?
        if let target = targetDuration {
            effectiveRemaining = max(0, target - effectiveElapsed)
        } else {
            effectiveRemaining = nil
        }

        let sessionState = FocusSessionState(
            id: UUID(),
            mode: mode,
            phase: phase,
            startedAt: effectiveStart,
            elapsedSeconds: max(0, effectiveElapsed),
            targetDuration: targetDuration,
            remainingSeconds: effectiveRemaining,
            progress: targetDuration != nil ? min(max(effectiveElapsed / targetDuration!, 0), 1) : nil,
            linkedTaskID: linkedTaskID,
            pomodoroNumber: mode == .pomodoro ? seededPomodoroNumber : nil,
            totalPomodoros: mode == .pomodoro ? effectiveConfig.pomodorosPerCycle : nil
        )

        self.state = sessionState
        self.phaseStartDate = effectiveStart
        self.totalPausedDuration = 0
        self.breakSuggestionEmitted = false

        startTicking()
    }

    /// Pause the current session.
    public func pause() {
        guard var current = state, !current.isPaused else { return }
        // FIX 4: During the waiting-for-next-phase hold the tick task is already
        // cancelled and no countdown is running. Pausing a hold has no meaningful
        // effect and would set phaseBeforePause to the completed phase (remaining = 0),
        // causing resume() → startTicking() → phaseComplete() to fire again (double
        // pomodoro increment). Guard here so pause is a no-op in this state.
        guard pendingNextPhase == nil else { return }
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
        // FIX 4: Mirror the pause() guard — if we somehow reach resume() while in the
        // waiting hold (e.g. Watch sends a resume after a pause that was itself a no-op),
        // do nothing. The hold is not a paused countdown; the CTA is the only exit.
        guard pendingNextPhase == nil else { return }
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
        // FIX 3: If we are in the waiting-for-next-phase hold (auto-start OFF),
        // a skip command (e.g. from the Watch) must advance into the already-resolved
        // pending phase and clear pendingNextPhase — exactly the same code path as
        // startNextPhase(). Re-deriving from the completed phase would double-advance
        // the Pomodoro number and leave pendingNextPhase dirty.
        if pendingNextPhase != nil {
            startNextPhase()
            return
        }
        advancePhase(from: current.phase, elapsed: current.elapsedSeconds)
    }

    /// Advance from the waiting-for-next-phase hold state into the pending next phase and
    /// start its countdown. Called when the user taps the CTA after auto-start is OFF.
    public func startNextPhase() {
        guard let pending = pendingNextPhase, let current = state else { return }
        pendingNextPhase = nil
        // Advance directly into the pending phase (already computed in phaseComplete).
        advancePhase(toResolved: pending, from: current)
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
        guard var current = state else { return }
        
        if let start = phaseStartDate {
            let now = Date.now
            // effectiveElapsed = now - start - totalPausedDuration
            // totalPausedDuration = now - start - effectiveElapsed
            self.totalPausedDuration = max(0, now.timeIntervalSince(start) - elapsed)
            current.elapsedSeconds = max(0, elapsed)
            current.totalPausedDuration = self.totalPausedDuration
            current.remainingSeconds = remaining
            if let target = current.targetDuration, let rem = remaining {
                current.progress = min(max(1.0 - (rem / target), 0), 1)
            } else {
                current.progress = nil
            }
            self.state = current
            emit(.tick(current))
        }
    }

    /// Apply an externally-triggered pause using the timestamp from the external process.
    /// This keeps elapsed time and future resume math anchored to the widget tap,
    /// not to the later moment when the app wakes up.
    public func applyExternalPause(elapsed: TimeInterval, remaining: TimeInterval?, pausedAt: Date) {
        // During a "waiting for next phase" hold the tick task is already cancelled and
        // there is no running timer — external pause must be a no-op to prevent
        // restoring a completed phase and triggering a double phaseComplete().
        guard pendingNextPhase == nil else { return }
        guard var current = state else { return }

        if !current.isPaused {
            phaseBeforePause = current.phase
            pauseCount += 1
        }

        current.isPaused = true
        current.pausedAt = pausedAt
        current.phase = .paused
        current.elapsedSeconds = max(0, elapsed)
        current.remainingSeconds = remaining
        if let target = current.targetDuration, let remaining {
            current.progress = min(max(1.0 - (remaining / target), 0), 1)
        } else {
            current.progress = nil
        }

        if let start = phaseStartDate {
            totalPausedDuration = max(0, pausedAt.timeIntervalSince(start) - current.elapsedSeconds)
        }
        current.totalPausedDuration = totalPausedDuration

        state = current
        timerTask?.cancel()
        timerTask = nil
        emit(.tick(current))
    }

    /// Apply an externally-triggered resume and align the engine with widget anchors.
    public func applyExternalResume(elapsed: TimeInterval, remaining: TimeInterval?) {
        // During a "waiting for next phase" hold the tick task is already cancelled and
        // there is no running timer — external resume must be a no-op to prevent
        // calling startTicking() with a completed phase (remainingSeconds == 0),
        // which would immediately re-fire phaseComplete() and double-count the interval.
        guard pendingNextPhase == nil else { return }
        guard var current = state else { return }

        if current.isPaused {
            current.isPaused = false
            current.pausedAt = nil
            restorePhaseAfterPause(&current)
        }

        current.elapsedSeconds = max(0, elapsed)
        current.remainingSeconds = remaining
        if let target = current.targetDuration, let remaining {
            current.progress = min(max(1.0 - (remaining / target), 0), 1)
        } else {
            current.progress = nil
        }

        if let start = phaseStartDate {
            totalPausedDuration = max(0, Date.now.timeIntervalSince(start) - current.elapsedSeconds)
        }
        current.totalPausedDuration = totalPausedDuration

        state = current
        startTicking()
        emit(.tick(current))
    }

    // MARK: - Private: Timing Loop

    private func startTicking() {
        timerTask?.cancel()
        timerTask = Task { [weak self] in
            // Tick at 4Hz (250ms). All display modes show whole seconds, so sub-second
            // precision is not needed. The ring uses a linear SwiftUI animation to smooth
            // progress updates between ticks, so the visual is identical to 10Hz.
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(250))
                await self?.tick()
            }
        }
    }

    private func tick() {
        // Handle external pause requests (from widget) immediately, even in background.
        if AppGroupDefaults.externalPauseRequested,
           let current = state,
           current.isPaused == false {
            guard !isStaleExternalPauseCommand(for: current) else {
                AppGroupDefaults.externalPauseRequested = false
                return
            }

            let elapsed = AppGroupDefaults.activeSessionElapsed
            let remaining = AppGroupDefaults.activeSessionRemaining
            let pausedAt = AppGroupDefaults.activeSessionPausedAt ?? Date.now
            
            // Clear the flag so we don't re-pause repeatedly
            AppGroupDefaults.externalPauseRequested = false
            
            applyExternalPause(elapsed: elapsed, remaining: remaining, pausedAt: pausedAt)
            return
        }

        guard var current = state,
              !current.isPaused,
              let phaseStart = phaseStartDate,
              let strategy = strategy else { return }

        // Date arithmetic: immune to Timer drift and background suspension
        let rawElapsed = Date.now.timeIntervalSince(phaseStart)
        let effectiveElapsed = rawElapsed - totalPausedDuration
        current.elapsedSeconds = max(0, effectiveElapsed)

        // Flowtime: optionally suggest a break once the minimum session threshold is met.
        if current.mode == .flowtime,
           current.phase == .flow,
           config.flowtimeShowBreakSuggestion,
           !breakSuggestionEmitted {
            let minSeconds = TimeInterval(config.flowtimeMinSessionMinutes * 60)
            if effectiveElapsed >= minSeconds {
                breakSuggestionEmitted = true
                let duration = strategy.suggestedBreakDuration(afterFocusing: effectiveElapsed)
                emit(.breakSuggested(duration: duration))
            }
        }

        // Update remaining/progress for phases with a target (Pomodoro, TimeBlock, Flowtime break).
        if let target = current.targetDuration {
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

    private func isStaleExternalPauseCommand(for current: FocusSessionState) -> Bool {
        if let issuedAt = AppGroupDefaults.externalCommandIssuedAt {
            return issuedAt < current.startedAt
        }

        if let pausedAt = AppGroupDefaults.activeSessionPausedAt {
            return pausedAt < current.startedAt
        }

        return true
    }

    // MARK: - Private: Phase Management

    private func phaseComplete() {
        guard let current = state, let strategy = strategy else { return }

        emit(.phaseCompleted(current.phase))

        guard strategy.supportsAutoAdvance else {
            // Modes that don't auto-advance (e.g. TimeBlock) stop on completion.
            stop(completed: true)
            return
        }

        // Resolve the next phase before checking the gate so we can carry it in the event.
        guard let nextPhase = strategy.nextPhase(after: current.phase, elapsed: current.elapsedSeconds, config: config) else {
            // No more phases — full cycle complete.
            stop(completed: true)
            return
        }

        // Resolve the actual next phase (Pomodoro work number increment happens here).
        var resolvedNext = nextPhase
        if case .work(_, let total) = nextPhase, current.mode == .pomodoro {
            currentPomodoroNumber += 1
            resolvedNext = .work(number: currentPomodoroNumber, total: total)
        }

        // Gate: check whether auto-start is enabled for the UPCOMING phase type.
        let shouldAutoStart: Bool
        switch current.phase {
        case .work:
            // Work just finished → next is a break. Gate on autoStartBreaks.
            shouldAutoStart = config.autoStartBreaks
        case .shortBreak, .longBreak:
            // Break just finished → next is work. Gate on autoStartWork.
            shouldAutoStart = config.autoStartWork
        default:
            // Non-Pomodoro phases or unexpected cases: always auto-advance.
            shouldAutoStart = true
        }

        if shouldAutoStart {
            // Auto-start is ON: advance immediately (existing behavior).
            advancePhase(toResolved: resolvedNext, from: current)
        } else {
            // Auto-start is OFF: enter the waiting hold.
            // Cancel the tick timer so nothing counts down while we wait.
            timerTask?.cancel()
            timerTask = nil
            pendingNextPhase = resolvedNext
            emit(.waitingForNextPhase(resolvedNext))
        }
    }

    /// Advance to the next phase by re-deriving it from the strategy.
    /// Used by `skipToNextPhase()` (user-initiated skip) where we haven't pre-resolved the next phase.
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

        applyPhaseTransition(to: resolvedPhase, current: &current)
    }

    /// Advance into an already-resolved next phase.
    /// Used by `phaseComplete()` (which pre-resolves to avoid duplicate number increments)
    /// and by `startNextPhase()` (user taps CTA from waiting state).
    private func advancePhase(toResolved resolvedPhase: FocusPhase, from current: FocusSessionState) {
        var mutable = current
        if case .work = resolvedPhase {
            mutable.pomodoroNumber = currentPomodoroNumber
        }
        applyPhaseTransition(to: resolvedPhase, current: &mutable)
    }

    /// Shared phase-transition logic: reset timing state, start ticking, emit tick.
    private func applyPhaseTransition(to resolvedPhase: FocusPhase, current: inout FocusSessionState) {
        guard let strategy = strategy else { return }

        let newTarget = strategy.targetDuration(config: config, phase: resolvedPhase)
        current.phase = resolvedPhase
        current.targetDuration = newTarget
        current.remainingSeconds = newTarget
        current.progress = newTarget != nil ? 0.0 : nil
        current.elapsedSeconds = 0

        state = current
        phaseStartDate = Date.now
        totalPausedDuration = 0

        if current.mode == .flowtime, resolvedPhase == .flow {
            breakSuggestionEmitted = false
        }

        startTicking()
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
        pendingNextPhase = nil
        breakSuggestionEmitted = false
    }
}
