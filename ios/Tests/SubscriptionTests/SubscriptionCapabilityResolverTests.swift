// SubscriptionCapabilityResolverTests.swift
// Pepinillo — Deep Work Companion for Apple

import Foundation
import Testing
@testable import Pepinillo

@Suite("SubscriptionCapabilityResolver")
struct SubscriptionCapabilityResolverTests {

    @Test("Active Everywhere+ maps to everywherePlus")
    func activeEverywhere() {
        let expiry = Date.now.addingTimeInterval(86_400)
        let state = SubscriptionCapabilityResolver.resolve(
            everywhere: ResolvedEntitlement(isActive: true, expirationDate: expiry),
            pepinilloPlus: nil,
            legacyPremium: nil,
            legacyPro: nil,
            activeSubscriptionID: "monthly",
            purchasedProductID: nil
        )
        #expect(state.capabilities == .everywherePlus)
        #expect(state.expirationDate == expiry)
    }

    @Test("Expired Everywhere+ with isActive false is free")
    func expiredEverywhere() {
        let state = SubscriptionCapabilityResolver.resolve(
            everywhere: ResolvedEntitlement(isActive: false, expirationDate: Date.now.addingTimeInterval(-86_400)),
            pepinilloPlus: nil,
            legacyPremium: nil,
            legacyPro: nil,
            activeSubscriptionID: nil,
            purchasedProductID: nil
        )
        #expect(state == .free)
    }

    @Test("Active Pepinillo+ one-time has no expiration")
    func activePepinilloPlus() {
        let state = SubscriptionCapabilityResolver.resolve(
            everywhere: nil,
            pepinilloPlus: ResolvedEntitlement(isActive: true, expirationDate: nil),
            legacyPremium: nil,
            legacyPro: nil,
            activeSubscriptionID: nil,
            purchasedProductID: "lifetime"
        )
        #expect(state.capabilities == .pepinilloPlus)
        #expect(state.expirationDate == nil)
    }

    @Test("Legacy lifetime pro maps to pepinilloPlus")
    func legacyLifetime() {
        let state = SubscriptionCapabilityResolver.resolve(
            everywhere: nil,
            pepinilloPlus: nil,
            legacyPremium: ResolvedEntitlement(isActive: true, expirationDate: nil),
            legacyPro: nil,
            activeSubscriptionID: nil,
            purchasedProductID: "lifetime"
        )
        #expect(state.capabilities == .pepinilloPlus)
    }

    @Test("Legacy subscription maps to everywherePlus while active")
    func legacySubscription() {
        let expiry = Date.now.addingTimeInterval(86_400)
        let state = SubscriptionCapabilityResolver.resolve(
            everywhere: nil,
            pepinilloPlus: nil,
            legacyPremium: nil,
            legacyPro: ResolvedEntitlement(isActive: true, expirationDate: expiry),
            activeSubscriptionID: "annual",
            purchasedProductID: nil
        )
        #expect(state.capabilities == .everywherePlus)
        #expect(state.expirationDate == expiry)
    }

    @Test("Billing grace: isActive true past nominal expiry still grants Pro")
    func billingGraceTrustsIsActive() {
        let pastExpiry = Date.now.addingTimeInterval(-5 * 86_400)
        let state = SubscriptionCapabilityResolver.resolve(
            everywhere: ResolvedEntitlement(isActive: true, expirationDate: pastExpiry),
            pepinilloPlus: nil,
            legacyPremium: nil,
            legacyPro: nil,
            activeSubscriptionID: "monthly",
            purchasedProductID: nil
        )
        #expect(state.capabilities == .everywherePlus)
    }
}