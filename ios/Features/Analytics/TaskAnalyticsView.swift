// TaskAnalyticsView.swift
// Pepinillo — Deep Work Companion for Apple
//
// Per-task productivity analytics sheet.
// Displays focus time, sessions, interruptions, mode distribution, and estimation accuracy.

import SwiftUI
import ComposableArchitecture

struct TaskAnalyticsView: View {
    @Bindable var store: StoreOf<TaskAnalyticsFeature>
    @Environment(\.appTheme) private var theme

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if store.isLoading {
                        TaskAnalyticsPlaceholder()
                            .redacted(reason: .placeholder)
                            .padding(.horizontal, 16)
                    } else if let analytics = store.analytics {
                        contentView(analytics)
                            .padding(.horizontal, 16)
                    } else {
                        ContentUnavailableView(
                            String(localized: "No Data Yet"),
                            systemImage: "chart.bar",
                            description: Text(String(localized: "Complete a focus session on this task to see analytics."))
                        )
                        .padding(.top, 40)
                    }
                }
                .padding(.bottom, 32)
            }
            .navigationTitle(String(localized: "Focus Analytics"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "Done")) {
                        store.send(.dismiss)
                    }
                }
            }
            .onAppear { store.send(.onAppear) }
        }
    }

    // MARK: - Content

    @ViewBuilder
    private func contentView(_ analytics: TaskAnalyticsDTO) -> some View {
        // Task title header
        Text(store.taskTitle)
            .font(.title2.weight(.bold))
            .frame(maxWidth: .infinity, alignment: .leading)

        // Summary cards
        summaryCards(analytics)

        // Interruptions & Pauses
        interruptionsSection(analytics)

        // Estimation accuracy
        if analytics.estimatedPomodoros > 0 {
            estimationSection(analytics)
        }

        // Mode distribution
        if !analytics.modeDistribution.isEmpty {
            modeDistributionSection(analytics)
        }

        // Peak hour
        if let peakHour = analytics.peakHourBucket {
            peakHourSection(peakHour)
        }

        // Satisfaction rating
        if let avgRating = analytics.avgSatisfactionRating, avgRating > 0 {
            satisfactionSection(avgRating)
        }
    }

    // MARK: - Summary Cards

    private func summaryCards(_ analytics: TaskAnalyticsDTO) -> some View {
        HStack(spacing: 12) {
            SummaryCard(
                title: String(localized: "Focus Time"),
                value: formatSeconds(analytics.totalFocusSeconds),
                icon: "brain.head.profile",
                color: theme.pomodoroColor
            )
            SummaryCard(
                title: String(localized: "Sessions"),
                value: "\(analytics.completedSessions)/\(analytics.totalSessions)",
                icon: "checkmark.circle",
                color: theme.flowtimeColor
            )
            SummaryCard(
                title: String(localized: "Completion"),
                value: analytics.totalSessions > 0
                    ? "\(Int(Double(analytics.completedSessions) / Double(analytics.totalSessions) * 100))%"
                    : "–",
                icon: "target",
                color: .green
            )
        }
    }

    // MARK: - Interruptions & Pauses

    private func interruptionsSection(_ analytics: TaskAnalyticsDTO) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "Focus Quality"))
                .font(.headline)
                .accessibilityAddTraits(.isHeader)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                PatternCard(
                    title: String(localized: "Interruptions"),
                    value: "\(analytics.totalInterruptions)",
                    icon: "hand.raised.fill",
                    color: .orange
                )
                PatternCard(
                    title: String(localized: "Avg/Session"),
                    value: String(format: "%.1f", analytics.avgInterruptionsPerSession),
                    icon: "chart.line.downtrend.xyaxis",
                    color: .orange
                )
                PatternCard(
                    title: String(localized: "Total Pauses"),
                    value: "\(analytics.totalPauses)",
                    icon: "pause.circle.fill",
                    color: .purple
                )
                PatternCard(
                    title: String(localized: "Avg Duration"),
                    value: analytics.totalSessions > 0
                        ? formatSeconds(analytics.avgSessionSeconds)
                        : "–",
                    icon: "clock.fill",
                    color: .blue
                )
            }
        }
        .padding(16)
        .pepinilloGlass(cornerRadius: GlassCornerRadius.card)
    }

    // MARK: - Estimation Accuracy

    private func estimationSection(_ analytics: TaskAnalyticsDTO) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "Estimation Accuracy"))
                .font(.headline)
                .accessibilityAddTraits(.isHeader)

            HStack(spacing: 16) {
                VStack(spacing: 4) {
                    Text(String(localized: "Estimated"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(analytics.estimatedPomodoros)")
                        .font(.title2.weight(.bold))
                }
                .frame(maxWidth: .infinity)

                VStack(spacing: 4) {
                    Text(String(localized: "Completed"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(analytics.completedPomodoros)")
                        .font(.title2.weight(.bold))
                }
                .frame(maxWidth: .infinity)
            }

            if analytics.estimatedPomodoros > 0 {
                let progress = min(Double(analytics.completedPomodoros) / Double(analytics.estimatedPomodoros), 1.0)
                ProgressView(value: progress)
                    .tint(progress >= 1.0 ? .green : theme.pomodoroColor)

                if let accuracy = analytics.estimationAccuracy {
                    Text(accuracy > 1.0
                        ? String(localized: "Over estimate by \(Int((accuracy - 1.0) * 100))%")
                        : String(localized: "\(Int(accuracy * 100))% of estimate used")
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
        }
        .padding(16)
        .pepinilloGlass(cornerRadius: GlassCornerRadius.card)
    }

    // MARK: - Mode Distribution

    private func modeDistributionSection(_ analytics: TaskAnalyticsDTO) -> some View {
        let totalSeconds = max(1, analytics.modeDistribution.values.reduce(0, +))

        return VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "Mode Distribution"))
                .font(.headline)
                .accessibilityAddTraits(.isHeader)

            VStack(spacing: 8) {
                ForEach(analytics.modeDistribution.sorted(by: { $0.value > $1.value }), id: \.key) { mode, seconds in
                    let percentage = Double(seconds) / Double(totalSeconds)
                    let focusMode = FocusMode(rawValue: mode)

                    VStack(spacing: 4) {
                        HStack {
                            if let fm = focusMode {
                                Text(fm.icon)
                                Text(fm.displayName)
                                    .font(.subheadline)
                            } else {
                                Text(mode)
                                    .font(.subheadline)
                            }
                            Spacer()
                            Text("\(seconds / 60)m")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text("\(Int(percentage * 100))%")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .frame(width: 40, alignment: .trailing)
                        }

                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color.secondary.opacity(0.15))
                                    .frame(height: 6)
                                Capsule()
                                    .fill(focusMode.map { theme.color(for: $0) } ?? .blue)
                                    .frame(width: geo.size.width * percentage, height: 6)
                            }
                        }
                        .frame(height: 6)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(focusMode?.displayName ?? mode), \(seconds / 60) minutes, \(Int(percentage * 100)) percent")
                }
            }
        }
        .padding(16)
        .pepinilloGlass(cornerRadius: GlassCornerRadius.card)
    }

    // MARK: - Peak Hour

    private func peakHourSection(_ peakHour: Int) -> some View {
        let endHour = (peakHour + 2) % 24
        let fmt = DateFormatter()
        fmt.dateFormat = "h a"
        let calendar = Calendar.current
        var sc = DateComponents(); sc.hour = peakHour
        var ec = DateComponents(); ec.hour = endHour
        let peakLabel: String
        if let sd = calendar.date(from: sc), let ed = calendar.date(from: ec) {
            peakLabel = "\(fmt.string(from: sd))–\(fmt.string(from: ed))"
        } else {
            peakLabel = "–"
        }

        return HStack(spacing: 12) {
            Image(systemName: "clock.fill")
                .font(.title2)
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text(String(localized: "Peak Focus Hour"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(peakLabel)
                    .font(.title3.weight(.bold))
            }
            Spacer()
        }
        .padding(16)
        .pepinilloGlass(cornerRadius: GlassCornerRadius.card)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(localized: "Peak focus hour, \(peakLabel)"))
    }

    // MARK: - Satisfaction

    private func satisfactionSection(_ avgRating: Double) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "star.fill")
                .font(.title2)
                .foregroundStyle(.yellow)
            VStack(alignment: .leading, spacing: 2) {
                Text(String(localized: "Avg Satisfaction"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack(spacing: 2) {
                    ForEach(1...5, id: \.self) { star in
                        Image(systemName: Double(star) <= avgRating ? "star.fill" : "star")
                            .font(.body)
                            .foregroundStyle(Double(star) <= avgRating ? .yellow : .secondary.opacity(0.3))
                    }
                    Text(String(format: "%.1f", avgRating))
                        .font(.subheadline.weight(.semibold))
                        .padding(.leading, 4)
                }
            }
            Spacer()
        }
        .padding(16)
        .pepinilloGlass(cornerRadius: GlassCornerRadius.card)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(localized: "Average satisfaction, \(String(format: "%.1f", avgRating)) out of 5"))
    }

    // MARK: - Helpers

    private func formatSeconds(_ seconds: Int) -> String {
        let minutes = seconds / 60
        if minutes < 60 {
            return String(localized: "\(minutes)m")
        }
        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        if remainingMinutes == 0 {
            return String(localized: "\(hours)h")
        }
        return String(localized: "\(hours)h \(remainingMinutes)m")
    }
}

// MARK: - Loading Placeholder

private struct TaskAnalyticsPlaceholder: View {
    var body: some View {
        VStack(spacing: 20) {
            // Title placeholder
            HStack {
                Text("Task Title Placeholder")
                    .font(.title2.weight(.bold))
                Spacer()
            }

            // Summary cards placeholder
            HStack(spacing: 12) {
                ForEach(0..<3, id: \.self) { _ in
                    VStack(spacing: 8) {
                        Text("00h 00m")
                            .font(.title3.weight(.bold))
                        Text("Focus Time")
                            .font(.caption)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(16)
                    .pepinilloGlass(cornerRadius: GlassCornerRadius.card)
                }
            }

            // Pattern cards placeholder
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(0..<4, id: \.self) { _ in
                    VStack(spacing: 8) {
                        Text("00")
                            .font(.title3.weight(.bold))
                        Text("Metric")
                            .font(.caption)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(14)
                    .background(Color(.tertiarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(16)
            .pepinilloGlass(cornerRadius: GlassCornerRadius.card)
        }
    }
}
