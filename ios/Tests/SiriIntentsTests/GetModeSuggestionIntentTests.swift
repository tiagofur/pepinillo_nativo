// GetModeSuggestionIntentTests.swift
// Pepinillo — Deep Work Companion for Apple

import Testing
import AppIntents
import Foundation
@testable import Pepinillo

@Suite("GetModeSuggestionIntent")
struct GetModeSuggestionIntentTests {

    @Test("perform does not crash when task parameter is nil")
    func performWithNilTaskDoesNotCrash() async throws {
        var intent = GetModeSuggestionIntent()
        intent.task = nil

        _ = try await intent.perform()
    }
}
