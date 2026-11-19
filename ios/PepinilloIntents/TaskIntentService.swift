// TaskIntentService.swift
// Pepinillo — Deep Work Companion for Apple
//
// Shared pure seam for the task-lifecycle App Intents (#900): the active /
// today query predicates (tombstone- and template-aware) and the
// pepinillo://task deep-link builder. TaskEntityQuery, Siri and Shortcuts
// all answer with the same definition of "active", so a task deleted in the
// app can never surface again through voice.

import Foundation
import SwiftData
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

enum TaskIntentService {

    /// Active = not completed, not tombstoned (`isLocallyDeleted`), not a
    /// recurring template — the same set in-app quick-add counts (#216).
    static func activeTasks(in container: ModelContainer, limit: Int? = nil) -> [TaskItem] {
        let context = ModelContext(container)
        var descriptor = FetchDescriptor<TaskItem>(
            predicate: #Predicate {
                !$0.isCompleted && !$0.isLocallyDeleted && !$0.isRecurringTemplate
            },
            sortBy: [SortDescriptor(\.sortOrder)]
        )
        if let limit { descriptor.fetchLimit = limit }
        return (try? context.fetch(descriptor)) ?? []
    }

    /// Today's plan (S2): active tasks flagged `scheduledForToday`, in plan order.
    static func todayTasks(in container: ModelContainer) -> [TaskItem] {
        activeTasks(in: container).filter(\.scheduledForToday)
    }

    /// The deep-link route both platforms already understand (AppFeature
    /// `.appURLReceived` on iOS, the PepinilloMacApp pipeline on Mac).
    static func deepLinkURL(for id: UUID) -> URL? {
        URL(string: "pepinillo://task/\(id.uuidString)")
    }

    /// Routes a deep link through the OS so the running app navigates to it.
    /// `UIApplication.shared`/`NSWorkspace.shared` are Main-actor isolated:
    /// the helper must hop too, so callers `await` it from `perform()` —
    /// otherwise Swift 6 surfaces the isolation as a build diagnostic.
    @MainActor
    static func open(_ url: URL) {
        #if os(iOS)
        UIApplication.shared.open(url)
        #elseif os(macOS)
        NSWorkspace.shared.open(url)
        #endif
    }
}
