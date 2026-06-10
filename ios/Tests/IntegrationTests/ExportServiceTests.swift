// ExportServiceTests.swift
// Pepinillo — Deep Work Companion for Apple
//
// Unit tests for ExportService CSV generation.
// All tests run against pure functions that take DTOs and return strings —
// no SwiftData, no network, no MainActor required.

import Testing
import Foundation
@testable import Pepinillo

@Suite("ExportService")
struct ExportServiceTests {

    // MARK: - CSV Escaping

    @Test("Plain value is returned as-is")
    func plainValueNoEscape() {
        #expect(ExportService.csvEscape("hello") == "hello")
    }

    @Test("Value containing comma is quoted")
    func commaTriggersQuoting() {
        #expect(ExportService.csvEscape("a,b") == "\"a,b\"")
    }

    @Test("Value containing double-quote is quoted and escaped")
    func quoteTriggersDoubleEscape() {
        #expect(ExportService.csvEscape("say \"hi\"") == "\"say \"\"hi\"\"\"")
    }

    @Test("Value containing newline is quoted")
    func newlineTriggersQuoting() {
        let value = "line1\nline2"
        let result = ExportService.csvEscape(value)
        #expect(result == "\"line1\nline2\"")
    }

    @Test("Value containing carriage return is quoted")
    func carriageReturnTriggersQuoting() {
        let value = "line1\rline2"
        let result = ExportService.csvEscape(value)
        #expect(result == "\"line1\rline2\"")
    }

    @Test("Empty string is returned as-is (no unnecessary quoting)")
    func emptyStringNoQuote() {
        #expect(ExportService.csvEscape("") == "")
    }

    // MARK: - CSV Row

    @Test("Row joins cells with commas")
    func csvRowJoins() {
        let row = ExportService.csvRow(["one", "two", "three"])
        #expect(row == "one,two,three")
    }

    @Test("Row with mixed plain and special values")
    func csvRowMixed() {
        let row = ExportService.csvRow(["title", "notes, extra", "100"])
        #expect(row == "title,\"notes, extra\",100")
    }

    // MARK: - Tasks CSV Header

    @Test("Tasks CSV starts with correct header")
    func tasksCsvHeader() {
        let csv = ExportService.buildTasksCSV(tasks: [])
        let firstLine = csv.components(separatedBy: "\n").first ?? ""
        #expect(firstLine.hasPrefix("title,notes,status,priority,energy"))
    }

    @Test("Tasks CSV with no tasks produces only the header row")
    func tasksCsvEmptyProducesHeaderOnly() {
        let csv = ExportService.buildTasksCSV(tasks: [])
        let lines = csv.components(separatedBy: "\n").filter { !$0.isEmpty }
        #expect(lines.count == 1)
    }

    // MARK: - Tasks CSV Rows

    @Test("Completed task row contains 'completed' status")
    func completedTaskStatusColumn() {
        let dto = makeTaskDTO(title: "Deep work", isCompleted: true)
        let csv = ExportService.buildTasksCSV(tasks: [dto])
        let dataLine = csv.components(separatedBy: "\n").dropFirst().first ?? ""
        #expect(dataLine.contains("completed"))
    }

    @Test("Pending task row contains 'pending' status")
    func pendingTaskStatusColumn() {
        let dto = makeTaskDTO(title: "Research", isCompleted: false)
        let csv = ExportService.buildTasksCSV(tasks: [dto])
        let dataLine = csv.components(separatedBy: "\n").dropFirst().first ?? ""
        #expect(dataLine.contains("pending"))
    }

    @Test("Task title with comma is properly escaped in CSV")
    func taskTitleCommaEscaping() {
        let dto = makeTaskDTO(title: "Plan, execute, review")
        let csv = ExportService.buildTasksCSV(tasks: [dto])
        let dataLine = csv.components(separatedBy: "\n").dropFirst().first ?? ""
        #expect(dataLine.hasPrefix("\"Plan, execute, review\""))
    }

    @Test("Task title with double-quote is properly escaped in CSV")
    func taskTitleQuoteEscaping() {
        let dto = makeTaskDTO(title: "Read \"Atomic Habits\"")
        let csv = ExportService.buildTasksCSV(tasks: [dto])
        let dataLine = csv.components(separatedBy: "\n").dropFirst().first ?? ""
        #expect(dataLine.hasPrefix("\"Read \"\"Atomic Habits\"\"\""))
    }

    @Test("Task notes with newline are properly escaped")
    func taskNotesNewlineEscaping() {
        let dto = makeTaskDTO(title: "Task", notes: "Line 1\nLine 2")
        let csv = ExportService.buildTasksCSV(tasks: [dto])
        // The embedded newline in the notes field must be RFC 4180 quoted.
        // We check the full CSV string rather than splitting on \n, because
        // the quoted cell itself contains a \n which would break naïve splitting.
        #expect(csv.contains("\"Line 1\nLine 2\""))
    }

    @Test("Multiple tasks produce matching row count")
    func multipleTasksRowCount() {
        let dtos = (0..<5).map { i in makeTaskDTO(title: "Task \(i)") }
        let csv = ExportService.buildTasksCSV(tasks: dtos)
        let lines = csv.components(separatedBy: "\n").filter { !$0.isEmpty }
        // 1 header + 5 data rows
        #expect(lines.count == 6)
    }

    @Test("Pomodoro counts are in the correct columns")
    func pomodoroCounts() {
        let dto = makeTaskDTO(title: "Coding", estimatedPomodoros: 4, completedPomodoros: 3)
        let csv = ExportService.buildTasksCSV(tasks: [dto])
        #expect(csv.contains(",4,") || csv.contains(",4\n") || csv.contains(",4\r"))
        #expect(csv.contains(",3,") || csv.contains(",3\n") || csv.contains(",3\r"))
    }

    // MARK: - Sessions CSV Header

    @Test("Sessions CSV starts with correct header")
    func sessionsCsvHeader() {
        let csv = ExportService.buildSessionsCSV(sessions: [])
        let firstLine = csv.components(separatedBy: "\n").first ?? ""
        #expect(firstLine.hasPrefix("date,mode,phase"))
    }

    @Test("Sessions CSV with no sessions produces only header")
    func sessionsCsvEmptyProducesHeaderOnly() {
        let csv = ExportService.buildSessionsCSV(sessions: [])
        let lines = csv.components(separatedBy: "\n").filter { !$0.isEmpty }
        #expect(lines.count == 1)
    }

    // MARK: - Sessions CSV Rows

    @Test("Completed session row contains 'yes'")
    func completedSessionColumn() {
        let dto = makeSessionDTO(mode: "pomodoro", wasCompleted: true, actualDuration: 1500)
        let csv = ExportService.buildSessionsCSV(sessions: [dto])
        let dataLine = csv.components(separatedBy: "\n").dropFirst().first ?? ""
        #expect(dataLine.contains(",yes,") || dataLine.hasSuffix(",yes"))
    }

    @Test("Incomplete session row contains 'no'")
    func incompleteSessionColumn() {
        let dto = makeSessionDTO(mode: "flowtime", wasCompleted: false, actualDuration: 600)
        let csv = ExportService.buildSessionsCSV(sessions: [dto])
        let dataLine = csv.components(separatedBy: "\n").dropFirst().first ?? ""
        #expect(dataLine.contains(",no,") || dataLine.hasSuffix(",no"))
    }

    @Test("Session duration is converted to minutes")
    func sessionDurationInMinutes() {
        // 1500 seconds = 25.0 minutes
        let dto = makeSessionDTO(mode: "pomodoro", wasCompleted: true, actualDuration: 1500)
        let csv = ExportService.buildSessionsCSV(sessions: [dto])
        #expect(csv.contains("25.0"))
    }

    @Test("Journal note with comma is escaped")
    func sessionJournalNoteEscaping() {
        let dto = makeSessionDTO(
            mode: "pomodoro",
            wasCompleted: true,
            actualDuration: 1500,
            journalNote: "Good session, very focused"
        )
        let csv = ExportService.buildSessionsCSV(sessions: [dto])
        #expect(csv.contains("\"Good session, very focused\""))
    }

    // MARK: - Temp Directory

    @Test("makeTempDirectory creates a directory")
    func tempDirectoryCreated() throws {
        let dir = try ExportService.makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        var isDir: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: dir.path, isDirectory: &isDir)
        #expect(exists && isDir.boolValue)
    }

    @Test("Two calls to makeTempDirectory return different paths")
    func tempDirectoryUnique() throws {
        let dir1 = try ExportService.makeTempDirectory()
        let dir2 = try ExportService.makeTempDirectory()
        defer {
            try? FileManager.default.removeItem(at: dir1)
            try? FileManager.default.removeItem(at: dir2)
        }
        #expect(dir1 != dir2)
    }

    // MARK: - CSV File Writing

    @Test("generateCSV writes task file when tasks are present")
    func generateCSVWritesTaskFile() throws {
        let dir = try ExportService.makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }

        let payload = ExportPayload(
            tasks: [makeTaskDTO(title: "My Task")],
            sessions: [],
            generatedAt: Date.now,
            dateRange: .last30Days
        )
        let urls = try ExportService.generateCSV(payload: payload, directory: dir)
        #expect(urls.count == 1)
        #expect(urls[0].lastPathComponent == "pepinillo_tasks.csv")
        let content = try String(contentsOf: urls[0], encoding: .utf8)
        #expect(content.contains("My Task"))
    }

    @Test("generateCSV writes session file when sessions are present")
    func generateCSVWritesSessionFile() throws {
        let dir = try ExportService.makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }

        let payload = ExportPayload(
            tasks: [],
            sessions: [makeSessionDTO(mode: "pomodoro", wasCompleted: true, actualDuration: 1500)],
            generatedAt: Date.now,
            dateRange: .last30Days
        )
        let urls = try ExportService.generateCSV(payload: payload, directory: dir)
        #expect(urls.count == 1)
        #expect(urls[0].lastPathComponent == "pepinillo_sessions.csv")
    }

    @Test("generateCSV writes both files when both data types present")
    func generateCSVWritesBothFiles() throws {
        let dir = try ExportService.makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }

        let payload = ExportPayload(
            tasks: [makeTaskDTO(title: "Task A")],
            sessions: [makeSessionDTO(mode: "pomodoro", wasCompleted: true, actualDuration: 1500)],
            generatedAt: Date.now,
            dateRange: .last30Days
        )
        let urls = try ExportService.generateCSV(payload: payload, directory: dir)
        #expect(urls.count == 2)
        let names = Set(urls.map(\.lastPathComponent))
        #expect(names.contains("pepinillo_tasks.csv"))
        #expect(names.contains("pepinillo_sessions.csv"))
    }

    @Test("generateCSV returns empty array when both lists are empty")
    func generateCSVEmptyPayload() throws {
        let dir = try ExportService.makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }

        let payload = ExportPayload(tasks: [], sessions: [], generatedAt: Date.now, dateRange: .allTime)
        let urls = try ExportService.generateCSV(payload: payload, directory: dir)
        #expect(urls.isEmpty)
    }

    // MARK: - Date Range

    @Test("last7Days interval spans roughly 7 days")
    func last7DaysInterval() {
        let (start, end) = ExportDateRange.last7Days.dateInterval()
        let diff = end.timeIntervalSince(start)
        // Should be 7 days ± a few seconds
        #expect(diff >= 7 * 24 * 3600 - 10)
        #expect(diff <= 7 * 24 * 3600 + 10)
    }

    @Test("allTime interval starts at Unix epoch")
    func allTimeStartsAtEpoch() {
        let (start, _) = ExportDateRange.allTime.dateInterval()
        #expect(start == Date(timeIntervalSince1970: 0))
    }

    // MARK: - Helpers

    private func makeTaskDTO(
        title: String,
        notes: String? = nil,
        isCompleted: Bool = false,
        estimatedPomodoros: Int = 1,
        completedPomodoros: Int = 0
    ) -> TaskItemDTO {
        TaskItemDTO(
            id: UUID(),
            title: title,
            notes: notes,
            isCompleted: isCompleted,
            priority: .none,
            energyLevel: .deep,
            estimatedPomodoros: estimatedPomodoros,
            completedPomodoros: completedPomodoros,
            sortOrder: 0,
            subtasksCompleted: 0,
            subtasksTotal: 0,
            recurrenceRule: nil,
            isRecurringTemplate: false,
            dueDate: nil,
            scheduledForToday: false,
            completedAt: nil,
            createdAt: Date.now
        )
    }

    private func makeSessionDTO(
        mode: String,
        wasCompleted: Bool,
        actualDuration: TimeInterval,
        journalNote: String? = nil
    ) -> SessionRecordDTO {
        SessionRecordDTO(
            id: UUID(),
            startedAt: Date.now,
            endedAt: Date.now.addingTimeInterval(actualDuration),
            mode: mode,
            phase: "work",
            targetDuration: nil,
            actualDuration: actualDuration,
            wasCompleted: wasCompleted,
            interruptions: 0,
            pauseCount: 0,
            totalPauseDuration: 0,
            pomodoroNumber: nil,
            taskID: nil,
            taskServerId: nil,
            journalNote: journalNote,
            satisfactionRating: nil
        )
    }
}
