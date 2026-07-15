// ExportView.swift
// Pepinillo — Deep Work Companion for Apple
//
// Full-screen export destination pushed from Account tab.
// CSV export is available to all users; PDF is PRO-only (#202).

import SwiftUI
import ComposableArchitecture

struct ExportView: View {
    let isPro: Bool

    @Dependency(\.persistenceClient) private var persistence

    @State private var selectedFormat: ExportFormat = .csv
    @State private var dateRange: ExportDateRange = .last30Days
    @State private var includeSessions = true
    @State private var includeTasks = true
    @State private var isExporting = false
    @State private var exportError: String?
    @State private var shareItems: [URL] = []
    @State private var isShareSheetPresented = false
    @State private var tempDirectory: URL?

    private var requiresProUpgrade: Bool {
        selectedFormat == .pdf && !isPro
    }

    var body: some View {
        List {
            formatSection
            dateRangeSection
            contentSection
            exportButtonSection

            if let errorMessage = exportError {
                Section {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .font(.subheadline)
                        .foregroundStyle(.red)
                } header: {
                    Text(String(localized: "export.section.error_header",
                                defaultValue: "Export Failed"))
                }
            }
        }
        #if os(macOS)
        .listStyle(.inset)
        #else
        .listStyle(.insetGrouped)
        #endif
        .navigationTitle(String(localized: "Export Data"))
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if requiresProUpgrade {
                proOverlay
                    .accessibilityElement(children: .contain)
            }
        }
        .onDisappear {
            cleanupTempDirectory()
        }
        .sheet(isPresented: $isShareSheetPresented, onDismiss: {
            cleanupTempDirectory()
            shareItems = []
        }) {
            if !shareItems.isEmpty {
                ShareSheet(items: shareItems)
                    .ignoresSafeArea()
            }
        }
    }

    // MARK: - Format

    private var formatSection: some View {
        Section {
            Picker(String(localized: "Format"), selection: $selectedFormat) {
                ForEach(ExportFormat.allCases, id: \.self) { format in
                    HStack {
                        Image(systemName: format.icon)
                        Text(format.label)
                        if format == .pdf && !isPro {
                            Image(systemName: "crown.fill")
                                .foregroundStyle(.yellow)
                                .font(.caption2)
                        }
                    }
                    .tag(format)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: selectedFormat) { _, newValue in
                if newValue == .pdf && !isPro {
                    selectedFormat = .csv
                }
            }
        } header: {
            Text(String(localized: "Export Format"))
        } footer: {
            if !isPro {
                Text(String(localized: "export.footer.csv_free",
                            defaultValue: "CSV export is free. Upgrade to Pro for PDF reports."))
            }
        }
    }

    // MARK: - Date Range

    private var dateRangeSection: some View {
        Section {
            Picker(String(localized: "Time Period"), selection: $dateRange) {
                ForEach(ExportDateRange.allCases, id: \.self) { range in
                    Text(range.label).tag(range)
                }
            }
        } header: {
            Text(String(localized: "Date Range"))
        }
    }

    // MARK: - Content

    private var contentSection: some View {
        Section {
            Toggle(isOn: $includeSessions) {
                Label(String(localized: "Focus Sessions"), systemImage: "timer")
            }

            Toggle(isOn: $includeTasks) {
                Label(String(localized: "Tasks & Completions"), systemImage: "checklist")
            }
        } header: {
            Text(String(localized: "Include"))
        }
    }

    // MARK: - Export Button

    private var exportButtonSection: some View {
        Section {
            Button {
                Task { await performExport() }
            } label: {
                HStack {
                    Spacer()
                    if isExporting {
                        HStack(spacing: 10) {
                            ProgressView()
                                .controlSize(.regular)
                            Text(String(localized: "export.button.exporting",
                                        defaultValue: "Exporting…"))
                                .font(.headline)
                                .foregroundStyle(Color.white)
                        }
                    } else {
                        Label(
                            String(localized: "Export \(selectedFormat.label)"),
                            systemImage: "square.and.arrow.up"
                        )
                        .font(.headline)
                    }
                    Spacer()
                }
            }
            .disabled(isExporting || (!includeSessions && !includeTasks) || requiresProUpgrade)
            .foregroundStyle(
                isExporting || (!includeSessions && !includeTasks) || requiresProUpgrade
                    ? Color.secondary : Color.white
            )
            .listRowBackground(
                Color.accentColor.opacity(
                    isExporting || (!includeSessions && !includeTasks) || requiresProUpgrade ? 0.5 : 1
                )
            )
        }
    }

    // MARK: - PRO Overlay

    private var proOverlay: some View {
        VStack(spacing: 16) {
            Image(systemName: "crown.fill")
                .font(.system(size: 40))
                .foregroundStyle(.yellow)

            Text(String(localized: "PDF Export is a Pro Feature"))
                .font(.title3.bold())

            Text(String(localized: "Upgrade to Pepinillo Pro for PDF reports. CSV export is always free."))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.regularMaterial)
    }

    // MARK: - Export Action

    @MainActor
    private func performExport() async {
        guard !requiresProUpgrade else { return }
        guard !isExporting else { return }
        guard includeSessions || includeTasks else {
            exportError = ExportError.noDataSelected.errorDescription
            return
        }

        ExportService.cleanLegacyExportDirectories()
        cleanupTempDirectory()
        isExporting = true
        exportError = nil

        do {
            let (startDate, endDate) = dateRange.dateInterval()

            let tasks: [TaskItemDTO]
            let sessions: [SessionRecordDTO]

            if includeTasks {
                let all = try await persistence.fetchTasks()
                tasks = all.filter { task in
                    let refDate = task.completedAt ?? task.createdAt
                    return refDate >= startDate && refDate <= endDate
                }
            } else {
                tasks = []
            }

            if includeSessions {
                sessions = try await persistence.fetchSessions(startDate, endDate)
            } else {
                sessions = []
            }

            if tasks.isEmpty && sessions.isEmpty {
                throw ExportError.noDataInRange
            }

            let payload = ExportPayload(
                tasks: tasks,
                sessions: sessions,
                generatedAt: Date.now,
                dateRange: dateRange
            )

            let dir = try ExportService.makeTempDirectory()
            tempDirectory = dir

            var urls: [URL] = []
            switch selectedFormat {
            case .csv:
                urls = try ExportService.generateCSV(payload: payload, directory: dir)
            case .pdf:
                let pdfURL = try await ExportService.generatePDF(payload: payload, directory: dir)
                urls = [pdfURL]
            }

            guard !urls.isEmpty else {
                throw ExportError.noDataInRange
            }

            shareItems = urls
            isShareSheetPresented = true

        } catch let exportErr as ExportError {
            cleanupTempDirectory()
            exportError = exportErr.errorDescription
        } catch {
            cleanupTempDirectory()
            exportError = ExportError.writeFailed(error).errorDescription
        }

        isExporting = false
    }

    private func cleanupTempDirectory() {
        if let dir = tempDirectory {
            try? FileManager.default.removeItem(at: dir)
            tempDirectory = nil
        }
    }
}

// MARK: - Share Sheet Bridge

private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Supporting Types

enum ExportFormat: String, CaseIterable {
    case csv
    case pdf

    var label: String {
        switch self {
        case .csv: return "CSV"
        case .pdf: return "PDF"
        }
    }

    var icon: String {
        switch self {
        case .csv: return "doc.text"
        case .pdf: return "doc.richtext"
        }
    }
}

enum ExportDateRange: String, CaseIterable {
    case last7Days
    case last30Days
    case last90Days
    case allTime

    var label: String {
        switch self {
        case .last7Days:  return String(localized: "Last 7 Days")
        case .last30Days: return String(localized: "Last 30 Days")
        case .last90Days: return String(localized: "Last 90 Days")
        case .allTime:    return String(localized: "All Time")
        }
    }

    /// Returns (start, end) date interval for the range.
    func dateInterval() -> (start: Date, end: Date) {
        let now = Date.now
        let calendar = Calendar.current
        switch self {
        case .last7Days:
            return (calendar.date(byAdding: .day, value: -7, to: now)!, now)
        case .last30Days:
            return (calendar.date(byAdding: .day, value: -30, to: now)!, now)
        case .last90Days:
            return (calendar.date(byAdding: .day, value: -90, to: now)!, now)
        case .allTime:
            return (Date(timeIntervalSince1970: 0), now)
        }
    }
}

// ExportResult is no longer needed (error state is in exportError string)
// Kept as a deprecated alias to avoid breaking any stale references.
@available(*, deprecated, message: "Use exportError state instead.")
enum ExportResult {
    case success
    case failure(String)
}