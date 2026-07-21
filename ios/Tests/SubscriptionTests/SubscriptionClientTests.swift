// SubscriptionClientTests.swift
// Pepinillo — Deep Work Companion for Apple

import Foundation
import Testing
@testable import Pepinillo

@Suite("SubscriptionClientTests")
struct SubscriptionClientTests {

    struct DummyError: Error, Equatable {}

    @Test("Non-network error is always thrown")
    func nonNetworkError() {
        let error = DummyError()
        
        #expect(throws: DummyError.self) {
            try SubscriptionOfflineGraceChecker.check(
                error: error,
                cachedCapabilities: .everywherePlus,
                lastVerifiedDate: Date()
            )
        }
    }

    @Test("Everywhere+ user within 7-day grace period is active")
    func everywhereWithinGracePeriod() throws {
        let networkError = URLError(.notConnectedToInternet)
        let lastVerified = Date().addingTimeInterval(-5 * 24 * 3600) // 5 days ago
        
        let state = try SubscriptionOfflineGraceChecker.check(
            error: networkError,
            cachedCapabilities: .everywherePlus,
            lastVerifiedDate: lastVerified
        )
        
        #expect(state.capabilities == .everywherePlus)
    }

    @Test("Everywhere+ user past 7-day grace period throws network error")
    func everywherePastGracePeriod() {
        let networkError = URLError(.notConnectedToInternet)
        let lastVerified = Date().addingTimeInterval(-8 * 24 * 3600) // 8 days ago
        
        #expect(throws: URLError.self) {
            try SubscriptionOfflineGraceChecker.check(
                error: networkError,
                cachedCapabilities: .everywherePlus,
                lastVerifiedDate: lastVerified
            )
        }
    }

    @Test("Pepinillo+ lifetime user offline remains active indefinitely")
    func pepinilloLifetimeOffline() throws {
        let networkError = URLError(.notConnectedToInternet)
        
        let state = try SubscriptionOfflineGraceChecker.check(
            error: networkError,
            cachedCapabilities: .pepinilloPlus,
            lastVerifiedDate: nil
        )
        
        #expect(state.capabilities == .pepinilloPlus)
    }

    @Test("SubscriptionClient checkEntitlement propagates throwing closures")
    func subscriptionClientCheckEntitlementThrows() async {
        var client = SubscriptionClient()
        client.checkEntitlement = { throw DummyError() }
        
        await #expect(throws: DummyError.self) {
            try await client.checkEntitlement()
        }
    }

    @Test("SubscriptionClient restorePurchases propagates throwing closures")
    func subscriptionClientRestorePurchasesThrows() async {
        var client = SubscriptionClient()
        client.restorePurchases = { throw DummyError() }
        
        await #expect(throws: DummyError.self) {
            try await client.restorePurchases()
        }
    }

    @Test("SubscriptionClient logIn propagates throwing closures")
    func subscriptionClientLogInThrows() async {
        var client = SubscriptionClient()
        client.logIn = { _ in throw DummyError() }
        
        await #expect(throws: DummyError.self) {
            try await client.logIn("user-123")
        }
    }

    @Test("SubscriptionClient.live fetchProducts defaults to empty when unconfigured or failing")
    func fetchProductsDefaultsToEmpty() async {
        let client = SubscriptionClient.live
        let products = await client.fetchProducts()
        #expect(products.isEmpty)
    }

    @Test("SubscriptionClient.live isPurchasesAvailable returns false when unconfigured")
    func isPurchasesAvailableReturnsFalseWhenUnconfigured() async {
        let client = SubscriptionClient.live
        let available = await client.isPurchasesAvailable()
        #expect(!available)
    }
}
