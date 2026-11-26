// TaskPlanningTests.swift
// Pepinillo — Deep Work Companion for Apple
//
// The unified «Hoy» rule (issue #991 S2/S3/S6) asserted against the shared
// case table contracts/fixtures/task-planning-cases-991.json — the same file
// the Android and web suites decode — plus the V6→V7 on-disk migration with
// its boolean → planned-date backfill (S1).

import Testing
import SwiftData
import Foundation
@testable import Pepinillo

@Suite("TaskPlanning", .serialized)
struct TaskPlanningTests {

    // MARK: - Shared case table (S3)

    private struct PlanningFixture: Decodable {
        let cases: [PlanningCase]
    }

    private struct PlanningCase: Decodable {
        let name: String
        let planned: Int?
        let due: Int?
        let status: String
        let legacyScheduledForToday: Bool?
        let recurringInstance: Bool?

        struct Expected: Decodable {
            let today: Bool
            let postponed: Bool
            let upcoming: Bool
            let inbox: Bool
        }

        let expected: Expected
    }

    /// contracts/fixtures/task-planning-cases-991.json, resolved from the
    /// source file location so the same repo file feeds every platform's suite.
    private static func loadFixture() throws -> PlanningFixture {
        let fixtureURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // Tests/IntegrationTests
            .deletingLastPathComponent() // Tests
            .deletingLastPathComponent() // ios
            .deletingLastPathComponent() // repo root
            .appendingPathComponent("contracts/fixtures/task-planning-cases-991.json")
        return try JSONDecoder().decode(PlanningFixture.self, from: Data(contentsOf: fixtureURL))
    }

    /// Fixed local calendar + reference day so every case is deterministic.
    private static func testCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private static let referenceNow: Date = {
        var calendar = testCalendar()
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar.date(from: DateComponents(year: 2026, month: 11, day: 27, hour: 15))!
    }()

    private static func day(_ offset: Int?, calendar: Calendar) -> Date? {
        guard let offset else { return nil }
        return calendar.date(byAdding: .day, value: offset, to: referenceNow)
            .map { TaskPlanning.plannedDay($0, calendar: calendar) }
    }

    @Test("unified rule matches the shared case table (#991 S3)")
    func unifiedRuleMatchesSharedCaseTable() throws {
        let fixture = try Self.loadFixture()
        #expect(fixture.cases.count >= 16, "the shared table keeps growing with regressions")
        let calendar = Self.testCalendar()

        for item in fixture.cases {
            let bucket = TaskPlanning.bucket(
                plannedDate: Self.day(item.planned, calendar: calendar),
                dueDate: Self.day(item.due, calendar: calendar),
                scheduledForToday: item.legacyScheduledForToday ?? false,
                isCompleted: item.status == "completed",
                now: Self.referenceNow,
                calendar: calendar
            )
            let label = item.name
            switch bucket {
            case .today(let postponed):
                #expect(item.expected.today, "today — \(label)")
                #expect(postponed == item.expected.postponed, "postponed — \(label)")
                #expect(!item.expected.upcoming, "not upcoming — \(label)")
                #expect(!item.expected.inbox, "not inbox — \(label)")
            case .upcoming:
                #expect(item.expected.upcoming, "upcoming — \(label)")
                #expect(!item.expected.today, "not today — \(label)")
                #expect(!item.expected.inbox, "not inbox — \(label)")
            case .inbox:
                #expect(item.expected.inbox, "inbox — \(label)")
                #expect(!item.expected.today, "not today — \(label)")
                #expect(!item.expected.upcoming, "not upcoming — \(label)")
            case .completed:
                #expect(item.status == "completed", "completed only for completed — \(label)")
                #expect(!item.expected.today && !item.expected.upcoming && !item.expected.inbox, "no active bucket — \(label)")
            }
        }
    }

    // MARK: - S6: past plans never roll back to inbox

    @Test("a past plan is today while the day has not passed and postponed afterwards (S6)")
    func pastPlanSurvivesMidnight() {
        let calendar = Self.testCalendar()
        let yesterday = Self.day(-1, calendar: calendar)!

        let sameDay = TaskPlanning.bucket(
            plannedDate: yesterday, dueDate: nil, isCompleted: false,
            now: Self.referenceNow, calendar: calendar
        )
        #expect(sameDay == .today(postponed: true))

        let nextDay = calendar.date(byAdding: .day, value: 1, to: Self.referenceNow)!
        let afterMidnight = TaskPlanning.bucket(
            plannedDate: yesterday, dueDate: nil, isCompleted: false,
            now: nextDay, calendar: calendar
        )
        #expect(afterMidnight == .today(postponed: true), "the plan stays visible as postponed (S6)")
    }

    @Test("plannedDay normalizes any time to the start of the local day (S1)")
    func plannedDayNormalizesToStartOfDay() {
        let calendar = Self.testCalendar()
        let noon = calendar.date(from: DateComponents(year: 2026, month: 11, day: 27, hour: 12, minute: 34))!
        let planned = TaskPlanning.plannedDay(noon, calendar: calendar)
        #expect(calendar.isDate(planned, inSameDayAs: noon))
        #expect(planned == calendar.startOfDay(for: noon))
    }

    // MARK: - S1: V6 → V7 migration with boolean backfill

    @MainActor
    @Test("V6 store migrates to V7: legacy boolean backfills to today, unflagged rows stay nil")
    func v6StoreMigratesToV7WithBackfill() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("pepinillo-planning-991-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let storeURL = dir.appendingPathComponent("test.sqlite")

        // 1. Create a V6 store: one flagged row (in today's list), one plain.
        do {
            let schema = Schema(versionedSchema: SchemaV6.self)
            let config = ModelConfiguration(schema: schema, url: storeURL, cloudKitDatabase: .none)
            let container = try ModelContainer(for: schema, configurations: [config])
            let ctx = container.mainContext

            let pinned = SchemaV6.TaskItem(title: "Pinned for today")
            pinned.scheduledForToday = true
            ctx.insert(pinned)

            let plain = SchemaV6.TaskItem(title: "Inbox task")
            ctx.insert(plain)

            try ctx.save()
        }

        // 2. Re-open with the full migration plan targeting V7.
        let currentSchema = Schema(versionedSchema: SchemaV7.self)
        let currentConfig = ModelConfiguration(schema: currentSchema, url: storeURL, cloudKitDatabase: .none)
        let migrated = try ModelContainer(
            for: currentSchema,
            migrationPlan: PepinilloMigrationPlan.self,
            configurations: [currentConfig]
        )
        let ctx = migrated.mainContext

        let tasks = try ctx.fetch(FetchDescriptor<TaskItem>())
        #expect(tasks.count == 2)

        let pinned = try #require(tasks.first { $0.title == "Pinned for today" })
        let plain = try #require(tasks.first { $0.title == "Inbox task" })

        // 3. S1: the boolean became plannedDate = today; the rest stays empty.
        let calendar = Calendar.current
        #expect(pinned.plannedDate != nil, "flagged row backfilled")
        #expect(calendar.isDateInToday(pinned.plannedDate!), "backfill stamps today")
        #expect(plain.plannedDate == nil, "unflagged rows keep no planned date")
        #expect(pinned.scheduledForToday == true, "the boolean stays for installs compat")
    }

    @MainActor
    @Test("V5 store migrates to V7: the frozen V5 snapshot opens the real V5 shape and backfills")
    func v5StoreMigratesToV7WithBackfill() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("pepinillo-planning-991-v5-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let storeURL = dir.appendingPathComponent("test.sqlite")

        // 1. Seed a genuine V5 store (frozen snapshot: no AchievementRecord, no plannedDate).
        do {
            let schema = Schema(versionedSchema: SchemaV5.self)
            let config = ModelConfiguration(schema: schema, url: storeURL, cloudKitDatabase: .none)
            let container = try ModelContainer(for: schema, configurations: [config])
            let ctx = container.mainContext

            let pinned = SchemaV5.TaskItem(title: "V5 pinned")
            pinned.scheduledForToday = true
            ctx.insert(pinned)
            try ctx.save()
        }

        // 2. Re-open through the full plan — this path previously aborted with
        //    "unknown model version" while SchemaV5 declared live classes.
        let currentSchema = Schema(versionedSchema: SchemaV7.self)
        let currentConfig = ModelConfiguration(schema: currentSchema, url: storeURL, cloudKitDatabase: .none)
        let migrated = try ModelContainer(
            for: currentSchema,
            migrationPlan: PepinilloMigrationPlan.self,
            configurations: [currentConfig]
        )
        let ctx = migrated.mainContext

        let tasks = try ctx.fetch(FetchDescriptor<TaskItem>())
        let pinned = try #require(tasks.first { $0.title == "V5 pinned" })
        #expect(pinned.plannedDate != nil, "V5 flag backfilled to today")
        #expect(Calendar.current.isDateInToday(pinned.plannedDate!))
    }

    @MainActor
    @Test("backfill is idempotent and never overwrites an existing planned date")
    func backfillIsIdempotent() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("pepinillo-planning-991-idem-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let storeURL = dir.appendingPathComponent("test.sqlite")

        let schema = Schema(versionedSchema: SchemaV7.self)
        let config = ModelConfiguration(schema: schema, url: storeURL, cloudKitDatabase: .none)
        let container = try ModelContainer(for: schema, configurations: [config])
        let ctx = container.mainContext

        let calendar = Self.testCalendar()
        let friday = Self.day(3, calendar: calendar)!

        let legacy = TaskItem(title: "Legacy flag")
        legacy.scheduledForToday = true
        ctx.insert(legacy)

        let futurePlanned = TaskItem(title: "Planned Friday")
        futurePlanned.scheduledForToday = true  // mixed state from sync shims
        futurePlanned.plannedDate = friday
        ctx.insert(futurePlanned)

        try ctx.save()
        try TaskPlanningBackfill.backfillPlannedDates(in: ctx, now: Self.referenceNow, calendar: calendar)
        try TaskPlanningBackfill.backfillPlannedDates(in: ctx, now: Self.referenceNow, calendar: calendar)

        let legacyAfter = try #require(try ctx.fetch(FetchDescriptor<TaskItem>()).first { $0.title == "Legacy flag" })
        #expect(calendar.isDate(legacyAfter.plannedDate!, inSameDayAs: Self.referenceNow), "backfilled exactly once")

        let futureAfter = try #require(try ctx.fetch(FetchDescriptor<TaskItem>()).first { $0.title == "Planned Friday" })
        #expect(futureAfter.plannedDate == friday, "existing plan is never overwritten")
    }

    // MARK: - S8: recurrence born planned

    @Test("plannedDay matches the recurrence birth semantics (S8)")
    func recurrenceBirthPlannedDay() {
        let calendar = Self.testCalendar()
        let occurrence = calendar.date(byAdding: .day, value: 2, to: Self.referenceNow)!
        let born = TaskPlanning.plannedDay(occurrence, calendar: calendar)
        let bucket = TaskPlanning.bucket(
            plannedDate: born, dueDate: nil, isCompleted: false,
            now: occurrence.addingTimeInterval(3600), calendar: calendar
        )
        #expect(bucket == .today(postponed: false), "an instance is in «Hoy» on its occurrence day")
    }
}
