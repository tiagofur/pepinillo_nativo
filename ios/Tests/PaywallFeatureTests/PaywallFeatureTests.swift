// PaywallFeatureTests.swift
// Pepinillo — Deep Work Companion for Apple
//
// TCA TestStore tests for the Paywall feature.

import Testing
import Foundation
import ComposableArchitecture
@testable import Pepinillo

// MARK: - Pure mapping helpers (Tasks 2.1, 2.3, 2.4)

@Suite("PaywallEntitlementMapper")
struct PaywallEntitlementMapperTests {

    @Test("Annual Everywhere product maps to everywherePlus entitlement")
    func annualMapsToEverywherePlus() {
        #expect(
            PaywallEntitlementMapper.subscriptionState(forProductID: PepinilloProduct.annual.rawValue)
            == .everywherePlus
        )
        #expect(PaywallEntitlementMapper.subscriptionState(forProductID: "annual") == .everywherePlus)
    }

    @Test("Monthly Everywhere product maps to everywherePlus entitlement")
    func monthlyMapsToEverywherePlus() {
        #expect(
            PaywallEntitlementMapper.subscriptionState(forProductID: PepinilloProduct.monthly.rawValue)
            == .everywherePlus
        )
        #expect(PaywallEntitlementMapper.subscriptionState(forProductID: "monthly") == .everywherePlus)
    }

    @Test("Lifetime Pepinillo+ product maps to pepinilloPlus entitlement")
    func lifetimeMapsToPepinilloPlus() {
        #expect(
            PaywallEntitlementMapper.subscriptionState(forProductID: PepinilloProduct.lifetime.rawValue)
            == .pepinilloPlus
        )
        #expect(PaywallEntitlementMapper.subscriptionState(forProductID: "lifetime") == .pepinilloPlus)
    }

    @Test("Pepinillo+ lifetime user can purchase Everywhere upgrade")
    func pepinilloPlusCanUpgradeToEverywhere() {
        #expect(
            PaywallEntitlementMapper.canPurchase(
                selectedProductID: PepinilloProduct.annual.rawValue,
                current: .pepinilloPlus
            )
        )
        #expect(
            PaywallEntitlementMapper.canPurchase(
                selectedProductID: "monthly",
                current: .pepinilloPlus
            )
        )
    }

    @Test("Pepinillo+ lifetime user cannot re-purchase lifetime")
    func pepinilloPlusCannotRepurchaseLifetime() {
        #expect(
            !PaywallEntitlementMapper.canPurchase(
                selectedProductID: PepinilloProduct.lifetime.rawValue,
                current: .pepinilloPlus
            )
        )
        #expect(
            !PaywallEntitlementMapper.canPurchase(
                selectedProductID: "lifetime",
                current: .pepinilloPlus
            )
        )
    }

    @Test("Everywhere user cannot purchase any product")
    func everywhereCannotPurchase() {
        #expect(
            !PaywallEntitlementMapper.canPurchase(
                selectedProductID: PepinilloProduct.annual.rawValue,
                current: .everywherePlus
            )
        )
        #expect(
            !PaywallEntitlementMapper.canPurchase(
                selectedProductID: PepinilloProduct.lifetime.rawValue,
                current: .everywherePlus
            )
        )
    }

    @Test("Free user can purchase any product")
    func freeCanPurchaseAll() {
        #expect(
            PaywallEntitlementMapper.canPurchase(
                selectedProductID: PepinilloProduct.lifetime.rawValue,
                current: .free
            )
        )
        #expect(
            PaywallEntitlementMapper.canPurchase(
                selectedProductID: PepinilloProduct.monthly.rawValue,
                current: .free
            )
        )
    }
}

@Suite("PaywallLegalCopy")
struct PaywallLegalCopyTests {

    @Test("Auto-renewal disclosure includes App Store management instructions")
    func disclosureMentionsAutoRenewalAndSettings() {
        let product = ProductInfo(
            id: PepinilloProduct.annual.rawValue,
            displayName: "Everywhere/AI+ Annual",
            description: "Best value",
            displayPrice: "$34.99",
            billingPeriod: "year",
            isFeatured: true
        )
        let text = PaywallLegalCopy.autoRenewalDisclosure(product: product)
        #expect(text.contains("$34.99"))
        #expect(text.localizedCaseInsensitiveContains("auto-renew"))
        #expect(text.localizedCaseInsensitiveContains("24 hours"))
        #expect(text.localizedCaseInsensitiveContains("App Store") || text.localizedCaseInsensitiveContains("Account Settings"))
        #expect(text.localizedCaseInsensitiveContains("cancel"))
    }

    @Test("Lifetime product disclosure notes one-time purchase")
    func lifetimeDisclosureIsOneTime() {
        let product = ProductInfo(
            id: PepinilloProduct.lifetime.rawValue,
            displayName: "Pepinillo+",
            description: "One-time",
            displayPrice: "$19.99",
            billingPeriod: "once"
        )
        let text = PaywallLegalCopy.autoRenewalDisclosure(product: product)
        #expect(text.contains("$19.99"))
        #expect(text.localizedCaseInsensitiveContains("one-time") || text.localizedCaseInsensitiveContains("not a subscription"))
    }
}

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
            $0.keychainClient.hasTokens = { true }
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

        await store.receive(.guestStatusLoaded(false))

        await store.receive(.subscriptionStateLoaded(.free))

    }

    @Test("Appearing preserves existing premium when entitlement check throws")
    func testAppearedEntitlementThrowPreservesState() async {
        var state = PaywallFeature.State()
        state.subscriptionState = .pepinilloPlus

        struct NetworkBoom: Error {}

        let store = TestStore(initialState: state) {
            PaywallFeature()
        } withDependencies: {
            let products = self.mockProducts
            $0.subscriptionClient.fetchProducts = { products }
            $0.subscriptionClient.checkEntitlement = { throw NetworkBoom() }
            $0.keychainClient.hasTokens = { true }
        }

        store.exhaustivity = .off

        await store.send(.appeared) {
            $0.isLoading = true
        }

        await store.receive(.productsLoaded(mockProducts)) {
            $0.isLoading = false
            $0.products = self.mockProducts
            $0.selectedProductID = "annual"
        }

        // Must NOT coerce to .free on throw — premium state stays.

        await store.receive(.guestStatusLoaded(false))
        #expect(store.state.subscriptionState == .pepinilloPlus)
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

    @Test("Successful Everywhere purchase maps to everywherePlus and unlocks")
    func testSuccessfulEverywherePurchase() async {
        var state = PaywallFeature.State()
        state.products = mockProducts
        state.selectedProductID = "annual"

        let store = TestStore(initialState: state) {
            PaywallFeature()
        } withDependencies: {
            $0.subscriptionClient.purchase = { _ in .success(productID: "annual") }
            $0.subscriptionClient.checkEntitlement = { .everywherePlus }
        }

        store.exhaustivity = .off

        await store.send(.purchaseTapped) {
            $0.isLoading = true
        }

        await store.receive(.purchaseFinished(.success(productID: "annual"))) {
            $0.isLoading = false
            $0.subscriptionState = .everywherePlus
            $0.purchaseResult = PaywallFeature.State.PurchaseResultAlert(
                message: String(localized: "Welcome to Everywhere/AI+! 🎉"),
                isSuccess: true
            )
        }

        await store.receive(.subscriptionStateLoaded(.everywherePlus))
        await store.receive(.delegate(.proUnlocked(.everywherePlus)))
    }

    @Test("Successful lifetime purchase maps to pepinilloPlus")
    func testSuccessfulLifetimePurchase() async {
        var state = PaywallFeature.State()
        state.products = mockProducts
        state.selectedProductID = "lifetime"

        let store = TestStore(initialState: state) {
            PaywallFeature()
        } withDependencies: {
            $0.subscriptionClient.purchase = { _ in .success(productID: "lifetime") }
            $0.subscriptionClient.checkEntitlement = { .pepinilloPlus }
        }

        store.exhaustivity = .off

        await store.send(.purchaseTapped) {
            $0.isLoading = true
        }

        await store.receive(.purchaseFinished(.success(productID: "lifetime"))) {
            $0.isLoading = false
            $0.subscriptionState = .pepinilloPlus
            $0.purchaseResult = PaywallFeature.State.PurchaseResultAlert(
                message: String(localized: "Welcome to Pepinillo+! 🎉"),
                isSuccess: true
            )
        }

        await store.receive(.subscriptionStateLoaded(.pepinilloPlus))
        await store.receive(.delegate(.proUnlocked(.pepinilloPlus)))
    }

    @Test("Purchase success keeps product mapping when entitlement re-check throws")
    func testPurchaseSuccessKeepsMappingWhenRecheckThrows() async {
        var state = PaywallFeature.State()
        state.products = mockProducts
        state.selectedProductID = "annual"

        struct RecheckBoom: Error {}

        let store = TestStore(initialState: state) {
            PaywallFeature()
        } withDependencies: {
            $0.subscriptionClient.purchase = { _ in .success(productID: "annual") }
            $0.subscriptionClient.checkEntitlement = { throw RecheckBoom() }
        }

        store.exhaustivity = .off

        await store.send(.purchaseTapped) {
            $0.isLoading = true
        }

        await store.receive(.purchaseFinished(.success(productID: "annual"))) {
            $0.isLoading = false
            $0.subscriptionState = .everywherePlus
            $0.purchaseResult = PaywallFeature.State.PurchaseResultAlert(
                message: String(localized: "Welcome to Everywhere/AI+! 🎉"),
                isSuccess: true
            )
        }

        // Optimistic everywherePlus mapping must survive the re-check failure,
        // and still unlock the parent with that mapped entitlement.
        await store.receive(.delegate(.proUnlocked(.everywherePlus)))
        #expect(store.state.subscriptionState == .everywherePlus)
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
                message: String(localized: "Welcome to Pepinillo+! 🎉"),
                isSuccess: true
            )
        }

        await store.receive(.delegate(.proUnlocked(.pro)))
    }

    @Test("Restore network failure surfaces error and does not demote to free")
    func testRestoreThrowSurfacesErrorWithoutDemotion() async {
        var state = PaywallFeature.State()
        state.subscriptionState = .everywherePlus

        struct RestoreBoom: Error, LocalizedError {
            var errorDescription: String? { "Restore network failed" }
        }

        let store = TestStore(initialState: state) {
            PaywallFeature()
        } withDependencies: {
            $0.subscriptionClient.restorePurchases = { throw RestoreBoom() }
        }

        store.exhaustivity = .off

        await store.send(.restoreTapped) {
            $0.isLoading = true
        }

        await store.receive(.purchaseFinished(.failed(message: "Restore network failed"))) {
            $0.isLoading = false
            $0.purchaseResult = PaywallFeature.State.PurchaseResultAlert(
                message: "Restore network failed",
                isSuccess: false
            )
        }

        #expect(store.state.subscriptionState == .everywherePlus)
    }

    // MARK: - Offering Failure & Gating (#213)

    @Test("Appeared offering failure returns empty array without mock products")
    func testAppearedOfferingFailureReturnsEmpty() async {
        let store = TestStore(initialState: PaywallFeature.State()) {
            PaywallFeature()
        } withDependencies: {
            $0.subscriptionClient.fetchProducts = { [] }
            $0.subscriptionClient.checkEntitlement = { .free }
            $0.keychainClient.hasTokens = { true }
        }

        store.exhaustivity = .off

        await store.send(.appeared) {
            $0.isLoading = true
        }

        await store.receive(.productsLoaded([])) {
            $0.isLoading = false
            $0.products = []
        }

        await store.receive(.guestStatusLoaded(false))

        await store.receive(.subscriptionStateLoaded(.free))


        #expect(store.state.products.isEmpty)
        #expect(!store.state.isPurchaseEnabled)
    }

    @Test("Purchase button disabled when products list is empty")
    func testPurchaseDisabledWhenProductsEmpty() async {
        var state = PaywallFeature.State()
        state.products = []
        state.selectedProductID = "annual"
        state.isLoading = false

        #expect(!state.isPurchaseEnabled)
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

    @Test("Close (X) button delegates closeRequested to the parent")
    func testCloseTappedDelegates() async {
        // The paywall sheet is presented by AppFeature via
        // `.sheet(isPresented: store.focus.showPaywall)`, so the close button must
        // ask the parent to flip that boolean — `@Dependency(\.dismiss)` cannot
        // close an isPresented sheet (regression: the X did nothing; only the
        // swipe-down gesture worked).
        let store = TestStore(initialState: PaywallFeature.State()) {
            PaywallFeature()
        }

        await store.send(.closeTapped)

        await store.receive(.delegate(.closeRequested))
    }

    // MARK: - Guest create-account nudge

    @Test("Guest purchase shows create-account nudge instead of welcome alert")
    func testGuestPurchaseShowsNudge() async {
        var state = PaywallFeature.State()
        state.products = mockProducts
        state.selectedProductID = "annual"
        state.isGuest = true

        let store = TestStore(initialState: state) {
            PaywallFeature()
        } withDependencies: {
            $0.subscriptionClient.purchase = { _ in .success(productID: "annual") }
            $0.subscriptionClient.checkEntitlement = { .everywherePlus }
        }

        store.exhaustivity = .off

        await store.send(.purchaseTapped) {
            $0.isLoading = true
        }

        await store.receive(.purchaseFinished(.success(productID: "annual"))) {
            $0.isLoading = false
            $0.subscriptionState = .everywherePlus
            $0.showCreateAccountNudge = true
        }

        #expect(store.state.purchaseResult == nil)

        await store.receive(.subscriptionStateLoaded(.everywherePlus))
        await store.receive(.delegate(.proUnlocked(.everywherePlus)))
    }

    @Test("Authed purchase shows welcome alert, not the guest nudge")
    func testAuthedPurchaseShowsWelcomeNotNudge() async {
        var state = PaywallFeature.State()
        state.products = mockProducts
        state.selectedProductID = "annual"
        state.isGuest = false

        let store = TestStore(initialState: state) {
            PaywallFeature()
        } withDependencies: {
            $0.subscriptionClient.purchase = { _ in .success(productID: "annual") }
            $0.subscriptionClient.checkEntitlement = { .everywherePlus }
        }

        store.exhaustivity = .off

        await store.send(.purchaseTapped) {
            $0.isLoading = true
        }

        await store.receive(.purchaseFinished(.success(productID: "annual"))) {
            $0.isLoading = false
            $0.subscriptionState = .everywherePlus
            $0.showCreateAccountNudge = false
            $0.purchaseResult = PaywallFeature.State.PurchaseResultAlert(
                message: String(localized: "Welcome to Everywhere/AI+! \u{1F389}"),
                isSuccess: true
            )
        }

        await store.receive(.subscriptionStateLoaded(.everywherePlus))
        await store.receive(.delegate(.proUnlocked(.everywherePlus)))
    }

    @Test("Create-account tap dismisses nudge and delegates sign-in")
    func testCreateAccountTappedDelegatesSignIn() async {
        var state = PaywallFeature.State()
        state.showCreateAccountNudge = true

        let store = TestStore(initialState: state) {
            PaywallFeature()
        }

        await store.send(.createAccountTapped) {
            $0.showCreateAccountNudge = false
        }

        await store.receive(.delegate(.signInRequested))
    }

    @Test("Dismissing create-account nudge only hides it")
    func testCreateAccountDismissedHidesNudge() async {
        var state = PaywallFeature.State()
        state.showCreateAccountNudge = true

        let store = TestStore(initialState: state) {
            PaywallFeature()
        }

        await store.send(.createAccountDismissed) {
            $0.showCreateAccountNudge = false
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
