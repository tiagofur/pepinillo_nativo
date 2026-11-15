// ExtensionContainerTests.swift
// Pepinillo — Deep Work Companion for Apple
//
// #674: extension processes must open the shared store WITHOUT a migration
// plan — SwiftData's staged-migration evaluator SIGTRAPs (uncatchable
// EXC_BREAKPOINT) when it runs inside a WidgetKit extension on macOS 27,
// killing every timeline render and freezing the widget on App Store
// builds. Without the plan, problems surface as thrown errors the widget
// providers already catch, rendering a fail-safe idle entry instead.
//
// The mismatch behavior (throw vs. trap) was verified empirically against
// seeded V1/V6 temp stores; in-process seeding locks the SQLite file from
// the test host, so these tests pin the REAL contract end-to-end: the
// public extension entrypoint opens the actual shared store cleanly.

import Testing
import SwiftData
@testable import Pepinillo

@Suite(.serialized)
struct ExtensionContainerTests {

    /// The path every widget/intents provider takes must open the shared
    /// app-group store without a migration plan and without trapping.
    /// If this ever traps or throws, #674 regressed.
    @Test func widgetContainerPathOpensSharedStore() throws {
        resetExtensionModelContainerCacheForTesting()
        let container = try makeWidgetModelContainer()
        // Sanity: the store answers a trivial fetch through a fresh context.
        let context = ModelContext(container)
        let prefs = try context.fetch(FetchDescriptor<UserPreferences>())
        #expect(prefs.count >= 0)
    }

    /// Repeated opens go through the cache and stay stable — a timeline
    /// reload must not need a fresh container each render.
    @Test func widgetContainerPathIsCachedAcrossOpens() throws {
        resetExtensionModelContainerCacheForTesting()
        let first = try makeWidgetModelContainer()
        let second = try makeWidgetModelContainer()
        #expect(first === second)
    }
}
