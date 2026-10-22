// MacSpotlightIndexer.swift
// Pepinillo — native macOS Spotlight integration
//
// Indexes open tasks into macOS Spotlight so they are searchable system-wide;
// selecting a result continues a `CSSearchableItemActionType` activity, which
// `MacAppDelegate` translates into the existing `pepinillo://task/` deep link.
//
// There is no reactive handle on the task store outside views, so the indexer
// fingerprints the task list on a slow timer and reindexes only real changes.

import CoreSpotlight
import ComposableArchitecture
import OSLog
import UniformTypeIdentifiers

@MainActor
final class MacSpotlightIndexer {
    static let domain = "tasks"

    private struct Fingerprint: Equatable {
        let id: UUID
        let title: String
        let isCompleted: Bool
    }

    private var store: StoreOf<AppFeature>?
    private var fingerprint: [Fingerprint] = []
    private var timer: Timer?
    private var isIndexedOnce = false

    func install(store: StoreOf<AppFeature>) {
        self.store = store
        indexIfNeeded()

        let timer = Timer(timeInterval: 10, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.indexIfNeeded() }
        }
        timer.tolerance = 3
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func indexIfNeeded() {
        guard let store else { return }
        let (next, tasks) = store.withState { state in
            let marks = state.tasks.tasks.map {
                Fingerprint(id: $0.id, title: $0.title, isCompleted: $0.isCompleted)
            }
            return (marks, Array(state.tasks.tasks))
        }
        guard !isIndexedOnce || next != fingerprint else { return }
        fingerprint = next
        isIndexedOnce = true
        reindex(tasks)
    }

    private func reindex(_ tasks: [TaskListFeature.TaskItemState]) {
        let index = CSSearchableIndex.default()
        let items = tasks
            .filter { !$0.isCompleted && !$0.isRecurringTemplate }
            .map(taskItem)

        index.deleteSearchableItems(withDomainIdentifiers: [Self.domain]) { [weak self] deleteError in
            if let deleteError {
                self?.log(deleteError, phase: "delete")
            }
            guard !items.isEmpty else { return }
            index.indexSearchableItems(items) { indexError in
                if let indexError {
                    self?.log(indexError, phase: "index")
                }
            }
        }
    }

    private func taskItem(_ task: TaskListFeature.TaskItemState) -> CSSearchableItem {
        let attributes = CSSearchableItemAttributeSet(contentType: .text)
        attributes.title = task.title
        if let notes = task.notes, !notes.isEmpty {
            attributes.contentDescription = notes
        }
        attributes.keywords = [task.energyLevel.displayName, task.priority.displayName]

        return CSSearchableItem(
            uniqueIdentifier: task.id.uuidString,
            domainIdentifier: Self.domain,
            attributeSet: attributes
        )
    }

    private static let log = Logger(subsystem: "com.pepinillo.app", category: "mac-spotlight")

    private func log(_ error: Error, phase: String) {
        // Spotlight indexing failures are silent by design in the UI; keep a
        // breadcrumb for Console diagnostics.
        Self.log.error("Spotlight \(phase, privacy: .public) failed: \(String(describing: error), privacy: .public)")
    }
}
