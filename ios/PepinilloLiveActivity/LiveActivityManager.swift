// LiveActivityManager.swift
// Pepinillo — Deep Work Companion for Apple
//
// Actor that manages the ActivityKit Live Activity lifecycle.
// Lives in the PepinilloLiveActivity module which has ActivityKit access.
// Called from FocusFeature via LiveActivityClient.activityKit().

@preconcurrency import ActivityKit
import Foundation

// MARK: - Live Activity Manager

/// Thread-safe actor managing a single active Focus Live Activity.
@available(iOS 16.2, *)
actor LiveActivityManager {
    static let shared = LiveActivityManager()

    private var activity: Activity<FocusActivityAttributes>?

    // MARK: - Public API

    func startActivity(sessionState: FocusSessionState, taskName: String?) async {
        // End any existing activity
        await endActivity(wasCompleted: false)

        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        var attributes = FocusActivityAttributes.from(state: sessionState)
        attributes.taskName = taskName

        var initialContent = FocusActivityAttributes.initialContent(from: sessionState)
        initialContent.taskName = taskName

        do {
            activity = try Activity<FocusActivityAttributes>.request(
                attributes: attributes,
                content: ActivityContent(state: initialContent, staleDate: nil),
                pushType: nil
            )
        } catch {
            // Non-critical: continue without Live Activity
        }
    }

    func updateActivity(sessionState: FocusSessionState, taskName: String?) async {
        guard let current = activity else { return }

        let newState = FocusActivityAttributes.ContentState(
            elapsedSeconds: Int(sessionState.elapsedSeconds),
            remainingSeconds: sessionState.remainingSeconds.map(Int.init),
            focusMode: sessionState.mode.rawValue,
            phase: sessionState.phase.displayName,
            taskName: taskName,
            progress: sessionState.progress,
            pomodoroNumber: sessionState.pomodoroNumber,
            totalPomodoros: sessionState.totalPomodoros,
            isPaused: sessionState.isPaused
        )

        await current.update(ActivityContent(state: newState, staleDate: nil))
    }

    func endActivity(wasCompleted: Bool) async {
        guard let current = activity else { return }
        activity = nil
        await current.end(nil, dismissalPolicy: .immediate)
    }

    // MARK: - LiveActivityClient factory

    /// Creates a LiveActivityClient backed by this manager.
    nonisolated static func makeClient() -> LiveActivityClient {
        LiveActivityClient(
            start: { sessionState, taskName in
                await LiveActivityManager.shared.startActivity(
                    sessionState: sessionState,
                    taskName: taskName
                )
            },
            update: { sessionState, taskName in
                await LiveActivityManager.shared.updateActivity(sessionState: sessionState, taskName: taskName)
            },
            end: { wasCompleted in
                await LiveActivityManager.shared.endActivity(wasCompleted: wasCompleted)
            },
            isAvailable: {
                ActivityAuthorizationInfo().areActivitiesEnabled
            }
        )
    }
}
