// ExportService.swift
// Pepinillo — Deep Work Companion for Apple
//
// Pure value-type service that converts persistence DTOs into export files
// (CSV and PDF). All methods are static so they can be called from a
// background task without capturing self. Generated files are written to
// a unique temporary directory that callers own and must clean up.

import Foundation
import SwiftUI

// MARK: - Export Payload

/// Aggregated data fetched from persistence before generating files.
struct ExportPayload: Sendable {
    let tasks: [TaskItemDTO]
    let sessions: [SessionRecordDTO]
    let generatedAt: Date
    let dateRange: ExportDateRange
}

// MARK: - ExportService

enum ExportService {

    // MARK: - Temporary Directory

    /// Creates a fresh, unique temp directory for one export operation.
    /// Caller is responsible for deleting it after the share sheet dismisses.
    static func makeTempDirectory() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("pepinillo-export-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// Cleans up legacy export directories from the temporary directory.
    static func cleanLegacyExportDirectories() {
        let tempDir = FileManager.default.temporaryDirectory
        guard let urls = try? FileManager.default.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil) else {
            return
        }
        for url in urls {
            if url.lastPathComponent.hasPrefix("pepinillo-export-") {
                try? FileManager.default.removeItem(at: url)
            }
        }
    }

    // MARK: - CSV Generation

    /// Generates CSV file(s) for the given payload and returns their URLs.
    /// If both tasks and sessions are requested they are written as separate files.
    static func generateCSV(
        payload: ExportPayload,
        directory: URL
    ) throws -> [URL] {
        var urls: [URL] = []

        if !payload.tasks.isEmpty {
            let url = directory.appendingPathComponent("pepinillo_tasks.csv")
            let csv = buildTasksCSV(tasks: payload.tasks)
            try csv.write(to: url, atomically: true, encoding: .utf8)
            urls.append(url)
        }

        if !payload.sessions.isEmpty {
            let url = directory.appendingPathComponent("pepinillo_sessions.csv")
            let csv = buildSessionsCSV(sessions: payload.sessions)
            try csv.write(to: url, atomically: true, encoding: .utf8)
            urls.append(url)
        }

        return urls
    }

    // MARK: - Tasks CSV

    static func buildTasksCSV(tasks: [TaskItemDTO]) -> String {
        var lines: [String] = []

        // Header
        lines.append(csvRow([
            "title", "notes", "status", "priority", "energy",
            "due_date", "completed_at", "estimated_pomodoros", "completed_pomodoros",
            "subtasks_completed", "subtasks_total", "recurrence_rule", "created_at"
        ]))

        let df = ISO8601DateFormatter()

        for task in tasks {
            lines.append(csvRow([
                task.title,
                task.notes ?? "",
                task.isCompleted ? "completed" : "pending",
                task.priority.displayName,
                task.energyLevel.displayName,
                task.dueDate.map { df.string(from: $0) } ?? "",
                task.completedAt.map { df.string(from: $0) } ?? "",
                String(task.estimatedPomodoros),
                String(task.completedPomodoros),
                String(task.subtasksCompleted),
                String(task.subtasksTotal),
                task.recurrenceRule ?? "",
                df.string(from: task.createdAt)
            ]))
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Sessions CSV

    static func buildSessionsCSV(sessions: [SessionRecordDTO]) -> String {
        var lines: [String] = []

        // Header
        lines.append(csvRow([
            "date", "mode", "phase", "duration_minutes", "completed",
            "interruptions", "pause_count", "total_pause_minutes",
            "satisfaction_rating", "journal_note"
        ]))

        let df = ISO8601DateFormatter()

        for session in sessions {
            let durationMinutes = String(format: "%.1f", session.actualDuration / 60)
            let pauseMinutes = String(format: "%.1f", session.totalPauseDuration / 60)
            lines.append(csvRow([
                df.string(from: session.startedAt),
                session.mode,
                session.phase,
                durationMinutes,
                session.wasCompleted ? "yes" : "no",
                String(session.interruptions),
                String(session.pauseCount),
                pauseMinutes,
                session.satisfactionRating.map(String.init) ?? "",
                session.journalNote ?? ""
            ]))
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - CSV Escaping

    /// Wraps a single cell value in quotes if needed and escapes internal quotes.
    /// RFC 4180 compliant: comma, newline, or double-quote forces quoting.
    static func csvEscape(_ value: String) -> String {
        let needsQuotes = value.contains(",") || value.contains("\"")
            || value.contains("\n") || value.contains("\r")
        if needsQuotes {
            let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }
        return value
    }

    /// Joins escaped cell values with commas.
    static func csvRow(_ values: [String]) -> String {
        values.map { csvEscape($0) }.joined(separator: ",")
    }

    // MARK: - PDF Generation

    /// Generates a PDF report and returns its URL.
    @MainActor
    static func generatePDF(
        payload: ExportPayload,
        directory: URL
    ) async throws -> URL {
        let url = directory.appendingPathComponent("pepinillo_report.pdf")
        let renderer = ImageRenderer(
            content: ExportReportView(payload: payload)
                .frame(width: 612)   // US Letter width in points at 72 dpi
        )
        renderer.scale = 2.0  // Retina quality
        guard let uiImage = renderer.uiImage else {
            throw ExportError.pdfRenderFailed
        }

        // Use UIGraphicsPDFRenderer to create a proper multi-page PDF
        // Each page is a US Letter page (612 × 792 pt)
        let pageWidth: CGFloat = 612
        let pageHeight: CGFloat = 792
        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        let margin: CGFloat = 36

        let pdfRenderer = UIGraphicsPDFRenderer(bounds: pageRect)
        let data = pdfRenderer.pdfData { ctx in
            let imageSize = uiImage.size
            // How many pt tall is the rendered image (at the page's width)?
            let scaleFactor = (pageWidth - margin * 2) / imageSize.width
            let imageHeightInPDF = imageSize.height * scaleFactor
            let contentWidth = pageWidth - margin * 2
            let usableHeight = pageHeight - margin * 2

            var yOffset: CGFloat = 0
            var pageNumber = 0

            while yOffset < imageHeightInPDF {
                ctx.beginPage()

                // Clip to the visible slice of the rendered image
                let sourceY = yOffset / scaleFactor
                let sourceHeight = min(usableHeight / scaleFactor, imageSize.height - sourceY)
                let sourceSlice = CGRect(x: 0, y: sourceY, width: imageSize.width, height: sourceHeight)

                if let cgImage = uiImage.cgImage?.cropping(to: CGRect(
                    x: sourceSlice.origin.x * uiImage.scale,
                    y: sourceSlice.origin.y * uiImage.scale,
                    width: sourceSlice.width * uiImage.scale,
                    height: sourceSlice.height * uiImage.scale
                )) {
                    let sliceImage = UIImage(cgImage: cgImage, scale: uiImage.scale, orientation: uiImage.imageOrientation)
                    let destHeight = sliceImage.size.height * scaleFactor
                    sliceImage.draw(in: CGRect(x: margin, y: margin, width: contentWidth, height: destHeight))
                }

                yOffset += usableHeight
                pageNumber += 1
            }
        }

        try data.write(to: url)
        return url
    }
}

// MARK: - Export Errors

enum ExportError: LocalizedError {
    case noDataSelected
    case noDataInRange
    case pdfRenderFailed
    case writeFailed(Error)

    var errorDescription: String? {
        switch self {
        case .noDataSelected:
            return String(localized: "export.error.no_data_selected",
                          defaultValue: "Please select at least one data type to export.")
        case .noDataInRange:
            return String(localized: "export.error.no_data_in_range",
                          defaultValue: "No tasks or sessions found in the selected date range.")
        case .pdfRenderFailed:
            return String(localized: "export.error.pdf_render_failed",
                          defaultValue: "Could not render the PDF. Please try again.")
        case .writeFailed(let underlying):
            return String(localized: "export.error.write_failed",
                          defaultValue: "Failed to write export file: \(underlying.localizedDescription)")
        }
    }
}
