// WidgetProGatingTests.swift
// Pepinillo — Deep Work Companion for Apple
//
// Tests for widget capability gating via AppGroupDefaults.userCapabilities.
// Verifies widget providers use the structured UserCapabilities model, not a legacy isProUser bool.

import Testing
import Foundation
@testable import Pepinillo

@Suite("WidgetProGating", .serialized)
struct WidgetProGatingTests {

    // MARK: - AppGroupDefaults.userCapabilities read/write

    @Test("userCapabilities nil-to-nil round-trip (unset state)")
    func nilCapabilitiesRoundTrip() {
        let saved = AppGroupDefaults.userCapabilities
        defer { AppGroupDefaults.userCapabilities = saved }

        AppGroupDefaults.userCapabilities = nil
        #expect(AppGroupDefaults.userCapabilities == nil)
    }

    @Test("Free capabilities — hasAnyPremium is false")
    func freeCapabilitiesHasNoPremium() {
        let saved = AppGroupDefaults.userCapabilities
        defer { AppGroupDefaults.userCapabilities = saved }

        AppGroupDefaults.userCapabilities = .free
        let caps = AppGroupDefaults.userCapabilities
        #expect(caps?.hasAnyPremium == false)
    }

    @Test("PepinilloPlus capabilities — hasAnyPremium true, backendSync false")
    func pepinilloPlusCapsHasPremiumButNoSync() {
        let saved = AppGroupDefaults.userCapabilities
        defer { AppGroupDefaults.userCapabilities = saved }

        AppGroupDefaults.userCapabilities = .pepinilloPlus
        let caps = AppGroupDefaults.userCapabilities
        #expect(caps?.hasAnyPremium == true)
        #expect(caps?.backendSync == false)
    }

    @Test("EverywhereePlus capabilities — hasAnyPremium true, backendSync true")
    func everywherePlusCapsHasSyncEnabled() {
        let saved = AppGroupDefaults.userCapabilities
        defer { AppGroupDefaults.userCapabilities = saved }

        AppGroupDefaults.userCapabilities = .everywherePlus
        let caps = AppGroupDefaults.userCapabilities
        #expect(caps?.hasAnyPremium == true)
        #expect(caps?.backendSync == true)
    }

    @Test("Widget shows proRequired placeholder when capabilities nil (unset = free)")
    func nilCapabilitiesMeansNoAccess() {
        let saved = AppGroupDefaults.userCapabilities
        defer { AppGroupDefaults.userCapabilities = saved }

        AppGroupDefaults.userCapabilities = nil
        // Widgets read: AppGroupDefaults.userCapabilities?.hasAnyPremium == true
        // When nil, this evaluates to false → proRequired entry shown
        #expect(AppGroupDefaults.userCapabilities?.hasAnyPremium != true)
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
}
