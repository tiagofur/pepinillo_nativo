// ExportReportView.swift
// Pepinillo — Deep Work Companion for Apple
//
// SwiftUI view rendered by ImageRenderer to produce the PDF export report.
// Layout targets a 612pt-wide canvas (US Letter) at 2× scale.
// This view is intentionally self-contained: it reads only the ExportPayload
// and uses no TCA or environment dependencies.

import SwiftUI

struct ExportReportView: View {
    let payload: ExportPayload

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .long
        f.timeStyle = .none
        return f
    }()

    private static let shortDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .short
        f.timeStyle = .none
        return f
    }()

    // MARK: - Derived stats

    private var totalFocusMinutes: Int {
        Int(payload.sessions.reduce(0) { $0 + $1.actualDuration } / 60)
    }

    private var completedSessions: Int {
        payload.sessions.filter(\.wasCompleted).count
    }

    private var completedTasks: Int {
        payload.tasks.filter(\.isCompleted).count
    }

    private var modeBreakdown: [(String, Int)] {
        var dict: [String: TimeInterval] = [:]
        for session in payload.sessions {
            dict[session.mode, default: 0] += session.actualDuration
        }
        return dict
            .map { (modeDisplayName($0.key), Int($0.value / 60)) }
            .sorted { $0.1 > $1.1 }
    }

    private func modeDisplayName(_ raw: String) -> String {
        switch raw {
        case "pomodoro":   return String(localized: "export.mode.pomodoro", defaultValue: "Pomodoro")
        case "flowtime":   return String(localized: "export.mode.flowtime", defaultValue: "Flowtime")
        case "timeBlock":  return String(localized: "export.mode.time_block", defaultValue: "Time Block")
        case "stopwatch":  return String(localized: "export.mode.stopwatch", defaultValue: "Stopwatch")
        default:           return raw.capitalized
        }
    }

    private var dateRangeLabel: String {
        payload.dateRange.label
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider().padding(.vertical, 16)
            summarySection
            if !payload.sessions.isEmpty {
                Divider().padding(.vertical, 16)
                sessionsSection
            }
            if !payload.tasks.isEmpty {
                Divider().padding(.vertical, 16)
                tasksSection
            }
            Spacer(minLength: 24)
            footer
        }
        .padding(36)
        .background(Color.white)
        .environment(\.colorScheme, .light)
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Image(systemName: "timer")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(Color(red: 0.2, green: 0.7, blue: 0.4))

                    Text("Pepinillo")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(.black)
                }

                Text(String(localized: "export.report.title",
                            defaultValue: "Productivity Report"))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color(.darkGray))

                Text(dateRangeLabel)
                    .font(.system(size: 12))
                    .foregroundStyle(Color(.gray))
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(String(localized: "export.report.generated_on",
                            defaultValue: "Generated on"))
                    .font(.system(size: 11))
                    .foregroundStyle(Color(.gray))
                Text(Self.dateFormatter.string(from: payload.generatedAt))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color(.darkGray))
            }
        }
    }

    // MARK: - Summary

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle(String(localized: "export.section.summary", defaultValue: "Summary"))

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                statCard(
                    value: "\(totalFocusMinutes)",
                    label: String(localized: "export.stat.focus_minutes", defaultValue: "Focus Minutes"),
                    icon: "clock.fill",
                    color: Color(red: 0.2, green: 0.6, blue: 1.0)
                )
                statCard(
                    value: "\(completedSessions)",
                    label: String(localized: "export.stat.sessions_completed", defaultValue: "Sessions Completed"),
                    icon: "checkmark.circle.fill",
                    color: Color(red: 0.2, green: 0.75, blue: 0.4)
                )
                statCard(
                    value: "\(completedTasks)",
                    label: String(localized: "export.stat.tasks_completed", defaultValue: "Tasks Completed"),
                    icon: "checklist",
                    color: Color(red: 0.6, green: 0.3, blue: 0.9)
                )
            }

            if !modeBreakdown.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text(String(localized: "export.section.mode_breakdown",
                                defaultValue: "Focus Mode Breakdown"))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color(.gray))
                        .textCase(.uppercase)

                    ForEach(modeBreakdown, id: \.0) { mode, minutes in
                        HStack {
                            Text(mode)
                                .font(.system(size: 12))
                                .foregroundStyle(.black)
                            Spacer()
                            Text("\(minutes) min")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Color(.darkGray))
                        }
                        .padding(.vertical, 2)
                    }
                }
                .padding(12)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    // MARK: - Sessions Table

    private var sessionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle(String(localized: "Focus Sessions"))

            // Table header
            tableRow(
                cells: [
                    String(localized: "export.table.date", defaultValue: "Date"),
                    String(localized: "export.table.mode", defaultValue: "Mode"),
                    String(localized: "export.table.duration", defaultValue: "Duration"),
                    String(localized: "export.table.completed", defaultValue: "Completed")
                ],
                isHeader: true
            )

            let displayedSessions = Array(payload.sessions.prefix(30))
            ForEach(Array(displayedSessions.enumerated()), id: \.offset) { index, session in
                tableRow(
                    cells: [
                        Self.shortDateFormatter.string(from: session.startedAt),
                        modeDisplayName(session.mode),
                        formatDuration(session.actualDuration),
                        session.wasCompleted
                            ? String(localized: "export.yes", defaultValue: "Yes")
                            : String(localized: "export.no", defaultValue: "No")
                    ],
                    isHeader: false,
                    isEven: index % 2 == 1
                )
            }

            if payload.sessions.count > 30 {
                Text(String(localized: "export.sessions.truncated",
                            defaultValue: "Showing 30 of \(payload.sessions.count) sessions. Full data available in the CSV export."))
                    .font(.system(size: 10))
                    .foregroundStyle(Color(.gray))
                    .padding(.top, 4)
            }
        }
    }

    // MARK: - Tasks Table

    private var tasksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle(String(localized: "Tasks & Completions"))

            tableRow(
                cells: [
                    String(localized: "export.table.task", defaultValue: "Task"),
                    String(localized: "export.table.priority", defaultValue: "Priority"),
                    String(localized: "export.table.pomodoros", defaultValue: "Pomodoros"),
                    String(localized: "export.table.status", defaultValue: "Status")
                ],
                isHeader: true
            )

            let displayedTasks = Array(payload.tasks.prefix(30))
            ForEach(Array(displayedTasks.enumerated()), id: \.offset) { index, task in
                tableRow(
                    cells: [
                        task.title,
                        task.priority.displayName,
                        "\(task.completedPomodoros)/\(task.estimatedPomodoros)",
                        task.isCompleted
                            ? String(localized: "export.status.done", defaultValue: "Done")
                            : String(localized: "export.status.pending", defaultValue: "Pending")
                    ],
                    isHeader: false,
                    isEven: index % 2 == 1
                )
            }

            if payload.tasks.count > 30 {
                Text(String(localized: "export.tasks.truncated",
                            defaultValue: "Showing 30 of \(payload.tasks.count) tasks. Full data available in the CSV export."))
                    .font(.system(size: 10))
                    .foregroundStyle(Color(.gray))
                    .padding(.top, 4)
            }
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Text("Pepinillo · pepinillo.app")
                .font(.system(size: 9))
                .foregroundStyle(Color(.lightGray))
            Spacer()
            Text(Self.dateFormatter.string(from: payload.generatedAt))
                .font(.system(size: 9))
                .foregroundStyle(Color(.lightGray))
        }
        .padding(.top, 8)
    }

    // MARK: - Reusable Components

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(.black)
            .padding(.bottom, 2)
    }

    private func statCard(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(color)
                Text(label)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(Color(.gray))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(.black)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(color.opacity(0.2), lineWidth: 1)
        )
    }

    private func tableRow(cells: [String], isHeader: Bool, isEven: Bool = false) -> some View {
        let columns = [
            GridItem(.flexible(minimum: 80)),
            GridItem(.fixed(70)),
            GridItem(.fixed(70)),
            GridItem(.fixed(70))
        ]
        return LazyVGrid(columns: columns, alignment: .leading, spacing: 0) {
            ForEach(Array(cells.enumerated()), id: \.offset) { _, cell in
                Text(cell)
                    .font(.system(size: isHeader ? 10 : 11,
                                  weight: isHeader ? .semibold : .regular))
                    .foregroundStyle(isHeader ? Color(.gray) : Color(.darkGray))
                    .textCase(isHeader ? .uppercase : .none)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 5)
                    .padding(.horizontal, 4)
            }
        }
        .background(
            isHeader
                ? Color(.systemGray5)
                : (isEven ? Color(.systemGray6) : Color.white)
        )
        .clipShape(RoundedRectangle(cornerRadius: isHeader ? 6 : 0))
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        if minutes >= 60 {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            return "\(hours)h \(remainingMinutes)m"
        }
        return "\(minutes)m"
    }
}
