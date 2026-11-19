// OpenTaskIntentTests.swift
// Pepinillo — Deep Work Companion for Apple
//
// RED→GREEN tests for the Siri "open a task" App Intent (issue #900).
// The navigation itself rides the existing pepinillo://task/<id> deep-link
// pipeline (AppFeature .appURLReceived on iOS, PepinilloMacApp on Mac), so
// what is unit-tested here is the URL seam the intent hands to the platform.

import Testing
import Foundation
import AppIntents
@testable import Pepinillo

@Suite("OpenTaskIntent", .serialized, .appGroupDefaultsSerialized)
struct OpenTaskIntentTests {

    // MARK: - T3 (S3): deep-link URL seam

    @Test("deepLinkURL builds the pepinillo://task route for a task id")
    func deepLinkURLBuildsTaskRoute() {
        let id = UUID(uuidString: "6F3A1B2C-4D5E-4F60-8A1B-2C3D4E5F6071")!

        let url = TaskIntentService.deepLinkURL(for: id)

        #expect(url?.absoluteString == "pepinillo://task/6F3A1B2C-4D5E-4F60-8A1B-2C3D4E5F6071")
    }
}
