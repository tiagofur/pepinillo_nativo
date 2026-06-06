// SpotlightClient.swift
// Pepinillo — Deep Work Companion for Apple
//
// TCA Dependency Client wrapping CoreSpotlight.
// Indexes TaskItems so users can find and open them via system search.
// CoreSpotlight is not available on watchOS — the client is a no-op there.

import Foundation
import ComposableArchitecture

#if canImport(CoreSpotlight)
import CoreSpotlight
#endif

@DependencyClient
struct SpotlightClient: Sendable {
    /// Index a batch of tasks in Spotlight.
    var indexTasks: @Sendable ([TaskItemDTO]) async throws -> Void

    /// Remove a task from the Spotlight index.
    var deindexTask: @Sendable (UUID) async throws -> Void

    /// Remove all Pepinillo items from the Spotlight index.
    var deleteAll: @Sendable () async throws -> Void
}

extension SpotlightClient: DependencyKey {
    #if canImport(CoreSpotlight)
    static let liveValue: SpotlightClient = {
        nonisolated(unsafe) let index = CSSearchableIndex.default()

        return SpotlightClient(
            indexTasks: { tasks in
                let items = tasks.compactMap { task -> CSSearchableItem? in
                    let attributes = CSSearchableItemAttributeSet(contentType: .content)
                    attributes.title = task.title
                    attributes.contentDescription = task.notes
                    attributes.keywords = ["focus", "task", "pepinillo", task.priority.displayName]

                    if task.dueDate != nil {
                        attributes.dueDate = task.dueDate
                    }

                    return CSSearchableItem(
                        uniqueIdentifier: "task-\(task.id.uuidString)",
                        domainIdentifier: "com.pepinillo.tasks",
                        attributeSet: attributes
                    )
                }
                try await index.indexSearchableItems(items)
            },
            deindexTask: { id in
                try await index.deleteSearchableItems(withIdentifiers: ["task-\(id.uuidString)"])
            },
            deleteAll: {
                try await index.deleteSearchableItems(withDomainIdentifiers: ["com.pepinillo.tasks"])
            }
        )
    }()
    #else
    static let liveValue = SpotlightClient()
    #endif

    static let testValue = SpotlightClient(
        indexTasks: { _ in },
        deindexTask: { _ in },
        deleteAll: {}
    )
}

extension DependencyValues {
    var spotlightClient: SpotlightClient {
        get { self[SpotlightClient.self] }
        set { self[SpotlightClient.self] = newValue }
    }
}
