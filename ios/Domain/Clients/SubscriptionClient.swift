// SubscriptionClient.swift
// Pepinillo — Deep Work Companion for Apple
//
// TCA dependency wrapping StoreKit 2.
// Manages Pro subscription products, purchases, and entitlement verification.

import Foundation
import StoreKit
import ComposableArchitecture

// MARK: - Subscription Product IDs

enum PepinilloProduct: String, CaseIterable, Sendable {
    case monthly  = "com.pepinillo.app.pro.monthly"
    case annual   = "com.pepinillo.app.pro.annual"
    case lifetime = "com.pepinillo.app.pro.lifetime"

    var isSubscription: Bool { self != .lifetime }
}

// MARK: - Subscription State

struct SubscriptionState: Equatable, Sendable {
    var isPro: Bool = false
    var activeProductID: String? = nil
    var expirationDate: Date? = nil

    static let free = SubscriptionState(isPro: false)
    static let pro  = SubscriptionState(isPro: true)
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
    /// Fetch available StoreKit products.
    var fetchProducts: @Sendable () async -> [ProductInfo] = { [] }

    /// Purchase a product by ID.
    var purchase: @Sendable (_ productID: String) async -> PurchaseResult = { _ in .cancelled }

    /// Restore previous purchases.
    var restorePurchases: @Sendable () async -> SubscriptionState = { .free }

    /// Check current entitlement (call on launch + after purchase).
    var checkEntitlement: @Sendable () async -> SubscriptionState = { .free }

    /// Listen to StoreKit transaction updates (call once at app launch).
    var listenForTransactionUpdates: @Sendable () -> AsyncStream<SubscriptionState> = { .finished }
}

// MARK: - Dependency Keys

extension SubscriptionClient: DependencyKey {
    static let liveValue = SubscriptionClient.live
    static let testValue = SubscriptionClient(
        fetchProducts: { PepinilloProduct.allCases.map(\.mockProductInfo) },
        purchase: { _ in .success(productID: PepinilloProduct.annual.rawValue) },
        restorePurchases: { .pro },
        checkEntitlement: { .free },
        listenForTransactionUpdates: { .finished }
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
        let manager = SubscriptionManager()
        return SubscriptionClient(
            fetchProducts: { await manager.fetchProducts() },
            purchase: { id in await manager.purchase(productID: id) },
            restorePurchases: { await manager.restorePurchases() },
            checkEntitlement: { await manager.checkEntitlement() },
            listenForTransactionUpdates: { manager.transactionStream() }
        )
    }()
}

// MARK: - Subscription Manager (actor)

private actor SubscriptionManager {
    func fetchProducts() async -> [ProductInfo] {
        let ids = PepinilloProduct.allCases.map(\.rawValue)
        do {
            let products = try await Product.products(for: ids)
            return products.compactMap { product -> ProductInfo? in
                guard let pepProduct = PepinilloProduct(rawValue: product.id) else { return nil }
                return ProductInfo(
                    id: product.id,
                    displayName: product.displayName,
                    description: product.description,
                    displayPrice: product.displayPrice,
                    billingPeriod: pepProduct.isSubscription
                        ? (product.subscription?.subscriptionPeriod.unit == .month ? "month" : "year")
                        : "once",
                    isFeatured: pepProduct == .annual
                )
            }
            .sorted { a, b in
                // Sort: monthly, annual (featured), lifetime
                let order = ["month": 0, "year": 1, "once": 2]
                return (order[a.billingPeriod] ?? 0) < (order[b.billingPeriod] ?? 0)
            }
        } catch {
            return PepinilloProduct.allCases.map(\.mockProductInfo)
        }
    }

    func purchase(productID: String) async -> PurchaseResult {
        do {
            guard let product = try await Product.products(for: [productID]).first else {
                return .failed(message: "Product not found")
            }
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await transaction.finish()
                return .success(productID: transaction.productID)
            case .pending:
                return .pending
            case .userCancelled:
                return .cancelled
            @unknown default:
                return .cancelled
            }
        } catch {
            return .failed(message: error.localizedDescription)
        }
    }

    func restorePurchases() async -> SubscriptionState {
        // StoreKit 2: sync transactions
        try? await AppStore.sync()
        return await checkEntitlement()
    }

    func checkEntitlement() async -> SubscriptionState {
        // Check for active subscriptions or lifetime purchase
        for await result in Transaction.currentEntitlements {
            if let transaction = try? checkVerified(result) {
                let isSubscription = PepinilloProduct(rawValue: transaction.productID)?.isSubscription ?? false
                if isSubscription {
                    // Check if subscription is still valid (3-day grace period for payment issues)
                    if let expiry = transaction.expirationDate, expiry.addingTimeInterval(3 * 24 * 60 * 60) > Date.now {
                        return SubscriptionState(
                            isPro: true,
                            activeProductID: transaction.productID,
                            expirationDate: expiry
                        )
                    }
                } else {
                    // Lifetime purchase
                    return SubscriptionState(isPro: true, activeProductID: transaction.productID)
                }
            }
        }
        return .free
    }

    nonisolated func transactionStream() -> AsyncStream<SubscriptionState> {
        AsyncStream { continuation in
            let task = Task {
                for await result in Transaction.updates {
                    if let _ = try? checkVerified(result) {
                        let state = await checkEntitlement()
                        continuation.yield(state)
                    }
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private nonisolated func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified: throw StoreError.failedVerification
        case .verified(let value): return value
        }
    }
}

// MARK: - StoreError

enum StoreError: Error {
    case failedVerification
}

// MARK: - Mock helpers for previews / tests

private extension PepinilloProduct {
    var mockProductInfo: ProductInfo {
        switch self {
        case .monthly:
            return ProductInfo(id: rawValue, displayName: "Pro Monthly",
                               description: "All features, billed monthly.", displayPrice: "$2.99",
                               billingPeriod: "month")
        case .annual:
            return ProductInfo(id: rawValue, displayName: "Pro Annual",
                               description: "Best value — save 50%.", displayPrice: "$14.99",
                               billingPeriod: "year", isFeatured: true)
        case .lifetime:
            return ProductInfo(id: rawValue, displayName: "Pro Lifetime",
                               description: "Pay once, own forever.", displayPrice: "$29.99",
                               billingPeriod: "once")
        }
    }
}
