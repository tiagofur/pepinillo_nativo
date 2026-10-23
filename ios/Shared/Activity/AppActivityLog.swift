// AppActivityLog.swift
// Pepinillo — local foreground-app usage captured during focus sessions
//
// Pure Foundation model behind the macOS top-activity statistics. Deliberately
// AppKit-free and compiled into every target so the shared test suite can
// exercise the accumulation and rollup logic without AppKit.
//
// Privacy contract: only bundle IDs, display names, and seconds are stored,
// in a local JSON file. Nothing is synced, logged, or uploaded — app names
// never leave this Mac.

import Foundation

/// One app's captured foreground time: seconds total plus the best display
/// name observed while it was frontmost (kept so the list still makes sense
/// after the app is uninstalled).
struct AppActivityUsage: Codable, Equatable {
    var seconds: Double
    var name: String
}

/// Per-app aggregate for display.
struct AppActivitySummary: Equatable {
    let bundleID: String
    let name: String
    let seconds: TimeInterval
}

/// Pure accumulation for foreground samples. Consecutive samples of the same
/// app accrue the elapsed delta between them; a sample of a different app
/// closes the open interval. `closeInterval()` discards the open interval so
/// pauses, screen locks, and session ends cannot stretch a stale app's time.
struct AppActivityAccumulator {
    private(set) var usage: [String: AppActivityUsage] = [:]

    private var lastBundleID: String?
    private var lastTimestamp: Date?

    /// Deltas above this are treated as sleep or clock gaps, not usage.
    static let maxSampleDelta: TimeInterval = 60

    mutating func record(bundleID: String, name: String, at timestamp: Date) {
        if let lastBundleID, let lastTimestamp, timestamp > lastTimestamp {
            let delta = timestamp.timeIntervalSince(lastTimestamp)
            // The interval belongs to the app that was frontmost during it —
            // the previous sample. Deltas beyond `maxSampleDelta` are sleep
            // or clock gaps, not usage.
            if delta < Self.maxSampleDelta {
                usage[lastBundleID, default: AppActivityUsage(seconds: 0, name: name)].seconds += delta
            }
        }
        lastBundleID = bundleID
        lastTimestamp = timestamp
        if usage[bundleID] == nil {
            usage[bundleID] = AppActivityUsage(seconds: 0, name: name)
        } else {
            usage[bundleID]?.name = name
        }
    }

    mutating func closeInterval() {
        lastBundleID = nil
        lastTimestamp = nil
    }

    /// Take everything captured so far and start over (session flush).
    /// Zero-second seeding entries (the app that happened to be frontmost at
    /// the end) are dropped so they never occupy a slot in the statistics.
    mutating func takeUsage() -> [String: AppActivityUsage] {
        let taken = usage.filter { $0.value.seconds > 0 }
        usage = [:]
        closeInterval()
        return taken
    }
}

/// Daily rollup persisted to local JSON: day key → bundle ID → usage. The Mac
/// Statistics window reads this directly; nothing else touches the file.
struct AppActivityUsageStore {
    /// Days older than this are pruned on save (longer than the Year chart).
    static let retentionDays = 400

    private let fileURL: URL
    private var days: [String: [String: AppActivityUsage]]
    private let dayFormatter: DateFormatter

    static func defaultFileURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base
            .appendingPathComponent("PepinilloMac", isDirectory: true)
            .appendingPathComponent("activity-usage.json", isDirectory: false)
    }

    init(fileURL: URL = AppActivityUsageStore.defaultFileURL()) {
        self.fileURL = fileURL
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        self.dayFormatter = formatter
        self.days = Self.loadDays(from: fileURL)
    }

    mutating func merge(_ usage: [String: AppActivityUsage], on date: Date) {
        let key = dayFormatter.string(from: date)
        var day = days[key] ?? [:]
        for (bundleID, added) in usage {
            var existing = day[bundleID] ?? AppActivityUsage(seconds: 0, name: added.name)
            existing.seconds += added.seconds
            existing.name = added.name
            day[bundleID] = existing
        }
        days[key] = day
        save()
    }

    /// Top apps by foreground seconds within `daysBack` days of `reference`
    /// (today inclusive), most-used first.
    func topApps(limit: Int, daysBack: Int, reference: Date) -> [AppActivitySummary] {
        let calendar = Calendar.current
        let cutoff = calendar.date(
            byAdding: .day,
            value: -(max(1, daysBack) - 1),
            to: calendar.startOfDay(for: reference)
        ) ?? .distantPast

        var totals: [String: (seconds: Double, name: String)] = [:]
        for (key, apps) in days {
            guard let day = dayFormatter.date(from: key), day >= cutoff else { continue }
            for (bundleID, usage) in apps {
                var total = totals[bundleID] ?? (0, usage.name)
                total.seconds += usage.seconds
                total.name = usage.name
                totals[bundleID] = total
            }
        }

        return totals
            .map { AppActivitySummary(bundleID: $0.key, name: $0.value.name, seconds: $0.value.seconds) }
            .sorted { $0.seconds > $1.seconds }
            .prefix(limit)
            .map { $0 }
    }

    private static func loadDays(from url: URL) -> [String: [String: AppActivityUsage]] {
        guard let data = try? Data(contentsOf: url) else { return [:] }
        return (try? JSONDecoder().decode([String: [String: AppActivityUsage]].self, from: data)) ?? [:]
    }

    /// Atomic best-effort write: losing a statistics rollup is acceptable, a
    /// thrown error on the sampling path is not worth surfacing.
    private mutating func save() {
        prune()
        try? FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        guard let data = try? JSONEncoder().encode(days) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    private mutating func prune() {
        guard let cutoff = Calendar.current.date(byAdding: .day, value: -Self.retentionDays, to: .now)
        else { return }
        days = days.filter { key, _ in
            guard let day = dayFormatter.date(from: key) else { return false }
            return day >= cutoff
        }
    }
}
