// PlanCatalogLocalizationTests.swift
// Pepinillo — Deep Work Companion for Apple
//
// Issue #1022: pins the user-facing strings of the energy suggestion
// (and the energy level names) against the string catalog, so a key used
// by EnergySuggestionPrompt can never ship without its es/pt translation
// again — the four keys this issue added rendered as English on every
// locale because they were never entered in the catalog.

import Foundation
import IdentifiedCollections
import Testing
@testable import Pepinillo

/// Parses `Localizable.xcstrings` straight from the repo (via #filePath, so
/// no bundle/locale machinery is involved) and asserts the catalog shape.
@Suite("Plan catalog localization")
struct PlanCatalogLocalizationTests {

    private static let catalogURL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()   // TaskFeatureTests
        .deletingLastPathComponent()   // Tests
        .deletingLastPathComponent()   // ios
        .appendingPathComponent("Shared/Resources/Localizable.xcstrings")

    private static func value(of key: String, locale: String) -> String? {
        guard let data = try? Data(contentsOf: catalogURL),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let strings = root["strings"] as? [String: Any],
              let entry = strings[key] as? [String: Any],
              let localizations = entry["localizations"] as? [String: Any],
              let unit = localizations[locale] as? [String: Any],
              let stringUnit = unit["stringUnit"] as? [String: Any],
              let state = stringUnit["state"] as? String, state == "translated",
              let value = stringUnit["value"] as? String
        else { return nil }
        return value
    }

    /// Issue #1022 S1: every string EnergySuggestionPrompt shows on screen
    /// or reads via VoiceOver has a translated es and pt value.
    @Test(arguments: [
        "Show all",
        "Show all levels",
        " · showing only this level",
        "Filter by %@",
        " · suggested now",
        "Dismiss energy suggestion",
    ])
    func energySuggestionKeysAreTranslated(key: String) {
        #expect(Self.value(of: key, locale: "es") != nil, "missing es for \(key.debugDescription)")
        #expect(Self.value(of: key, locale: "pt") != nil, "missing pt for \(key.debugDescription)")
    }

    /// Issue #1022 S4: the admin level is a role of work, not a person —
    /// aligned with web ('plan.energy.admin' = "Admin" in es and pt).
    @Test func adminLevelNameIsAlignedWithWeb() {
        #expect(Self.value(of: "Admin", locale: "es") == "Admin")
        #expect(Self.value(of: "Admin", locale: "pt") == "Admin")
    }
}

// MARK: - Issue #1022 S3 — one «Today without filters» for both platforms

@Suite("Today unfiltered candidate set")
struct TodayUnfilteredCandidateSetTests {

    private func state(
        id: UUID,
        title: String,
        plannedDate: Date? = nil,
        dueDate: Date? = nil
    ) -> TaskListFeature.TaskItemState {
        TaskListFeature.TaskItemState(
            id: id,
            title: title,
            notes: nil,
            isCompleted: false,
            priority: .none,
            energyLevel: .deep,
            estimatedPomodoros: 1,
            completedPomodoros: 0,
            subtaskProgress: .init(completed: 0, total: 0),
            recurrenceRule: nil,
            isRecurringTemplate: false,
            dueDate: dueDate,
            scheduledForToday: false,
            plannedDate: plannedDate,
            sortOrder: 0,
            createdAt: .now
        )
    }

    @Test func todayUnfilteredHoldsTheUnifiedTodayRule() {
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: .now)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: todayStart)!
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: todayStart)!

        let tasks = IdentifiedArray(uniqueElements: [
            state(id: UUID(), title: "planned today", plannedDate: todayStart),
            state(id: UUID(), title: "due today", dueDate: todayStart),
            state(id: UUID(), title: "postponed stays in today", plannedDate: yesterday),
            state(id: UUID(), title: "overdue stays in today", dueDate: yesterday),
            state(id: UUID(), title: "planned tomorrow", plannedDate: tomorrow),
            state(id: UUID(), title: "inbox has no dates"),
        ])

        let today = TaskListFeature.todayUnfilteredTasks(tasks)
        #expect(
            Set(today.map(\.title))
                == ["planned today", "due today", "postponed stays in today", "overdue stays in today"]
        )
    }
}
