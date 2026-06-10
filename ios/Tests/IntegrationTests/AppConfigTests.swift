// AppConfigTests.swift
// Pepinillo — Deep Work Companion for Apple

import Testing
@testable import Pepinillo

@Suite("AppConfig")
struct AppConfigTests {

    @Test("aiInsightsEnabled is true — AI Reports feature is enabled")
    func aiInsightsEnabled() {
        #expect(AppConfig.aiInsightsEnabled == true)
    }
}
