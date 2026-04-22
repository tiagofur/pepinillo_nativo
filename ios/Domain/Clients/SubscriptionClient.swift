// SubscriptionClient.swift
// Pepinillo — Deep Work Companion for Apple
//
// TCA dependency wrapping RevenueCat SDK.
// Manages subscription products, purchases, and entitlement verification.
//
// Products:
//   - Pepinillo+ (one-time): local premium + iCloud sync + Apple Intelligence
//   - Everywhere/AI+ Monthly/Annual (subscription): everything + backend sync + cloud AI credits
//
// Legacy products (grandfathered):
//   - Pro Monthly/Annual → mapped to Everywhere/AI+
//   - Pro Lifetime → grandfathered to Pepinillo+

import Foundation
import ComposableArchitecture

#if canImport(RevenueCat)
import RevenueCat
#endif

// MARK: - Subscription Product IDs

enum PepinilloProduct: String, CaseIterable, Sendable {
    // Active products (configured in App Store Connect + RevenueCat)
    case monthly  = "com.pepinillo.app.pro.monthly"
    case annual   = "com.pepinillo.app.pro.annual"
    case lifetime = "com.pepinillo.app.pro.lifetime"

    var isSubscription: Bool { self != .lifetime }

    /// Products shown in paywall.
    static var currentProducts: [PepinilloProduct] {
        allCases
    }
}

// MARK: - Subscription State

struct SubscriptionState: Equatable, Sendable {
    var capabilities: UserCapabilities = .free
    var activeProductID: String? = nil
    var expirationDate: Date? = nil

    // MARK: Backward-compatible computed properties

    /// True if user has any paid tier (Pepinillo+ or Everywhere/AI+).
    var isPro: Bool { capabilities.hasAnyPremium }

    /// True if user has the Everywhere subscription.
    var isEverywhere: Bool { capabilities.isEverywhere }

    /// Human-readable tier name.
    var tierName: String { capabilities.tierDisplayName }

    // MARK: Static presets

    static let free = SubscriptionState(capabilities: .free)
    static let pepinilloPlus = SubscriptionState(capabilities: .pepinilloPlus)
    static let everywherePlus = SubscriptionState(capabilities: .everywherePlus)

    /// Legacy convenience — use .pepinilloPlus or .everywherePlus instead.
    static let pro = SubscriptionState(capabilities: .pepinilloPlus)
}

// MARK: - Product Info (value type for UI)

struct ProductInfo: Equatable, Sendable, Identifiable {
    var id: String
    var displayName: String
    var description: String
    var displayPrice: String
    var billingPeriod: String    // "month" | "year" | "once"
    var isFeatured: Bool = false
}

// MARK: - Purchase Result

enum PurchaseResult: Equatable, Sendable {
    case success(productID: String)
    case pending
    case cancelled
    case failed(message: String)
}

// MARK: - Subscription Client

@DependencyClient
struct SubscriptionClient: Sendable {
    /// Configure RevenueCat with API key and user ID.
    var configure: @Sendable (_ apiKey: String, _ userID: String?) async -> Void = { _, _ in }

    /// Fetch available RevenueCat offerings/packages.
    var fetchProducts: @Sendable () async -> [ProductInfo] = { [] }

    /// Purchase a RevenueCat package by product ID.
    var purchase: @Sendable (_ productID: String) async -> PurchaseResult = { _ in .cancelled }

    /// Restore previous purchases via RevenueCat.
    var restorePurchases: @Sendable () async -> SubscriptionState = { .free }

    /// Check current entitlement (call on launch + after purchase).
    var checkEntitlement: @Sendable () async -> SubscriptionState = { .free }

    /// Listen to customer info changes via RevenueCat.
    var listenForTransactionUpdates: @Sendable () -> AsyncStream<SubscriptionState> = { .finished }

    /// Identify user with backend user ID.
    var logIn: @Sendable (_ userID: String) async -> Void = { _ in }

    /// Reset to anonymous (logged out).
    var logOut: @Sendable () async -> Void = { }
}

// MARK: - Dependency Keys

extension SubscriptionClient: DependencyKey {
    static let liveValue = SubscriptionClient.live
    static let testValue = SubscriptionClient(
        configure: { _, _ in },
        fetchProducts: { PepinilloProduct.currentProducts.map(\.mockProductInfo) },
        purchase: { _ in .success(productID: PepinilloProduct.annual.rawValue) },
        restorePurchases: { .pepinilloPlus },
        checkEntitlement: { .free },
        listenForTransactionUpdates: { .finished },
        logIn: { _ in },
        logOut: { }
    )
}

extension DependencyValues {
    var subscriptionClient: SubscriptionClient {
        get { self[SubscriptionClient.self] }
        set { self[SubscriptionClient.self] = newValue }
    }
}

// MARK: - Live Implementation

extension SubscriptionClient {
    static let live: SubscriptionClient = {
#if canImport(RevenueCat)
        let manager = SubscriptionManager()
        return SubscriptionClient(
            configure: { apiKey, userID in await manager.configure(apiKey: apiKey, userID: userID) },
            fetchProducts: { await manager.fetchProducts() },
            purchase: { id in await manager.purchase(productID: id) },
            restorePurchases: { await manager.restorePurchases() },
            checkEntitlement: { await manager.checkEntitlement() },
            listenForTransactionUpdates: { manager.customerInfoStream() },
            logIn: { userID in await manager.logIn(userID: userID) },
            logOut: { await manager.logOut() }
        )
#else
        // RevenueCat is not available on every platform target (e.g. watch simulator).
        // Keep a functional no-op implementation so builds remain cross-target compatible.
        return SubscriptionClient(
            configure: { _, _ in },
            fetchProducts: { PepinilloProduct.currentProducts.map(\.mockProductInfo) },
            purchase: { _ in .failed(message: "Purchases unavailable on this platform") },
            restorePurchases: { .free },
            checkEntitlement: { .free },
            listenForTransactionUpdates: { .finished },
            logIn: { _ in },
            logOut: { }
        )
#endif
    }()
}

// MARK: - Subscription Manager (actor)

#if canImport(RevenueCat)
private actor SubscriptionManager {
    private var isConfigured = false

    func configure(apiKey: String, userID: String?) async {
        guard !isConfigured else { return }
        isConfigured = true

        Purchases.logLevel = .debug
        Purchases.configure(withAPIKey: apiKey, appUserID: userID)
    }

    func fetchProducts() async -> [ProductInfo] {
        do {
            let offerings = try await Purchases.shared.offerings()
            guard let offering = offerings.current else {
                return PepinilloProduct.currentProducts.map(\.mockProductInfo)
            }

            var productInfos: [ProductInfo] = []
            for pepProduct in PepinilloProduct.currentProducts {
                if let package = offering.package(identifier: pepProduct.rawValue) ?? offering.availablePackages.first(where: { $0.product.productIdentifier == pepProduct.rawValue }) {
                    let productInfo = ProductInfo(
                        id: pepProduct.rawValue,
                        displayName: package.product.localizedTitle,
                        description: package.product.localizedDescription,
                        displayPrice: package.localizedPriceString,
                        billingPeriod: billingPeriodString(for: package),
                        isFeatured: pepProduct == .annual
                    )
                    productInfos.append(productInfo)
                }
            }

            return productInfos.isEmpty ? PepinilloProduct.currentProducts.map(\.mockProductInfo) : productInfos.sorted { a, b in
                let order = ["month": 0, "year": 1, "once": 2]
                return (order[a.billingPeriod] ?? 0) < (order[b.billingPeriod] ?? 0)
            }
        } catch {
            return PepinilloProduct.currentProducts.map(\.mockProductInfo)
        }
    }

    func purchase(productID: String) async -> PurchaseResult {
        do {
            let offerings = try await Purchases.shared.offerings()
            guard let offering = offerings.current else {
                return .failed(message: "No offerings available")
            }

            guard let package = offering.package(identifier: productID) ?? offering.availablePackages.first(where: { $0.product.productIdentifier == productID }) else {
                return .failed(message: "Package not found")
            }

            let result = try await Purchases.shared.purchase(package: package)

            // Check for active entitlement (supports new "pepinillo_plus"/"everywhere_plus" and legacy "premium"/"pro")
            let entitlements = result.customerInfo.entitlements
            let hasActiveEntitlement = entitlements["everywhere_plus"]?.isActive == true
                || entitlements["pepinillo_plus"]?.isActive == true
                || entitlements["premium"]?.isActive == true
                || entitlements["pro"]?.isActive == true

            if hasActiveEntitlement {
                return .success(productID: productID)
            } else {
                return .failed(message: "Purchase completed but entitlement not active")
            }
        } catch let error as ErrorCode {
            switch error {
            case .purchaseCancelledError:
                return .cancelled
            default:
                return .failed(message: error.localizedDescription)
            }
        } catch {
            return .failed(message: error.localizedDescription)
        }
    }

    func restorePurchases() async -> SubscriptionState {
        do {
            let customerInfo = try await Purchases.shared.restorePurchases()
            return await subscriptionStateFromCustomerInfo(customerInfo)
        } catch {
            return .free
        }
    }

    func checkEntitlement() async -> SubscriptionState {
        do {
            let customerInfo = try await Purchases.shared.customerInfo()
            return await subscriptionStateFromCustomerInfo(customerInfo)
        } catch {
            return .free
        }
    }

    nonisolated func customerInfoStream() -> AsyncStream<SubscriptionState> {
        AsyncStream { continuation in
            let task = Task {
                for await customerInfo in Purchases.shared.customerInfoStream {
                    let state = await subscriptionStateFromCustomerInfo(customerInfo)
                    continuation.yield(state)
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    func logIn(userID: String) async {
        do {
            _ = try await Purchases.shared.logIn(userID)
        } catch {
            // Log error but don't fail
            print("RevenueCat logIn failed: \(error)")
        }
    }

    func logOut() async {
        do {
            _ = try await Purchases.shared.logOut()
        } catch {
            // Log error but don't fail
            print("RevenueCat logOut failed: \(error)")
        }
    }

    private func subscriptionStateFromCustomerInfo(_ customerInfo: CustomerInfo) -> SubscriptionState {
        // Check for Everywhere+ entitlement first (superset of Pepinillo+)
        if let everywhereEntitlement = customerInfo.entitlements["everywhere_plus"], everywhereEntitlement.isActive {
            let expiryDate = everywhereEntitlement.expirationDate
            if let expiry = expiryDate {
                // Subscription with expiration — check grace period (3 days)
                if expiry.addingTimeInterval(3 * 24 * 60 * 60) > Date.now {
                    return SubscriptionState(
                        capabilities: .everywherePlus,
                        activeProductID: customerInfo.activeSubscriptions.first,
                        expirationDate: expiry
                    )
                }
            } else {
                // No expiration (shouldn't happen for Everywhere+, but be safe)
                return SubscriptionState(
                    capabilities: .everywherePlus,
                    activeProductID: customerInfo.activeSubscriptions.first,
                    expirationDate: nil
                )
            }
        }

        // Check for Pepinillo+ entitlement (one-time purchase)
        if let unlockEntitlement = customerInfo.entitlements["pepinillo_plus"], unlockEntitlement.isActive {
            return SubscriptionState(
                capabilities: .pepinilloPlus,
                activeProductID: customerInfo.allPurchasedProductIdentifiers.first,
                expirationDate: nil  // One-time purchase, no expiration
            )
        }

        // Legacy: check for old "premium" / "pro" entitlements — grandfather to appropriate tier
        if let proEntitlement = customerInfo.entitlements["premium"] ?? customerInfo.entitlements["pro"], proEntitlement.isActive {
            let expiryDate = proEntitlement.expirationDate

            // Legacy lifetime → grandfather to Pepinillo+
            if expiryDate == nil {
                return SubscriptionState(
                    capabilities: .pepinilloPlus,
                    activeProductID: customerInfo.allPurchasedProductIdentifiers.first,
                    expirationDate: nil
                )
            }

            // Legacy subscription → grandfather to Everywhere+
            if expiryDate!.addingTimeInterval(3 * 24 * 60 * 60) > Date.now {
                return SubscriptionState(
                    capabilities: .everywherePlus,
                    activeProductID: customerInfo.activeSubscriptions.first,
                    expirationDate: expiryDate
                )
            }
        }

        return .free
    }

    private nonisolated func billingPeriodString(for package: RevenueCat.Package) -> String {
        if let subscription = package.product.subscription {
            switch subscription.subscriptionPeriod.unit {
            case .day: return "day"
            case .week: return "week"
            case .month: return "month"
            case .year: return "year"
            @unknown default: return "month"
            }
        }
        return "once"
    }
}
#endif

// MARK: - Mock helpers for previews / tests

private extension PepinilloProduct {
    var mockProductInfo: ProductInfo {
        switch self {
        case .monthly:
            return ProductInfo(id: rawValue, displayName: "Everywhere/AI+ Monthly",
                               description: "Everything in Pepinillo+ plus backend sync and advanced cloud AI.", displayPrice: "$4.99",
                               billingPeriod: "month")
        case .annual:
            return ProductInfo(id: rawValue, displayName: "Everywhere/AI+ Annual",
                               description: "Best value — save 42% vs monthly.", displayPrice: "$34.99",
                               billingPeriod: "year", isFeatured: true)
        case .lifetime:
            return ProductInfo(id: rawValue, displayName: "Pepinillo+",
                               description: "One purchase. Yours forever. Not a subscription.", displayPrice: "$19.99",
                               billingPeriod: "once")
        }
    }
}
