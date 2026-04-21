// ExportView.swift
// Pepinillo — Deep Work Companion for Apple
//
// Full-screen export destination pushed from Account tab.
// Allows exporting session history and task data as CSV or PDF.
// Gated behind PRO subscription for non-Pro users.

import SwiftUI

struct ExportView: View {
    let isPro: Bool

    @State private var selectedFormat: ExportFormat = .csv
    @State private var dateRange: ExportDateRange = .last30Days
    @State private var includeSessions = true
    @State private var includeTasks = true
    @State private var isExporting = false
    @State private var exportResult: ExportResult?

    var body: some View {
        List {
            formatSection
            dateRangeSection
            contentSection
            exportButtonSection
        }
        .listStyle(.insetGrouped)
        .navigationTitle(String(localized: "Export Data"))
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if isPro == false {
                proOverlay
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
                    }
                    .tag(format)
                }
            }
            .pickerStyle(.segmented)
        } header: {
            Text(String(localized: "Export Format"))
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
                performExport()
            } label: {
                HStack {
                    Spacer()
                    if isExporting {
                        ProgressView()
                            .controlSize(.regular)
                    } else {
                        Label(String(localized: "Export \(selectedFormat.label)"), systemImage: "square.and.arrow.up")
                            .font(.headline)
                    }
                    Spacer()
                }
            }
            .disabled(isExporting || (!includeSessions && !includeTasks))
            .foregroundStyle(isExporting || (!includeSessions && !includeTasks) ? Color.secondary : Color.white)
            .listRowBackground(Color.accentColor.opacity(isExporting || (!includeSessions && !includeTasks) ? 0.5 : 1))
        }
    }

    // MARK: - PRO Overlay

    private var proOverlay: some View {
        VStack(spacing: 16) {
            Image(systemName: "crown.fill")
                .font(.system(size: 40))
                .foregroundStyle(.yellow)

            Text(String(localized: "Export is a Pro Feature"))
                .font(.title3.bold())

            Text(String(localized: "Upgrade to Pepinillo Pro to export your focus sessions and tasks."))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.regularMaterial)
    }

    // MARK: - Actions

    private func performExport() {
        isExporting = true
        // TODO: Wire up actual export via ShareLink or file write
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            isExporting = false
            exportResult = .success
        }
    }
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
}

enum ExportResult {
    case success
    case failure(String)
}
