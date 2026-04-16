// SentryServiceTests.swift
// Pepinillo — Deep Work Companion for Apple
//
// Unit tests for SentryService DSN resolution — the one piece of Sentry
// integration we can exercise without a network. The SDK itself is trusted.

import Testing
import Foundation
@testable import Pepinillo

@Suite("SentryService")
struct SentryServiceTests {

    // MARK: - resolveDSN

    @Test("returns nil when SENTRY_DSN is missing")
    func missingDSNReturnsNil() {
        let bundle = StubBundle(info: [:])
        #expect(SentryService.resolveDSN(bundle: bundle) == nil)
    }

    @Test("returns nil when SENTRY_DSN is empty")
    func emptyDSNReturnsNil() {
        let bundle = StubBundle(info: ["SENTRY_DSN": ""])
        #expect(SentryService.resolveDSN(bundle: bundle) == nil)
    }

    @Test("returns nil when SENTRY_DSN is only whitespace")
    func whitespaceDSNReturnsNil() {
        let bundle = StubBundle(info: ["SENTRY_DSN": "   \n "])
        #expect(SentryService.resolveDSN(bundle: bundle) == nil)
    }

    @Test("returns nil when xcconfig substitution did not happen")
    func unsubstitutedDSNReturnsNil() {
        let bundle = StubBundle(info: ["SENTRY_DSN": "$(SENTRY_DSN)"])
        #expect(SentryService.resolveDSN(bundle: bundle) == nil)
    }

    @Test("returns nil in DEBUG builds without explicit opt-in", .enabled(if: isDebug))
    func debugDSNDisabledByDefault() {
        let bundle = StubBundle(info: ["SENTRY_DSN": "https://abc@sentry.io/123"])
        // No PEPINILLO_SENTRY_DEBUG env var in the test process
        #expect(SentryService.resolveDSN(bundle: bundle) == nil)
    }

    // MARK: - resolveEnvironment

    @Test("falls back to 'unknown' when APP_ENVIRONMENT missing")
    func defaultEnvironment() {
        let bundle = StubBundle(info: [:])
        #expect(SentryService.resolveEnvironment(bundle: bundle) == "unknown")
    }

    @Test("returns APP_ENVIRONMENT when present")
    func environmentFromInfo() {
        let bundle = StubBundle(info: ["APP_ENVIRONMENT": "production"])
        #expect(SentryService.resolveEnvironment(bundle: bundle) == "production")
    }

    @Test("treats empty APP_ENVIRONMENT as unknown")
    func emptyEnvironmentIsUnknown() {
        let bundle = StubBundle(info: ["APP_ENVIRONMENT": ""])
        #expect(SentryService.resolveEnvironment(bundle: bundle) == "unknown")
    }

    // MARK: - resolveReleaseName

    @Test("combines bundle identifier, version and build")
    func releaseName() {
        let bundle = StubBundle(
            info: [
                "CFBundleShortVersionString": "1.2.3",
                "CFBundleVersion": "42"
            ],
            identifier: "com.pepinillo.app"
        )
        #expect(SentryService.resolveReleaseName(bundle: bundle) == "com.pepinillo.app@1.2.3+42")
    }

    // MARK: - Helpers

    private static var isDebug: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }
}

// Lightweight Bundle stub. We subclass Bundle and override the two methods
// SentryService uses. Works on iOS and macOS alike.
private final class StubBundle: Bundle, @unchecked Sendable {
    private let info: [String: Any]
    private let identifier: String?

    init(info: [String: Any], identifier: String? = nil) {
        self.info = info
        self.identifier = identifier
        super.init(url: Bundle.main.bundleURL)!
    }

    override func object(forInfoDictionaryKey key: String) -> Any? {
        info[key]
    }

    override var bundleIdentifier: String? {
        identifier ?? super.bundleIdentifier
    }
}
