// WidgetProGatingTests.swift
// Pepinillo — Deep Work Companion for Apple
//
// Tests for widget capability gating via AppGroupDefaults.userCapabilities.
// Replaces legacy isProUser bool tests with the structured UserCapabilities model.

import Testing
import Foundation
@testable import Pepinillo

@Suite("WidgetProGating")
struct WidgetProGatingTests {

    @Test("userCapabilities nil-to-nil round-trip (unset state)")
    func nilCapabilitiesRoundTrip() {
        let saved = AppGroupDefaults.userCapabilities
        defer { AppGroupDefaults.userCapabilities = saved }

        AppGroupDefaults.userCapabilities = nil
        #expect(AppGroupDefaults.userCapabilities == nil)
    }

    @Test("Free capabilities — hasAnyPremium is false")
    func freeCapabilitiesHasNoPermium() {
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
}
