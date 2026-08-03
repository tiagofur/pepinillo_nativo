// ExportService.swift
// Pepinillo — Deep Work Companion for Apple
//
// Pure value-type service that converts persistence DTOs into export files
// (CSV and PDF). All methods are static so they can be called from a
// background task without capturing self. Generated files are written to
// a unique temporary directory that callers own and must clean up.

import Foundation
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

#if canImport(AppKit)
import AppKit
import PDFKit
#endif

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

    // Shared date formatter for human-readable dates in headers/footers
    static let headerDateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .short
        return df
    }()

    /// Título estándar del reporte
    static func reportTitle() -> String {
        return "Pepinillo — Reporte de Exportación"
    }

    /// Subtítulo con la fecha de generación (en español)
    static func reportSubtitle(generatedAt: Date) -> String {
        let generated = headerDateFormatter.string(from: generatedAt)
        return "Generado: \(generated)"
    }

    /// Línea de resumen para portada (tareas y sesiones)
    static func reportSummaryLine(tasksCount: Int, sessionsCount: Int) -> String {
        let tareas = tasksCount == 1 ? "1 tarea" : "\(tasksCount) tareas"
        let sesiones = sessionsCount == 1 ? "1 sesión" : "\(sessionsCount) sesiones"
        return "Resumen: \(tareas) · \(sesiones)"
    }

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
#if canImport(UIKit)
        let url = directory.appendingPathComponent("pepinillo_report.pdf")
        let contentView = ExportReportView(payload: payload)
            .frame(width: 612)
        let renderer = ImageRenderer(content: contentView)
        renderer.scale = 2.0
        guard let uiImage = renderer.uiImage else {
            throw ExportError.pdfRenderFailed
        }

        // PDF page setup
        let pageWidth: CGFloat = 612
        let pageHeight: CGFloat = 792
        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        let margin: CGFloat = 36
        let contentWidth = pageWidth - margin * 2
        let usableHeight = pageHeight - margin * 2

        // Document metadata
        let format = UIGraphicsPDFRendererFormat()
        let docInfo: [String: Any] = [
            kCGPDFContextTitle as String: reportTitle(),
            kCGPDFContextAuthor as String: "Pepinillo",
            kCGPDFContextSubject as String: "Exported report"
        ]
        format.documentInfo = docInfo

        let pdfRenderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)
        let data = pdfRenderer.pdfData { ctx in
            // Cover page
            ctx.beginPage()
            // Draw cover title and subtitle centered
            let title = reportTitle() as NSString
            let subtitle = reportSubtitle(generatedAt: payload.generatedAt) as NSString
            let titleAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 24),
                .foregroundColor: UIColor.label
            ]
            let subtitleAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 14),
                .foregroundColor: UIColor.secondaryLabel
            ]
            let titleSize = title.size(withAttributes: titleAttrs)
            let subtitleSize = subtitle.size(withAttributes: subtitleAttrs)
            let centerX = pageRect.midX
            title.draw(at: CGPoint(x: centerX - titleSize.width/2, y: pageRect.midY - titleSize.height), withAttributes: titleAttrs)
            subtitle.draw(at: CGPoint(x: centerX - subtitleSize.width/2, y: pageRect.midY + 12), withAttributes: subtitleAttrs)

            let summary = reportSummaryLine(tasksCount: payload.tasks.count, sessionsCount: payload.sessions.count) as NSString
            let summaryAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 13),
                .foregroundColor: UIColor.secondaryLabel
            ]
            let summarySize = summary.size(withAttributes: summaryAttrs)
            summary.draw(at: CGPoint(x: centerX - summarySize.width/2, y: pageRect.midY + 36), withAttributes: summaryAttrs)

            // Render body pages from image slices
            let imageSize = uiImage.size
            let scaleFactor = (pageWidth - margin * 2) / imageSize.width
            let imageHeightInPDF = imageSize.height * scaleFactor

            var yOffset: CGFloat = 0
            var pageNumber = 2 // cover is page 1

            while yOffset < imageHeightInPDF {
                ctx.beginPage()

                // Header
                let headerTitle = reportTitle() as NSString
                let headerSubtitle = reportSubtitle(generatedAt: payload.generatedAt) as NSString
                let headerTitleAttrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.boldSystemFont(ofSize: 12),
                    .foregroundColor: UIColor.secondaryLabel
                ]
                let headerSubtitleAttrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 10),
                    .foregroundColor: UIColor.tertiaryLabel
                ]
                headerTitle.draw(at: CGPoint(x: margin, y: margin - 20), withAttributes: headerTitleAttrs)
                headerSubtitle.draw(at: CGPoint(x: margin, y: margin - 6), withAttributes: headerSubtitleAttrs)

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

                // Footer with page number
                let footer = "Página \(pageNumber)" as NSString
                let footerAttrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 10),
                    .foregroundColor: UIColor.tertiaryLabel
                ]
                let footerSize = footer.size(withAttributes: footerAttrs)
                footer.draw(at: CGPoint(x: pageRect.maxX - margin - footerSize.width, y: pageRect.maxY - margin - footerSize.height), withAttributes: footerAttrs)

                yOffset += usableHeight
                pageNumber += 1
            }
        }

        try data.write(to: url)
        return url
#elseif canImport(AppKit)
        let url = directory.appendingPathComponent("pepinillo_report.pdf")
        let contentView = ExportReportView(payload: payload)
            .frame(width: 612)
        let renderer = ImageRenderer(content: contentView)
        renderer.scale = 2.0

        guard let nsImage = renderer.nsImage else {
            throw ExportError.pdfRenderFailed
        }

        // Page setup
        let pageWidth: CGFloat = 612
        let pageHeight: CGFloat = 792
        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        let margin: CGFloat = 36
        let contentWidth = pageWidth - margin * 2
        let usableHeight = pageHeight - margin * 2

        // Compute scaling
        let imageSize = nsImage.size
        let scaleFactor = (pageWidth - margin * 2) / imageSize.width
        let imageHeightInPDF = imageSize.height * scaleFactor

        // PDF metadata
        let consumer = CGDataConsumer(url: url as CFURL)
        guard let consumer = consumer else { throw ExportError.pdfRenderFailed }
        var mediaBox = CGRect(origin: .zero, size: CGSize(width: pageWidth, height: pageHeight))
        let info: [CFString: Any] = [
            kCGPDFContextTitle: reportTitle(),
            kCGPDFContextAuthor: "Pepinillo",
            kCGPDFContextSubject: "Exported report"
        ]
        guard let ctx = CGContext(consumer: consumer, mediaBox: &mediaBox, info as CFDictionary) else {
            throw ExportError.pdfRenderFailed
        }

        // Cover page
        ctx.beginPDFPage([kCGPDFContextMediaBox: pageRect] as CFDictionary)
        // Flip for text drawing
        ctx.saveGState()
        ctx.translateBy(x: 0, y: pageHeight)
        ctx.scaleBy(x: 1, y: -1)
        let title = reportTitle()
        let subtitle = reportSubtitle(generatedAt: payload.generatedAt)
        let titleAttrs = [NSAttributedString.Key.font: NSFont.boldSystemFont(ofSize: 24)]
        let subtitleAttrs = [NSAttributedString.Key.font: NSFont.systemFont(ofSize: 14), NSAttributedString.Key.foregroundColor: NSColor.secondaryLabelColor]
        let titleStr = NSAttributedString(string: title, attributes: titleAttrs)
        let subtitleStr = NSAttributedString(string: subtitle, attributes: subtitleAttrs)
        let titleSize = titleStr.size()
        let subtitleSize = subtitleStr.size()
        let centerX = pageRect.midX
        titleStr.draw(at: CGPoint(x: centerX - titleSize.width/2, y: pageRect.midY - titleSize.height))
        subtitleStr.draw(at: CGPoint(x: centerX - subtitleSize.width/2, y: pageRect.midY + 12))

        let summaryStr = NSAttributedString(
            string: reportSummaryLine(tasksCount: payload.tasks.count, sessionsCount: payload.sessions.count),
            attributes: [.font: NSFont.systemFont(ofSize: 13), .foregroundColor: NSColor.secondaryLabelColor]
        )
        let summarySize = summaryStr.size()
        summaryStr.draw(at: CGPoint(x: centerX - summarySize.width/2, y: pageRect.midY + 36))

        ctx.restoreGState()
        ctx.endPDFPage()

        // Body pages
        var yOffset: CGFloat = 0
        var pageNumber = 2 // cover is page 1
        while yOffset < imageHeightInPDF {
            ctx.beginPDFPage([kCGPDFContextMediaBox: pageRect] as CFDictionary)

            // Flip for drawing
            ctx.saveGState()
            ctx.translateBy(x: 0, y: pageHeight)
            ctx.scaleBy(x: 1, y: -1)

            // Header
            let headerTitle = NSAttributedString(string: reportTitle(), attributes: [.font: NSFont.boldSystemFont(ofSize: 12), .foregroundColor: NSColor.secondaryLabelColor])
            let headerSubtitle = NSAttributedString(string: reportSubtitle(generatedAt: payload.generatedAt), attributes: [.font: NSFont.systemFont(ofSize: 10), .foregroundColor: NSColor.tertiaryLabelColor])
            headerTitle.draw(at: CGPoint(x: margin, y: margin - 20))
            headerSubtitle.draw(at: CGPoint(x: margin, y: margin - 6))

            // Slice
            let sourceY = yOffset / scaleFactor
            let sourceHeight = min(usableHeight / scaleFactor, imageSize.height - sourceY)
            let sourceRect = CGRect(x: 0, y: sourceY, width: imageSize.width, height: sourceHeight)

            if let cgRef = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                let cropRect = CGRect(x: sourceRect.origin.x,
                                      y: sourceRect.origin.y,
                                      width: sourceRect.width,
                                      height: sourceRect.height)
                if let cgImage = cgRef.cropping(to: cropRect) {
                    let destHeight = sourceRect.height * scaleFactor
                    let destRect = CGRect(x: margin, y: margin, width: contentWidth, height: destHeight)
                    ctx.draw(cgImage, in: destRect)
                }
            }

            // Footer
            let footer = NSAttributedString(string: "Página \(pageNumber)", attributes: [.font: NSFont.systemFont(ofSize: 10), .foregroundColor: NSColor.tertiaryLabelColor])
            let footerSize = footer.size()
            footer.draw(at: CGPoint(x: pageRect.maxX - margin - footerSize.width, y: pageRect.maxY - margin - footerSize.height))

            ctx.restoreGState()
            ctx.endPDFPage()

            yOffset += usableHeight
            pageNumber += 1
        }

        ctx.closePDF()
        return url
#else
        // PDF generation is not supported on this platform
        throw ExportError.pdfRenderFailed
#endif
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

