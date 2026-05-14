// HealthClient.swift
// Pepinillo — Deep Work Companion for Apple
//
// TCA Dependency Client wrapping HealthKit (HKHealthStore).
// Logs completed focus sessions as Mindful Minutes in Apple Health.

import Foundation
import ComposableArchitecture
#if canImport(HealthKit) && !os(macOS)
import HealthKit
#endif

@DependencyClient
struct HealthClient: Sendable {
    /// Request authorization to write mindful session samples.
    var requestAuthorization: @Sendable () async throws -> Bool = { false }

    /// Check whether the user has granted write access for mindful sessions.
    var isAuthorized: @Sendable () -> Bool = { false }

    /// Log a completed focus session as a mindful session in Apple Health.
    var logMindfulMinutes: @Sendable (_ start: Date, _ end: Date) async throws -> Void
}

extension HealthClient: DependencyKey {
    static let liveValue: HealthClient = {
#if canImport(HealthKit) && !os(macOS)
        let store = HKHealthStore()
        let mindfulType = HKCategoryType(.mindfulSession)

        return HealthClient(
            requestAuthorization: {
                guard HKHealthStore.isHealthDataAvailable() else { return false }
                try await store.requestAuthorization(toShare: [mindfulType], read: [])
                return store.authorizationStatus(for: mindfulType) == .sharingAuthorized
            },
            isAuthorized: {
                guard HKHealthStore.isHealthDataAvailable() else { return false }
                return store.authorizationStatus(for: mindfulType) == .sharingAuthorized
            },
            logMindfulMinutes: { start, end in
                guard HKHealthStore.isHealthDataAvailable() else { return }
                let sample = HKCategorySample(
                    type: mindfulType,
                    value: HKCategoryValue.notApplicable.rawValue,
                    start: start,
                    end: end
                )
                try await store.save(sample)
            }
        )
#else
        return HealthClient()
#endif
    }()

    /// Noop fallback for tests and previews.
    static let testValue = HealthClient()
}

extension DependencyValues {
    var healthClient: HealthClient {
        get { self[HealthClient.self] }
        set { self[HealthClient.self] = newValue }
    }
}
