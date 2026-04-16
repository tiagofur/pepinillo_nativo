// AppConfigTests.swift
// Pepinillo — Deep Work Companion for Apple

import Testing
@testable import Pepinillo

@Suite("AppConfig")
struct AppConfigTests {

    @Test("aiInsightsEnabled defaults to false for v1")
    func aiInsightsDisabledByDefault() {
        #expect(AppConfig.aiInsightsEnabled == false)
    }
}
