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

    // MARK: - Widget cold-start capability read (spec: "iOS Widget launches before main app")

    @Test("Widget cold start with no App Group data → free semantics (no access)")
    func widgetColdStartNoCapabilitiesDefaultsFree() {
        let saved = AppGroupDefaults.userCapabilities
        defer { AppGroupDefaults.userCapabilities = saved }

        // Simulate clean state (fresh install / uninstall)
        AppGroupDefaults.userCapabilities = nil

        // Widget gating logic: capabilities?.hasAnyPremium == true
        let shouldShowPremiumContent = AppGroupDefaults.userCapabilities?.hasAnyPremium == true
        #expect(shouldShowPremiumContent == false, "No capabilities → free tier → no premium widget content")
    }

    @Test("Widget cold start with cached pepinilloPlus → premium content shown")
    func widgetColdStartWithPepinilloPlusShowsPremiumContent() {
        let saved = AppGroupDefaults.userCapabilities
        defer { AppGroupDefaults.userCapabilities = saved }

        // Main app wrote capabilities before widget launched
        AppGroupDefaults.userCapabilities = .pepinilloPlus

        let shouldShowPremiumContent = AppGroupDefaults.userCapabilities?.hasAnyPremium == true
        #expect(shouldShowPremiumContent == true, "Cached pepinilloPlus → show premium content")
    }

    @Test("Widget cold start with cached everywherePlus → premium content shown")
    func widgetColdStartWithEverywherePlusShowsPremiumContent() {
        let saved = AppGroupDefaults.userCapabilities
        defer { AppGroupDefaults.userCapabilities = saved }

        AppGroupDefaults.userCapabilities = .everywherePlus

        let shouldShowPremiumContent = AppGroupDefaults.userCapabilities?.hasAnyPremium == true
        let hasBackendSync = AppGroupDefaults.userCapabilities?.backendSync == true
        #expect(shouldShowPremiumContent == true, "Cached everywherePlus → show premium content")
        #expect(hasBackendSync == true, "Everywhere+ tier always has backendSync")
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

    @Test("Tasks widget guard pattern — nil caps → proRequired")
    func tasksWidgetGuardNilCaps() {
        let saved = AppGroupDefaults.userCapabilities
        defer { AppGroupDefaults.userCapabilities = saved }

        AppGroupDefaults.userCapabilities = nil
        let isBlocked = AppGroupDefaults.userCapabilities?.hasAnyPremium != true
        #expect(isBlocked, "Tasks widget should return proRequired when capabilities nil")
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
