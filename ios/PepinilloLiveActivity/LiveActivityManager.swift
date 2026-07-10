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

    // MARK: - Launch reconciliation

    /// Adopt or dismiss system Live Activities left behind after a process kill.
    func reconcileOrphanActivitiesOnLaunch() async {
        let existing = Activity<FocusActivityAttributes>.activities
        guard !existing.isEmpty else { return }

        let hasActiveSession = AppGroupDefaults.isSessionActive
            && AppGroupDefaults.activeModeName != nil

        if !hasActiveSession {
            await endAllActivities()
            return
        }

        // Reclaim the most recent activity so updates resume without creating duplicates.
        let adopted = existing.max(by: { $0.content.state.elapsedSeconds < $1.content.state.elapsedSeconds })
            ?? existing[0]
        activity = adopted

        for orphan in existing where orphan.id != adopted.id {
            await orphan.end(nil, dismissalPolicy: .immediate)
        }
    }

    // MARK: - Public API

    func startActivity(sessionState: FocusSessionState, taskName: String?) async {
        await endAllActivities()

        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        var attributes = FocusActivityAttributes.from(state: sessionState)
        attributes.taskName = taskName

        let initialContent = FocusActivityAttributes.contentState(from: sessionState, taskName: taskName)
        let staleDate = FocusActivityAttributes.staleDate(for: sessionState)

        do {
            activity = try Activity<FocusActivityAttributes>.request(
                attributes: attributes,
                content: ActivityContent(state: initialContent, staleDate: staleDate),
                pushType: nil
            )
        } catch {
            // Non-critical: continue without Live Activity
        }
    }

    func updateActivity(sessionState: FocusSessionState, taskName: String?) async {
        if activity == nil, !Activity<FocusActivityAttributes>.activities.isEmpty {
            await reconcileOrphanActivitiesOnLaunch()
        }
        guard let current = activity else { return }

        let newState = FocusActivityAttributes.contentState(from: sessionState, taskName: taskName)
        let staleDate = FocusActivityAttributes.staleDate(for: sessionState)

        await current.update(ActivityContent(state: newState, staleDate: staleDate))
    }

    func endActivity(wasCompleted: Bool) async {
        await endAllActivities()
    }

    // MARK: - Private

    private func endAllActivities() async {
        activity = nil
        for existing in Activity<FocusActivityAttributes>.activities {
            await existing.end(nil, dismissalPolicy: .immediate)
        }
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
            },
            reconcileOnLaunch: {
                await LiveActivityManager.shared.reconcileOrphanActivitiesOnLaunch()
            }
        )
    }
}