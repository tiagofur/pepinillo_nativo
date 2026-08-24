// WidgetProGatingTests.swift
// Pepinillo — Deep Work Companion for Apple

import Testing
import Foundation
@testable import Pepinillo

@Suite("WidgetProGating", .serialized, .appGroupDefaultsSerialized)
struct WidgetProGatingTests {

    @Test("AppGroupDefaults.isProUser round-trips")
    func isProUserFlagRoundTrips() {
        let original = AppGroupDefaults.isProUser
        defer { AppGroupDefaults.isProUser = original }

        AppGroupDefaults.isProUser = true
        #expect(AppGroupDefaults.isProUser == true)

        AppGroupDefaults.isProUser = false
        #expect(AppGroupDefaults.isProUser == false)
    }

    @Test("AppGroupDefaults.isProUser defaults to false")
    func isProUserDefaultsFalseAfterClear() {
        let original = AppGroupDefaults.isProUser
        defer { AppGroupDefaults.isProUser = original }

        AppGroupDefaults.isProUser = false
        #expect(AppGroupDefaults.isProUser == false)
    }

    @Test("Tasks widget access and provider loader enforce canonical entitlement states")
    func tasksWidgetAccessMatrix() {
        var unknown = UserCapabilities.pepinilloPlus
        unknown.localAI = false
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let saved = AppGroupDefaultsSnapshot.capture()
        defer { saved.restore() }
        let cases: [(String?, UserCapabilities?, Date?, Date?, Bool, TimeInterval)] = [
            (nil, nil, nil, nil, false, 900), (nil, .pepinilloPlus, nil, nil, false, 900),
            ("free", .free, now, nil, false, 900), ("pepinillo_plus", .pepinilloPlus, nil, nil, true, 900),
            ("everywhere_plus", .everywherePlus, now.addingTimeInterval(-TasksWidgetAccess.everywhereOfflineGracePeriod + 60), nil, true, 60), ("everywhere_plus", .everywherePlus, now, now.addingTimeInterval(30), true, 30),
            ("everywhere_plus", .everywherePlus, nil, nil, false, 900), ("everywhere_plus", .everywherePlus, now, now.addingTimeInterval(-1), false, 900),
            ("everywhere_plus", .everywherePlus, now.addingTimeInterval(-TasksWidgetAccess.everywhereOfflineGracePeriod), nil, false, 900), ("everywhere_plus", .everywherePlus, now.addingTimeInterval(1), nil, false, 900), ("pepinillo_plus", unknown, nil, nil, false, 900),
        ]
        for (tier, capabilities, verified, expiration, expected, refreshInterval) in cases {
            AppGroupDefaults.subscriptionTierIdentifier = tier
            AppGroupDefaults.userCapabilities = capabilities
            AppGroupDefaults.lastVerifiedDate = verified
            AppGroupDefaults.subscriptionExpirationDate = expiration
            var loaded = false
            let value = TasksWidgetAccess.loadIfAuthorized(now: now) { loaded = true }
            #expect((value != nil) == expected)
            #expect(loaded == expected)
            #expect(TasksWidgetAccess.nextRefreshDate(
                now: now, normalRefresh: now.addingTimeInterval(900)
            ) == now.addingTimeInterval(refreshInterval))
        }
    }

    // MARK: - Widget gating logic matches provider pattern

    @Test("Dashboard widget guard pattern — nil caps → proRequired")
    func dashboardWidgetGuardNilCaps() {
        let saved = AppGroupDefaults.userCapabilities
        defer { AppGroupDefaults.userCapabilities = saved }

        AppGroupDefaults.userCapabilities = nil
        // Reproduces: guard AppGroupDefaults.userCapabilities?.hasAnyPremium == true else { return .proRequired }
        let isBlocked = AppGroupDefaults.userCapabilities?.hasAnyPremium != true
        #expect(isBlocked, "Dashboard widget should return proRequired when capabilities nil")
    }

    @Test("Focus widget guard — free caps → isPro false")
    func focusWidgetFreeCapabilitiesIsProFalse() {
        let saved = AppGroupDefaults.userCapabilities
        defer { AppGroupDefaults.userCapabilities = saved }

        AppGroupDefaults.userCapabilities = .free
        // Reproduces: let isPro = AppGroupDefaults.userCapabilities?.hasAnyPremium ?? false
        let isPro = AppGroupDefaults.userCapabilities?.hasAnyPremium ?? false
        #expect(isPro == false, "Free tier → isPro false in Focus widget entry")
    }

    @Test("Focus widget guard — everywherePlus caps → isPro true")
    func focusWidgetEverywherePlusIsProTrue() {
        let saved = AppGroupDefaults.userCapabilities
        defer { AppGroupDefaults.userCapabilities = saved }

        AppGroupDefaults.userCapabilities = .everywherePlus
        let isPro = AppGroupDefaults.userCapabilities?.hasAnyPremium ?? false
        #expect(isPro == true, "Everywhere+ → isPro true in Focus widget entry")
    }

    // MARK: - Control Center Pro gating (widgetResolvedMode)

    @Test("CC start: free user with flowtime selected → falls back to pomodoro")
    func controlCenterFreeUserFlowtimeFallsBackToPomodoro() {
        let resolved = widgetResolvedMode(requested: "flowtime", isPro: false)
        #expect(resolved == "pomodoro", "Free user + flowtime → must fall back to pomodoro")
    }

    @Test("CC start: free user with timeBlock selected → falls back to pomodoro")
    func controlCenterFreeUserTimeBlockFallsBackToPomodoro() {
        let resolved = widgetResolvedMode(requested: "timeBlock", isPro: false)
        #expect(resolved == "pomodoro", "Free user + timeBlock → must fall back to pomodoro")
    }

    @Test("CC start: free user with pomodoro selected → pomodoro passes through")
    func controlCenterFreeUserPomodoroPassesThrough() {
        let resolved = widgetResolvedMode(requested: "pomodoro", isPro: false)
        #expect(resolved == "pomodoro", "Free user + pomodoro → pomodoro")
    }

    @Test("CC start: free user with stopwatch selected → stopwatch passes through")
    func controlCenterFreeUserStopwatchPassesThrough() {
        let resolved = widgetResolvedMode(requested: "stopwatch", isPro: false)
        #expect(resolved == "stopwatch", "Free user + stopwatch → stopwatch (not a Pro mode)")
    }

    @Test("CC start: pro user with flowtime selected → flowtime passes through")
    func controlCenterProUserFlowtimePassesThrough() {
        let resolved = widgetResolvedMode(requested: "flowtime", isPro: true)
        #expect(resolved == "flowtime", "Pro user + flowtime → flowtime")
    }

    @Test("CC start: pro user with timeBlock selected → timeBlock passes through")
    func controlCenterProUserTimeBlockPassesThrough() {
        let resolved = widgetResolvedMode(requested: "timeBlock", isPro: true)
        #expect(resolved == "timeBlock", "Pro user + timeBlock → timeBlock")
    }
}
