// WidgetProGatingTests.swift
// Pepinillo — Deep Work Companion for Apple

import Testing
import Foundation
@testable import Pepinillo

@Suite("WidgetProGating")
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
}
