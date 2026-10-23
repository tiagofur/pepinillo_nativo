// MacStatisticsView.swift
// Pepinillo — native macOS statistics window
//
// The F4 window from the design contract: period-switchable focus chart
// (7D/30D/Year) over the shared AnalyticsFeature state. The Year period is
// aggregated into weekly buckets client-side; month and week render daily bars.

import AppKit
import Charts
import ComposableArchitecture
import SwiftUI

struct MacStatisticsView: View {
    @Bindable var store: StoreOf<AnalyticsFeature>

    @Environment(\.appTheme) private var theme

    /// Local-only foreground rollup written by `MacActivitySampler`; created
    /// lazily so the JSON file is not read on every render.
    @State private var activityStore: AppActivityUsageStore?
    @State private var topActivity: [AppActivitySummary] = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                summaryHeader
                topActivityCard
                chartCard
            }
            .frame(maxWidth: 880, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(24)
        }
        .navigationTitle(String(localized: "Statistics"))
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Picker("Period", selection: periodBinding) {
                    ForEach(AnalyticsFeature.State.Period.allCases, id: \.self) { period in
                        Text(period.displayName).tag(period)
                    }
                }
                .pickerStyle(.segmented)
                .help("Statistics period")
            }

            if AppConfig.aiInsightsEnabled {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            store.send(.aiReportTapped(.week))
                        } label: {
                            Label(String(localized: "Weekly AI Report"), systemImage: "sparkles")
                        }
                        Button {
                            store.send(.aiReportTapped(.month))
                        } label: {
                            Label(String(localized: "Monthly AI Report"), systemImage: "sparkles")
                        }
                    } label: {
                        Label("Reports", systemImage: "sparkles")
                    }
                    .help("Generate AI reports")
                }
            }
        }
        // Same presentation as the iOS Dashboard sheet; the Pro gate lives in
        // the shared reducer (free users surface the paywall on the main
        // window via focus.showPaywall).
        .sheet(item: $store.scope(state: \.aiReport, action: \.aiReport)) { aiStore in
            AIReportView(store: aiStore)
                .frame(minWidth: 520, minHeight: 600)
        }
        .onAppear {
            store.send(.onAppear)
            refreshTopActivity()
        }
        .onChange(of: store.period) {
            refreshTopActivity()
        }
    }

    private var periodBinding: Binding<AnalyticsFeature.State.Period> {
        Binding(
            get: { store.period },
            set: { store.send(.periodChanged($0)) }
        )
    }

    // MARK: - Derived data

    /// One bar in the chart: a day for 7D/30D, a week for Year.
    private struct Bucket: Identifiable {
        let date: Date
        let minutes: Int
        let sessions: Int
        let label: String
        var id: Date { date }
    }

    private var buckets: [Bucket] {
        if store.period != .year {
            return store.chartData.map { point in
                Bucket(
                    date: point.date,
                    minutes: point.totalMinutes,
                    sessions: point.sessionsCompleted,
                    label: point.date.formatted(.dateTime.weekday(.wide))
                )
            }
        }
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: store.chartData) { point in
            calendar.dateInterval(of: .weekOfYear, for: point.date)?.start ?? point.date
        }
        return grouped
            .map { date, points in
                Bucket(
                    date: date,
                    minutes: points.reduce(0) { $0 + $1.totalMinutes },
                    sessions: points.reduce(0) { $0 + $1.sessionsCompleted },
                    label: date.formatted(.dateTime.month(.abbreviated).day())
                )
            }
            .sorted { $0.date < $1.date }
    }

    private var totalMinutes: Int {
        buckets.reduce(0) { $0 + $1.minutes }
    }

    private var totalSessions: Int {
        buckets.reduce(0) { $0 + $1.sessions }
    }

    private var bestBucket: Bucket? {
        buckets.filter { $0.minutes > 0 }.max { $0.minutes < $1.minutes }
    }

    // MARK: - Header

    private var summaryHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 14) {
                Text(durationText(TimeInterval(totalMinutes) * 60))
                    .font(.system(.largeTitle, design: .rounded).weight(.semibold))
                    .monospacedDigit()
                Text(store.period.displayName)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 16) {
                Label {
                    Text("\(totalSessions) sessions")
                } icon: {
                    Image(systemName: "checkmark.circle")
                        .foregroundStyle(theme.color(for: .flowtime))
                }
                if let bestBucket {
                    Label {
                        Text("Best day: \(bestBucket.label)")
                    } icon: {
                        Image(systemName: "star")
                            .foregroundStyle(theme.streakColor)
                    }
                }
                Label {
                    Text("\(store.currentStreakDays) days streak")
                } icon: {
                    Image(systemName: "flame.fill")
                        .foregroundStyle(theme.streakColor)
                }
            }
            .font(.callout)
            .foregroundStyle(.secondary)
        }
    }

    // MARK: - Top activity

    private func refreshTopActivity() {
        if activityStore == nil {
            activityStore = AppActivityUsageStore()
        }
        topActivity = activityStore?.topApps(
            limit: 4,
            daysBack: store.period.days,
            reference: .now
        ) ?? []
    }

    /// Foreground apps captured during focus sessions (opt-in sampler). The
    /// card stays hidden until the sampler has written at least one rollup.
    @ViewBuilder
    private var topActivityCard: some View {
        if !topActivity.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Top activity")
                    .font(.headline)
                HStack(spacing: 16) {
                    ForEach(topActivity, id: \.bundleID) { app in
                        topActivityIcon(app)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .pepinilloGlass(cornerRadius: GlassCornerRadius.card)
        }
    }

    private func topActivityIcon(_ app: AppActivitySummary) -> some View {
        Group {
            if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: app.bundleID) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: appURL.path))
                    .resizable()
            } else {
                Image(systemName: "app.dashed")
                    .font(.system(size: 26))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 32, height: 32)
        .help("\(app.name) · \(durationText(app.seconds))")
        .accessibilityLabel(Text("\(app.name), \(durationText(app.seconds))"))
    }

    // MARK: - Chart

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            if totalMinutes <= 0 {
                Text("No sessions in this period")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 24)
            } else {
                chart
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .pepinilloGlass(cornerRadius: GlassCornerRadius.card)
    }

    private var chart: some View {
        Chart(buckets) { bucket in
            BarMark(
                x: .value("Day", bucket.date, unit: store.period == .year ? .weekOfYear : .day),
                y: .value("Minutes", bucket.minutes)
            )
            .foregroundStyle(theme.color(for: .pomodoro).opacity(0.85))
            .cornerRadius(3)
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: store.period == .year ? .month : .day)) { _ in
                AxisGridLine()
                    .foregroundStyle(.quaternary)
                AxisValueLabel(format: store.period == .year
                    ? .dateTime.month(.abbreviated)
                    : .dateTime.weekday(.narrow))
                    .font(.caption)
            }
        }
        .chartYAxis {
            AxisMarks(position: .trailing) { value in
                AxisGridLine()
                    .foregroundStyle(.quaternary)
                AxisValueLabel {
                    if let minutes = value.as(Int.self) {
                        Text("\(minutes) min")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .frame(minHeight: 220)
        .accessibilityLabel(Text("Focus minutes for the selected period"))
        .accessibilityValue(Text("\(totalMinutes) minutes"))
    }

    // MARK: - Formatting

    private func durationText(_ seconds: TimeInterval) -> String {
        let value = Duration.seconds(max(0, seconds))
        if seconds < 60 {
            return value.formatted(.units(allowed: [.seconds], width: .abbreviated))
        }
        return value.formatted(.units(allowed: [.hours, .minutes], width: .abbreviated))
    }
}
