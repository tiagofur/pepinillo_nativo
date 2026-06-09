// SentryService.swift
// Pepinillo — Deep Work Companion for Apple
//
// Thin wrapper around sentry-cocoa so the rest of the app never imports Sentry
// directly. Responsibilities:
//   1. Read SENTRY_DSN from Info.plist (plumbed in from xcconfig).
//   2. Decide whether Sentry should be enabled for this build.
//   3. Configure privacy-preserving defaults (no screenshots, no PII).
//
// Enable/disable rules:
//   • Empty/missing DSN            → disabled (no-op).
//   • Still containing the literal token "$(SENTRY_DSN)" → disabled (means the
//     xcconfig substitution did not happen — usually a local/dev build).
//   • #if DEBUG                    → disabled by default so development runs
//     do not spam the live Sentry project.
//   • Anything else (Staging/Release with a real DSN) → enabled.

import Foundation
import Sentry

protocol BundleInfoProviding {
    var bundleIdentifier: String? { get }
    func object(forInfoDictionaryKey key: String) -> Any?
}

extension Bundle: BundleInfoProviding {}

enum SentryService {

    /// Capture an error in Sentry with an optional human-readable context string.
    /// No-op if Sentry was not started (e.g. missing DSN, DEBUG build).
    static func captureError(_ error: Error, context: String? = nil) {
        let event = Event(level: .error)
        event.message = SentryMessage(formatted: context ?? error.localizedDescription)
        event.exceptions = [Exception(value: error.localizedDescription, type: String(describing: type(of: error)))]
        SentrySDK.capture(event: event)
    }

    /// Start Sentry if a DSN is available and the build isn't excluded.
    /// Safe to call multiple times — the SDK itself guards against double init.
    static func start(bundle: Bundle = .main) {
        guard let dsn = resolveDSN(bundle: bundle) else { return }

        SentrySDK.start { options in
            options.dsn = dsn
            options.environment = resolveEnvironment(bundle: bundle)
            options.releaseName = resolveReleaseName(bundle: bundle)

            // Automatic performance tracing for UIViewController / SwiftUI
            // navigation. Low sample rate to keep noise and quota manageable.
            options.enableAutoPerformanceTracing = true
            options.tracesSampleRate = 0.1

            // Privacy-first defaults.
            #if !os(macOS)
            options.attachScreenshot = false
            options.attachViewHierarchy = false
            #endif
            options.sendDefaultPii = false

            // App hangs & slow frames tracking (cheap, high signal).
            options.enableAppHangTracking = true
            options.enableAutoBreadcrumbTracking = true
        }
    }

    // MARK: - Resolution helpers (internal for testability)

    static func resolveDSN(bundle: BundleInfoProviding) -> String? {
        guard let raw = bundle.object(forInfoDictionaryKey: "SENTRY_DSN") as? String else {
            return nil
        }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        // Substitution failure — xcconfig variable was not replaced.
        if trimmed.contains("$(SENTRY_DSN)") { return nil }

        #if DEBUG
        // Don't report debug builds unless the developer explicitly opted in
        // by setting PEPINILLO_SENTRY_DEBUG=1 in the scheme environment.
        if ProcessInfo.processInfo.environment["PEPINILLO_SENTRY_DEBUG"] != "1" {
            return nil
        }
        #endif

        return trimmed
    }

    static func resolveEnvironment(bundle: BundleInfoProviding) -> String {
        (bundle.object(forInfoDictionaryKey: "APP_ENVIRONMENT") as? String)
            .flatMap { $0.isEmpty ? nil : $0 }
            ?? "unknown"
    }

    static func resolveReleaseName(bundle: BundleInfoProviding) -> String {
        let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0"
        let build = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
        let identifier = bundle.bundleIdentifier ?? "com.pepinillo.app"
        return "\(identifier)@\(version)+\(build)"
    }
}
