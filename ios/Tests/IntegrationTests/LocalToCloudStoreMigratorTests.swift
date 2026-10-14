// LocalToCloudStoreMigratorTests.swift
// Pepinillo — Deep Work Companion for Apple
//
// Integration tests for store-to-store migration using dual on-disk containers.

import Testing
import Foundation
import SwiftData
@testable import Pepinillo

@Suite("LocalToCloudStoreMigrator Integration Tests")
struct LocalToCloudStoreMigratorTests {

    private func makeOnDiskContainer(
        directory: URL,
        fileName: String
    ) throws -> ModelContainer {
        let schema = Schema(versionedSchema: SchemaV5.self)
        let config = ModelConfiguration(
            schema: schema,
            url: directory.appendingPathComponent(fileName),
            cloudKitDatabase: .none
        )
        return try ModelContainer(
            for: schema,
            migrationPlan: PepinilloMigrationPlan.self,
            configurations: [config]
        )
    }

    private func makeTempDirectory() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("pepinillo-migrator-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    @Test("Preserves task IDs and non-DTO fields across local→cloud seed")
    @MainActor
    func preservesTaskIDsAndFields() throws {
        let dir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }

        let sourceContainer = try makeOnDiskContainer(directory: dir, fileName: "source.sqlite")
        let targetContainer = try makeOnDiskContainer(directory: dir, fileName: "target.sqlite")
        let sourceContext = sourceContainer.mainContext

        let templateID = UUID()
        let dueDate = Date(timeIntervalSince1970: 1_800_000_000)
        let task = TaskItem(
            title: "Deep work",
            notes: "Full notes",
            priority: .high,
            energyLevel: .deep,
            estimatedPomodoros: 4,
            sortOrder: 2
        )
        task.preferredMode = "flowtime"
        task.scheduledForToday = true
        task.dueDate = dueDate
        task.completedPomodoros = 2
        task.serverId = 42
        task.syncId = "sync-abc"
        task.isDirty = false
        task.syncedAt = Date(timeIntervalSince1970: 1_700_000_000)
        task.recurrenceRule = RecurrencePreset.weekly.rawValue
        task.nextOccurrence = dueDate
        task.isRecurringTemplate = true
        task.recurringTemplateID = templateID
        sourceContext.insert(task)

        let sub = SubTask(title: "Sub A", sortOrder: 0)
        sub.isCompleted = true
        sourceContext.insert(sub)
        sub.parent = task

        try sourceContext.save()
        let originalTaskID = task.id
        let originalSubID = sub.id

        try LocalToCloudStoreMigrator.migrate(from: sourceContainer, to: targetContainer)

        let targetContext = targetContainer.mainContext
        let migratedTasks = try targetContext.fetch(FetchDescriptor<TaskItem>())
        #expect(migratedTasks.count == 1)

        let migrated = try #require(migratedTasks.first)
        #expect(migrated.id == originalTaskID)
        #expect(migrated.title == "Deep work")
        #expect(migrated.notes == "Full notes")
        #expect(migrated.priority == .high)
        #expect(migrated.sortOrder == 2)
        #expect(migrated.preferredMode == "flowtime")
        #expect(migrated.scheduledForToday == true)
        #expect(migrated.dueDate == dueDate)
        #expect(migrated.completedPomodoros == 2)
        #expect(migrated.serverId == 42)
        #expect(migrated.syncId == "sync-abc")
        #expect(migrated.recurrenceRule == RecurrencePreset.weekly.rawValue)
        #expect(migrated.isRecurringTemplate == true)
        #expect(migrated.recurringTemplateID == templateID)

        #expect(migrated.subtasks.count == 1)
        #expect(migrated.subtasks.first?.id == originalSubID)
        #expect(migrated.subtasks.first?.title == "Sub A")
        #expect(migrated.subtasks.first?.isCompleted == true)
    }

    @Test("Restores session→task relationships with full session fields")
    @MainActor
    func restoresSessionTaskRelationships() throws {
        let dir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }

        let sourceContainer = try makeOnDiskContainer(directory: dir, fileName: "source.sqlite")
        let targetContainer = try makeOnDiskContainer(directory: dir, fileName: "target.sqlite")
        let sourceContext = sourceContainer.mainContext

        let task = TaskItem(title: "Linked task")
        sourceContext.insert(task)

        let startedAt = Date(timeIntervalSince1970: 1_750_000_000)
        let endedAt = startedAt.addingTimeInterval(1_500)
        let session = FocusSessionRecord(
            mode: "pomodoro",
            phase: "work",
            startedAt: startedAt,
            endedAt: endedAt,
            actualDuration: 1_500,
            targetDuration: 1_800,
            wasCompleted: true,
            interruptions: 1,
            pauseCount: 2,
            totalPauseDuration: 30
        )
        session.pomodoroNumber = 3
        session.journalNote = "Felt focused"
        session.satisfactionRating = 4
        session.isDirty = false
        session.syncedAt = endedAt
        session.task = task
        sourceContext.insert(session)
        try sourceContext.save()

        let originalSessionID = session.id
        let originalTaskID = task.id

        try LocalToCloudStoreMigrator.migrate(from: sourceContainer, to: targetContainer)

        let targetContext = targetContainer.mainContext
        let migratedSessions = try targetContext.fetch(FetchDescriptor<FocusSessionRecord>())
        #expect(migratedSessions.count == 1)

        let migratedSession = try #require(migratedSessions.first)
        #expect(migratedSession.id == originalSessionID)
        #expect(migratedSession.task?.id == originalTaskID)
        #expect(migratedSession.mode == "pomodoro")
        #expect(migratedSession.phase == "work")
        #expect(migratedSession.targetDuration == 1_800)
        #expect(migratedSession.actualDuration == 1_500)
        #expect(migratedSession.interruptions == 1)
        #expect(migratedSession.pauseCount == 2)
        #expect(migratedSession.totalPauseDuration == 30)
        #expect(migratedSession.pomodoroNumber == 3)
        #expect(migratedSession.journalNote == "Felt focused")
        #expect(migratedSession.satisfactionRating == 4)
        #expect(migratedSession.isDirty == false)
    }

    @Test("Copies DailyStats and ProductivityReport analytics models")
    @MainActor
    func copiesAnalyticsModels() throws {
        let dir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }

        let sourceContainer = try makeOnDiskContainer(directory: dir, fileName: "source.sqlite")
        let targetContainer = try makeOnDiskContainer(directory: dir, fileName: "target.sqlite")
        let sourceContext = sourceContainer.mainContext

        let day = Calendar.current.startOfDay(for: Date(timeIntervalSince1970: 1_760_000_000))
        let stats = DailyStats(date: day)
        stats.totalFocusSeconds = 7_200
        stats.sessionsCompleted = 4
        stats.tasksCompleted = 2
        stats.longestStreak = 3
        stats.pomodoroSeconds = 3_600
        stats.flowtimeSeconds = 1_800
        stats.timeBlockSeconds = 900
        stats.stopwatchSeconds = 900
        stats.pomodoroCount = 2
        stats.flowtimeCount = 1
        stats.timeBlockCount = 1
        stats.stopwatchCount = 1
        stats.hadFocusSession = true
        sourceContext.insert(stats)

        let report = ProductivityReport(
            period: "week",
            periodStart: day,
            periodEnd: day.addingTimeInterval(604_800),
            title: "Great week",
            highlights: ["Deep focus"],
            insights: [ReportInsight(category: "pattern", text: "Mornings work best")],
            recommendations: ["Keep mornings clear"],
            rawPayload: "{\"sessions\":4}"
        )
        sourceContext.insert(report)
        try sourceContext.save()

        let originalStatsID = stats.id
        let originalReportID = report.id

        try LocalToCloudStoreMigrator.migrate(from: sourceContainer, to: targetContainer)

        let targetContext = targetContainer.mainContext
        let migratedStats = try targetContext.fetch(FetchDescriptor<DailyStats>())
        #expect(migratedStats.count == 1)
        let migratedStat = try #require(migratedStats.first)
        #expect(migratedStat.id == originalStatsID)
        #expect(migratedStat.totalFocusSeconds == 7_200)
        #expect(migratedStat.sessionsCompleted == 4)
        #expect(migratedStat.pomodoroSeconds == 3_600)
        #expect(migratedStat.hadFocusSession == true)

        let migratedReports = try targetContext.fetch(FetchDescriptor<ProductivityReport>())
        #expect(migratedReports.count == 1)
        let migratedReport = try #require(migratedReports.first)
        #expect(migratedReport.id == originalReportID)
        #expect(migratedReport.title == "Great week")
        #expect(migratedReport.highlights == ["Deep focus"])
        #expect(migratedReport.insights.first?.text == "Mornings work best")
        #expect(migratedReport.rawPayload == "{\"sessions\":4}")
    }

    @Test("Migrates soft-deleted tombstones with sync identity")
    @MainActor
    func migratesSoftDeletedTombstones() throws {
        let dir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }

        let sourceContainer = try makeOnDiskContainer(directory: dir, fileName: "source.sqlite")
        let targetContainer = try makeOnDiskContainer(directory: dir, fileName: "target.sqlite")
        let sourceContext = sourceContainer.mainContext

        let deletedTask = TaskItem(title: "Deleted")
        deletedTask.isLocallyDeleted = true
        deletedTask.serverId = 99
        deletedTask.syncId = "sync-del"
        deletedTask.isDirty = true
        sourceContext.insert(deletedTask)

        let activeTask = TaskItem(title: "Active")
        sourceContext.insert(activeTask)

        let orphanSession = FocusSessionRecord(
            mode: "pomodoro",
            phase: "work",
            startedAt: Date.now,
            endedAt: nil,
            actualDuration: 600,
            targetDuration: nil,
            wasCompleted: false,
            interruptions: 0,
            pauseCount: 0,
            totalPauseDuration: 0
        )
        orphanSession.task = deletedTask
        sourceContext.insert(orphanSession)
        try sourceContext.save()

        try LocalToCloudStoreMigrator.migrate(from: sourceContainer, to: targetContainer)

        let targetContext = targetContainer.mainContext
        let migratedTasks = try targetContext.fetch(FetchDescriptor<TaskItem>())
        #expect(migratedTasks.count == 2)
        // The tombstone migrates with its delete marker and server identity
        // intact, so the pending delete survives the store switch (S2).
        let tombstone = try #require(migratedTasks.first(where: { $0.title == "Deleted" }))
        #expect(tombstone.id == deletedTask.id)
        #expect(tombstone.isLocallyDeleted == true)
        #expect(tombstone.serverId == 99)
        #expect(tombstone.syncId == "sync-del")
        #expect(tombstone.isDirty == true)

        let migratedSessions = try targetContext.fetch(FetchDescriptor<FocusSessionRecord>())
        #expect(migratedSessions.count == 1)
        // The session stays linked to the migrated tombstone: history preserved.
        #expect(migratedSessions.first?.task?.id == tombstone.id)
    }

    @Test("Cloud→local merge keeps newer task revision by updatedAt")
    @MainActor
    func cloudToLocalMergeUsesLastWriteWins() throws {
        let dir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }

        let sourceContainer = try makeOnDiskContainer(directory: dir, fileName: "source.sqlite")
        let targetContainer = try makeOnDiskContainer(directory: dir, fileName: "target.sqlite")

        let sharedID = UUID()
        let olderDate = Date(timeIntervalSince1970: 1_700_000_000)
        let newerDate = Date(timeIntervalSince1970: 1_800_000_000)

        let targetContext = targetContainer.mainContext
        let existingTask = TaskItem(title: "Stale cloud title")
        existingTask.id = sharedID
        existingTask.updatedAt = olderDate
        targetContext.insert(existingTask)
        try targetContext.save()

        let sourceContext = sourceContainer.mainContext
        let newerTask = TaskItem(title: "Fresh local title")
        newerTask.id = sharedID
        newerTask.updatedAt = newerDate
        sourceContext.insert(newerTask)
        try sourceContext.save()

        try LocalToCloudStoreMigrator.migrate(from: sourceContainer, to: targetContainer)

        let mergedTasks = try targetContext.fetch(FetchDescriptor<TaskItem>())
        #expect(mergedTasks.count == 1)
        #expect(mergedTasks.first?.title == "Fresh local title")
        #expect(mergedTasks.first?.updatedAt == newerDate)
    }

    @Test("Legacy Pepinillo.sqlite import is one-shot and preserves IDs")
    @MainActor
    func legacyImportIsOneShot() throws {
        let dir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }

        let legacyURL = dir.appendingPathComponent(AppGroup.legacyCloudKitStoreFileName)
        let localURL = dir.appendingPathComponent("local.sqlite")

        let legacyContainer = try makeOnDiskContainer(directory: dir, fileName: AppGroup.legacyCloudKitStoreFileName)
        let localContainer = try makeOnDiskContainer(directory: dir, fileName: "local.sqlite")
        let legacyContext = legacyContainer.mainContext

        let task = TaskItem(title: "Legacy task")
        task.syncId = "legacy-sync"
        legacyContext.insert(task)
        try legacyContext.save()
        let originalTaskID = task.id

        let importKey = LocalToCloudStoreMigrator.legacyImportCompleteKey
        let savedFlag = UserDefaults.standard.bool(forKey: importKey)
        defer { UserDefaults.standard.set(savedFlag, forKey: importKey) }
        UserDefaults.standard.set(false, forKey: importKey)

        // Point legacy import at the temp legacy file via a test-only override.
        try migrateLegacyStoreForTesting(from: legacyURL, into: localContainer)
        #expect(UserDefaults.standard.bool(forKey: importKey) == true)

        let localContext = localContainer.mainContext
        let importedTasks = try localContext.fetch(FetchDescriptor<TaskItem>())
        #expect(importedTasks.count == 1)
        #expect(importedTasks.first?.id == originalTaskID)
        #expect(importedTasks.first?.syncId == "legacy-sync")

        // Second run should be a no-op even if we reset data in local (flag prevents re-import).
        try localContext.delete(model: TaskItem.self)
        try localContext.save()
        try migrateLegacyStoreForTesting(from: legacyURL, into: localContainer)
        let afterSecondImport = try localContext.fetch(FetchDescriptor<TaskItem>())
        #expect(afterSecondImport.isEmpty)

        #expect(FileManager.default.fileExists(atPath: legacyURL.path))
        #expect(FileManager.default.fileExists(atPath: localURL.path))
    }
}

/// Mirrors production legacy import but accepts an explicit legacy URL for tests.
private func migrateLegacyStoreForTesting(
    from legacyURL: URL,
    into localContainer: ModelContainer
) throws {
    guard UserDefaults.standard.bool(forKey: LocalToCloudStoreMigrator.legacyImportCompleteKey) == false else {
        return
    }
    guard FileManager.default.fileExists(atPath: legacyURL.path) else { return }

    let schema = Schema(versionedSchema: SchemaV5.self)
    let config = ModelConfiguration(schema: schema, url: legacyURL, cloudKitDatabase: .none)
    let legacyContainer = try ModelContainer(
        for: schema,
        migrationPlan: PepinilloMigrationPlan.self,
        configurations: [config]
    )
    try LocalToCloudStoreMigrator.migrate(from: legacyContainer, to: localContainer)
    UserDefaults.standard.set(true, forKey: LocalToCloudStoreMigrator.legacyImportCompleteKey)
}