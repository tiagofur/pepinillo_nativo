// AppActivityLogTests.swift
// Pepinillo — tests for the local foreground-activity accumulator and rollup
//
// The macOS sampler (AppKit) feeds `AppActivityAccumulator` and persists
// through `AppActivityUsageStore`; both are pure Foundation, so the logic is
// exercised here without AppKit.

import Testing
import Foundation
@testable import Pepinillo

@Suite("AppActivityAccumulator")
struct AppActivityAccumulatorTests {

    @Test func consecutiveSamplesAccrueDelta() {
        var accumulator = AppActivityAccumulator()
        let t0 = Date(timeIntervalSince1970: 1_000)

        accumulator.record(bundleID: "com.apple.Safari", name: "Safari", at: t0)
        accumulator.record(bundleID: "com.apple.Safari", name: "Safari", at: t0.addingTimeInterval(1))
        accumulator.record(bundleID: "com.apple.Safari", name: "Safari", at: t0.addingTimeInterval(2))

        #expect(accumulator.usage["com.apple.Safari"]?.seconds == 2)
        #expect(accumulator.usage["com.apple.Safari"]?.name == "Safari")
    }

    @Test func appSwitchClosesPreviousInterval() {
        var accumulator = AppActivityAccumulator()
        let t0 = Date(timeIntervalSince1970: 1_000)

        // 1 Hz sampler cadence: Safari until t0+2, Slack from t0+3 on.
        accumulator.record(bundleID: "com.apple.Safari", name: "Safari", at: t0)
        accumulator.record(bundleID: "com.apple.Safari", name: "Safari", at: t0.addingTimeInterval(1))
        accumulator.record(bundleID: "com.apple.Safari", name: "Safari", at: t0.addingTimeInterval(2))
        accumulator.record(bundleID: "com.apple.Slack", name: "Slack", at: t0.addingTimeInterval(3))
        accumulator.record(bundleID: "com.apple.Slack", name: "Slack", at: t0.addingTimeInterval(4))

        // The [2,3] interval is credited to Safari (frontmost until the
        // switch); Slack only accrues from its own second sample onward.
        #expect(accumulator.usage["com.apple.Safari"]?.seconds == 3)
        #expect(accumulator.usage["com.apple.Slack"]?.seconds == 1)
    }

    @Test func largeDeltaIsIgnoredAsSleepGap() {
        var accumulator = AppActivityAccumulator()
        let t0 = Date(timeIntervalSince1970: 1_000)

        accumulator.record(bundleID: "com.apple.Safari", name: "Safari", at: t0)
        accumulator.record(bundleID: "com.apple.Safari", name: "Safari", at: t0.addingTimeInterval(600))

        #expect(accumulator.usage["com.apple.Safari"]?.seconds == 0)
    }

    @Test func closeIntervalDropsOpenInterval() {
        var accumulator = AppActivityAccumulator()
        let t0 = Date(timeIntervalSince1970: 1_000)

        accumulator.record(bundleID: "com.apple.Safari", name: "Safari", at: t0)
        accumulator.closeInterval()
        accumulator.record(bundleID: "com.apple.Safari", name: "Safari", at: t0.addingTimeInterval(45))

        #expect(accumulator.usage["com.apple.Safari"]?.seconds == 0)
    }

    @Test func takeUsageResetsForTheNextSession() {
        var accumulator = AppActivityAccumulator()
        let t0 = Date(timeIntervalSince1970: 1_000)

        accumulator.record(bundleID: "com.zed.Zed", name: "Zed", at: t0)
        accumulator.record(bundleID: "com.zed.Zed", name: "Zed", at: t0.addingTimeInterval(5))

        let taken = accumulator.takeUsage()

        #expect(taken["com.zed.Zed"]?.seconds == 5)
        #expect(accumulator.usage.isEmpty)
    }
}

@Suite("AppActivityUsageStore")
struct AppActivityUsageStoreTests {

    private func makeStoreURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("pepinillo-activity-tests-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("activity-usage.json")
    }

    private var noon: Date {
        Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: .now)!
    }

    @Test func mergeAggregatesAcrossDaysAndSortsTopApps() {
        var store = AppActivityUsageStore(fileURL: makeStoreURL())

        store.merge(
            [
                "com.zed.Zed": AppActivityUsage(seconds: 600, name: "Zed"),
                "com.apple.Safari": AppActivityUsage(seconds: 120, name: "Safari"),
            ],
            on: noon
        )
        store.merge(
            ["com.zed.Zed": AppActivityUsage(seconds: 300, name: "Zed")],
            on: noon.addingTimeInterval(-86_400)
        )

        let top = store.topApps(limit: 4, daysBack: 7, reference: noon)
        #expect(top.count == 2)
        #expect(top[0].bundleID == "com.zed.Zed")
        #expect(top[0].seconds == 900)
        #expect(top[0].name == "Zed")
        #expect(top[1].bundleID == "com.apple.Safari")
    }

    @Test func topAppsFiltersByPeriodAndLimit() {
        var store = AppActivityUsageStore(fileURL: makeStoreURL())

        store.merge(["com.a.A": AppActivityUsage(seconds: 10, name: "A")], on: noon)
        store.merge(
            ["com.b.B": AppActivityUsage(seconds: 999, name: "B")],
            on: noon.addingTimeInterval(-40 * 86_400)
        )

        #expect(store.topApps(limit: 4, daysBack: 7, reference: noon).map(\.bundleID) == ["com.a.A"])
        #expect(store.topApps(limit: 1, daysBack: 60, reference: noon).map(\.bundleID) == ["com.b.B"])
    }

    @Test func reloadReadsPersistedDaysAndPrunesBeyondRetention() {
        let url = makeStoreURL()
        var store = AppActivityUsageStore(fileURL: url)

        store.merge(["com.a.A": AppActivityUsage(seconds: 10, name: "A")], on: noon)
        store.merge(
            ["com.old.O": AppActivityUsage(seconds: 50, name: "Old")],
            on: noon.addingTimeInterval(-401 * 86_400)
        )

        let reloaded = AppActivityUsageStore(fileURL: url)
        let top = reloaded.topApps(limit: 10, daysBack: 364, reference: noon)
        #expect(top.map(\.bundleID) == ["com.a.A"])
    }
}
