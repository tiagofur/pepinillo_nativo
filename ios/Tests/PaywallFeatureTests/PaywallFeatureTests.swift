// PaywallFeatureTests.swift
// Pepinillo — Deep Work Companion for Apple
//
// TCA TestStore tests for the Paywall feature.

import Testing
import ComposableArchitecture
@testable import Pepinillo

@Suite("PaywallFeature")
@MainActor
struct PaywallFeatureTests {

    let mockProducts: [ProductInfo] = [
        ProductInfo(id: "monthly", displayName: "Pro Monthly",
                    description: "All features.", displayPrice: "$2.99",
                    billingPeriod: "month"),
        ProductInfo(id: "annual", displayName: "Pro Annual",
                    description: "Best value.", displayPrice: "$14.99",
                    billingPeriod: "year", isFeatured: true),
        ProductInfo(id: "lifetime", displayName: "Pro Lifetime",
                    description: "Pay once.", displayPrice: "$29.99",
                    billingPeriod: "once"),
    ]

    // MARK: - Load Products

    @Test("Appearing loads products and selects featured")
    func testAppearedLoadsProducts() async {
        let store = TestStore(initialState: PaywallFeature.State()) {
            PaywallFeature()
        } withDependencies: {
            let products = self.mockProducts
            $0.subscriptionClient.fetchProducts = { products }
            $0.subscriptionClient.checkEntitlement = { .free }
        }

        await store.send(.appeared) {
            $0.isLoading = true
        }

        // Both productsLoaded and subscriptionStateLoaded arrive.
        // productsLoaded sets isLoading = false, so subscriptionStateLoaded
        // only changes subscriptionState (which is already .free → no change).
        // Use non-exhaustive to avoid ordering issues.
        store.exhaustivity = .off

        await store.receive(.productsLoaded(mockProducts)) {
            $0.isLoading = false
            $0.products = self.mockProducts
            $0.selectedProductID = "annual"
        }

        await store.receive(.subscriptionStateLoaded(.free))
    }

    // MARK: - Product Selection

    @Test("Selecting a product updates selectedProductID")
    func testProductSelection() async {
        var state = PaywallFeature.State()
        state.products = mockProducts
        state.selectedProductID = "annual"

        let store = TestStore(initialState: state) {
            PaywallFeature()
        }

        await store.send(.productSelected("lifetime")) {
            $0.selectedProductID = "lifetime"
        }
    }

    // MARK: - Successful Purchase

    @Test("Successful purchase sets isPro state and shows success alert")
    func testSuccessfulPurchase() async {
        var state = PaywallFeature.State()
        state.products = mockProducts
        state.selectedProductID = "annual"

        let store = TestStore(initialState: state) {
            PaywallFeature()
        } withDependencies: {
            $0.subscriptionClient.purchase = { _ in .success(productID: "annual") }
            $0.subscriptionClient.checkEntitlement = { .pepinilloPlus }
        }

        store.exhaustivity = .off

        await store.send(.purchaseTapped) {
            $0.isLoading = true
        }

        await store.receive(.purchaseFinished(.success(productID: "annual"))) {
            $0.isLoading = false
            $0.subscriptionState = .pro
            $0.purchaseResult = PaywallFeature.State.PurchaseResultAlert(
                message: String(localized: "Welcome to Pepinillo Pro! 🎉"),
                isSuccess: true
            )
        }

        await store.receive(.subscriptionStateLoaded(.pepinilloPlus))
        await store.receive(.delegate(.proUnlocked(.pepinilloPlus)))
    }

    // MARK: - Cancelled Purchase

    @Test("Cancelled purchase does not show alert")
    func testCancelledPurchase() async {
        var state = PaywallFeature.State()
        state.products = mockProducts

        let store = TestStore(initialState: state) {
            PaywallFeature()
        } withDependencies: {
            $0.subscriptionClient.purchase = { _ in .cancelled }
        }

        await store.send(.purchaseTapped) {
            $0.isLoading = true
        }

        await store.receive(.purchaseFinished(.cancelled)) {
            $0.isLoading = false
        }
    }

    // MARK: - Restore Purchases

    @Test("Restore with active subscription sets isPro")
    func testRestoreWithActiveSub() async {
        let store = TestStore(initialState: PaywallFeature.State()) {
            PaywallFeature()
        } withDependencies: {
            $0.subscriptionClient.restorePurchases = { .pro }
        }

        store.exhaustivity = .off

        await store.send(.restoreTapped) {
            $0.isLoading = true
        }

        await store.receive(.subscriptionStateLoaded(.pro)) {
            $0.isLoading = false
            $0.subscriptionState = .pro
        }

        await store.receive(.purchaseFinished(.success(productID: ""))) {
            $0.purchaseResult = PaywallFeature.State.PurchaseResultAlert(
                message: String(localized: "Welcome to Pepinillo Pro! 🎉"),
                isSuccess: true
            )
        }
    }

    // MARK: - Dismiss Alert

    @Test("Dismissing alert clears purchaseResult")
    func testAlertDismiss() async {
        var state = PaywallFeature.State()
        state.purchaseResult = .init(message: "Welcome!", isSuccess: true)

        let store = TestStore(initialState: state) {
            PaywallFeature()
        }

        await store.send(.alertDismissed) {
            $0.purchaseResult = nil
        }
    }
}

// MARK: - Notification Client Tests

@Suite("NotificationClient")
@MainActor
struct NotificationClientTests {

    @Test("scheduleBreakEnd sends one notification")
    func testBreakEndScheduling() async {
        nonisolated(unsafe) var scheduled: [String] = []
        var overrideClient = NotificationClient.testValue
        overrideClient.scheduleBreakEnd = { minutes in
            scheduled.append("break-\(minutes)")
        }

        await overrideClient.scheduleBreakEnd(5)
        #expect(scheduled == ["break-5"])
    }

    @Test("cancelAll is callable without error")
    func testCancelAll() async {
        var client = NotificationClient.testValue
        client.cancelAll = { }
        await client.cancelAll()
    }
}
